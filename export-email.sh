#!/bin/bash

# This script will export a tar file from incremental backups for the specified date and email.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

USAGE="-- Usage example \nexport-email.sh email@domain.com 2021-10-15"

# Assign arguments
EMAIL=$1
DATE=$2

# Checking required arguments
if [[ "$#" -lt 2 ]]; then
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
    # TODO: Maybe we have to find a way to handle emails that are not in the cyberpanel db anymore like we mentioned in the export-database script.
    echo "-- Email $EMAIL was not found in cyberpanel"
    exit 2
fi

# Set script start time to calculate duration
START_TIME=$(date +%s)

EXPORT_DIR="$EXPORT_DIR/emails/$DOMAIN"

# Set borg repo path
EMAIL_REPO=$REPO_EMAILS_DIR/$DOMAIN/$EMAIL
EXPORT_LOCATION="local"

# Check if user repo exist
if ! "$CURRENT_DIR"/helpers/dir-exists.sh "$EMAIL_REPO/data"; then
    echo "-- ERROR: There is no backup for email $EMAIL."
    exit 4
fi

# This should happen after checking if the dir exists because the dir-exists needs the pure path to directory and not the ssh one
if [[ -n $SSH_HOST ]]; then
    EMAIL_REPO="$SSH_DESTINATION/${EMAIL_REPO#/}"
    EXPORT_LOCATION="remote ssh"
fi

# Check if backup archive date exist for the given emaill
if ! borg list "$EMAIL_REPO" | grep -q "$DATE"; then
    echo "-- ERROR: There is no backup for email $EMAIL for date $DATE."
    echo "-- The following backups are available for this email"
    borg list "$EMAIL_REPO"
    exit 5
fi

read -p "Are you sure you want to export tar for email $EMAIL for date $DATE to $EXPORT_LOCATION location $EXPORT_DIR? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    # This is to avoid exiting the script if the script is sourced
    [[ "$0" = "$BASH_SOURCE" ]]
    echo
    echo "---------- EXPORT CANCELED! -----------"
    exit 6
fi

echo
echo "---------- EXPORT STARTED! -----------"

# Create export dir if it doesn't exist
"$CURRENT_DIR"/helpers/mkdir-if-not-exist.sh "$EXPORT_DIR"

# Pipe the tar file to the destination
if [[ -z $SSH_HOST ]]; then
    # local export
    borg export-tar --tar-filter="gzip -9" "$EMAIL_REPO"::"$DATE" "$EXPORT_DIR/${EMAIL}_$DATE.tar.gz"
else
    # remote export
    # We have to export to a temp file because borg export-tar doesn't support piping to a remote location
    TMP_FILE=/tmp/"${EMAIL}_$DATE.tar.gz"

    echo "-- Creating tar.gz file from backup"
    borg export-tar --tar-filter="gzip -9" "$EMAIL_REPO"::"$DATE" "$TMP_FILE"

    echo "-- Uploading $TMP_FILE to $EXPORT_DIR"
    # We have to remove the leading / in front of the export dir. Otherwise we get an error "No such file or directory"
    scp -P "$SSH_PORT" "$TMP_FILE" "$SSH_USER"@"$SSH_HOST":"${EXPORT_DIR#/}/"

    echo "-- Removing temp file $TMP_FILE"
    rm "$TMP_FILE"
fi

echo "---------- EXPORT COMPLETED! -----------"
echo "-- Exported file: $EXPORT_DIR/${EMAIL}_$DATE.tar.gz"

END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))

echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
