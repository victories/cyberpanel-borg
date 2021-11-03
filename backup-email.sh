#!/bin/bash

# This script will backup your email account

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

USAGE="-- Usage example \nbackup-email.sh demo@domain.com"
EMAIL=$1

# Checking required arguments
if [[ -z $EMAIL ]]; then
    echo "-- ERROR: arguments are missing..."
    echo -e "$USAGE"
    exit 1
fi

# Checking if given email exists in db
# NOTE: e.mail column holds the directory that has the email in the system (e.g. maildir:/home/vmail/domain.com/your_email/Maildir)
read -r EMAIL_META DOMAIN < <(echo "SELECT e.mail, e.emailOwner_id FROM e_users e WHERE e.email = '$EMAIL'" | mysql cyberpanel -s)
if [[ -z $EMAIL_META ]]; then
    echo "-- Email $EMAIL was not found in cyberpanel"
    exit 2
fi

# Now we must extract the email dir from the mail meta
if [[ "$EMAIL_META" =~ maildir:(.*) ]]; then
    # BASH_REMATCH[1] stores the first capture group of the regex match
    DIR_FOR_BACKUP="${BASH_REMATCH[1]}"
else
    echo "-- ERROR: Couldn't extract the email directory for $EMAIL"
    exit 3
fi

# Checking if the email dir exists
# There might be a case that this directory isn't' created.
# This happens if there isn't any email received / sent yet for this email account
if ! [[ -d $DIR_FOR_BACKUP ]]; then
    echo "-- This email account has no emails at all. There is nothing to backup..."
    exit 0
fi

echo "---------- BACKUP STARTED! -----------"

# Set script start time to calculate duration
START_TIME=$(date +%s)

# Set borg repo path
EMAIL_REPO=$REPO_EMAILS_DIR/$DOMAIN/$EMAIL
# This is the path that can contain the ssh:// config in case we have a remote ssh backup location
EMAIL_REPO_DESTINATION="$EMAIL_REPO"

if [[ -n $SSH_HOST ]]; then
    # We don't have to add / before EMAIL_REPO because it is already added in the config.sh
    EMAIL_REPO_DESTINATION="$SSH_DESTINATION$EMAIL_REPO"
fi

# Check if repo was initialized, if it is not we perform a borg init
if ! "$CURRENT_DIR"/helpers/dir-exists.sh "$EMAIL_REPO/data"; then
    echo "-- No repo found for $EMAIL. This is the first time you take a backup of it."
    echo "-- Initializing a new borg repository $EMAIL_REPO"

    # We should create the backup directory for this repo.
    "$CURRENT_DIR"/helpers/mkdir-if-not-exist.sh "$EMAIL_REPO"

    borg init $OPTIONS_INIT "$EMAIL_REPO_DESTINATION"
fi

DATE=$(date +'%F')

echo "-- Creating new backup archive $EMAIL_REPO::$DATE"
borg create $OPTIONS_CREATE "$EMAIL_REPO_DESTINATION"::"$DATE" "$DIR_FOR_BACKUP"

echo "-- Cleaning old backup archives"
borg prune $OPTIONS_PRUNE "$EMAIL_REPO_DESTINATION"

echo "---------- BACKUP COMPLETED! -----------"
END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))
echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
