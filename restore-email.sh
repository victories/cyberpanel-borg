#!/bin/bash

# This script will restore your email account to the given date.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

USAGE="-- Usage example \nrestore-email.sh demo@domain.com 2021-10-15"
EMAIL=$1
DATE=$2

# Checking required arguments
if [[ -z $EMAIL || -z $DATE ]]; then
    echo "-- ERROR: arguments are missing..."
    echo -e "$USAGE"
    exit 1
fi

# Checking date format (YYYY-MM-DD)
if [[ ! $DATE =~ ^20[0-9]{2}-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])$ ]]; then
    echo "-- ERROR: the date format is not correct"
    echo -e "$USAGE"
    exit 2
fi

# Checking if given email exists in db
# NOTE: e.mail column holds the directory that has the email in the system (e.g. maildir:/home/vmail/domain.com/your_email/Maildir)
read -r EMAIL_META DOMAIN < <(echo "SELECT e.mail, e.emailOwner_id FROM e_users e WHERE e.email = '$EMAIL'" | mysql cyberpanel -s)
if [[ -z $EMAIL_META ]]; then
    echo "-- Email $EMAIL was not found in cyberpanel"
    echo "-- Please create the email account $EMAIL in cyberpanel first and then try to run restore again."
    exit 3
fi

# Now we must extract the email dir from the mail meta
if [[ "$EMAIL_META" =~ maildir:(.*) ]]; then
    # BASH_REMATCH[1] stores the first capture group of the regex match
    DIR_TO_RESTORE="${BASH_REMATCH[1]}"
else
    echo "-- ERROR: Couldn't extract the email directory for $EMAIL"
    exit 4
fi

# Set borg repo path
EMAIL_REPO=$REPO_EMAILS_DIR/$DOMAIN/$EMAIL

# Checking if backups exist for this email
if ! [ -d "$EMAIL_REPO/data" ]; then
    echo "-- No repo found for email $EMAIL. Please make sure that you have backups for this email"
    exit 5
fi

# Checking if we have backup for given date for this email
if ! borg list "$EMAIL_REPO" | grep -q "$DATE"; then
    echo "-- No backup archive found for date $DATE. The following are available for this email:"
    borg list "$EMAIL_REPO"
    exit 6
fi

read -p "Are you sure you want to restore email $EMAIL to date $DATE backup version? [y/n]" -n 1 -r
# Verify that we want to restore the selected backup
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    # This is to avoid exiting the script if the script is sourced
    [[ "$0" = "$BASH_SOURCE" ]]
    echo
    echo "---------- RESTORATION WAS CANCELED! -----------"
    exit 7
fi

echo
echo "---------- RESTORATION STARTED! -----------"

# Set script start time to calculate duration
START_TIME=$(date +%s)

# Removing current files from the domain directory
echo "-- Removing old directory"
rm -rf "$DIR_TO_RESTORE"

# Recreating the directory
echo "-- Re-creating directory"
mkdir -p "$DIR_TO_RESTORE"

# Restoring the backup to the domain directory
echo "-- Restoring backup"

# This is a workaround. Borg will actually try to restore files in the home/vmail/domain.com/email_name directory because we are using the ${DIR_TO_RESTORE:1} as a restore pattern.
# Thus we need to be in the root dir, so that the restore is done in the right place.
# Unfortunately, it is not possible to use absolute paths for the restoration since borg will complain that "Include pattern '/home/vmail/domain.com/email_name' never matched." if we just add $DIR_TO_RESTORE without removing the first /.
cd /

# Note that have to use ${DIR_TO_RESTORE:1} for the reason explained above.
borg extract --list "$EMAIL_REPO"::"$DATE" "${DIR_TO_RESTORE:1}"

# Fixing permissions
echo "-- Fixing directory and file ownership"
chown -R vmail:vmail "$DIR_TO_RESTORE"

echo "---------- RESTORATION COMPLETED! -----------"
END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))
echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
