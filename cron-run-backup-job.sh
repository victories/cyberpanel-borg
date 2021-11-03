#!/bin/bash

# This script allows to backup databases, domains and emails for all accounts in cyberpanel.
# You can add this script to crontab to run it automatically.
# For now we only support 1 backup per day since the backup archives are named with the date (without time included).
# Thus if you try to run this backup more than once per day, it will skip the backup since there is already a backup archive for that date.
# Just make sure that you have configured your config.sh file properly as explained in the readme file.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR/config.sh"

# Set script start time to calculate duration
START_TIME=$(date +%s)

# We are keeping the website names for the failed backups so that we can inform the user via email.
FAILED_WEBSITE_BACKUPS=()
FAILED_CHILD_DOMAIN_BACKUPS=()
FAILED_DATABASE_BACKUPS=()
FAILED_EMAIL_BACKUPS=()

DATE=$(date +'%F')
LOG_DIR="/var/log/cyberpanel-borg/cron-backup-job"
LOG_FILE="$LOG_DIR/$DATE.log"

if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

echo "---------- CRON BACKUP JOB STARTED! -----------" >>"$LOG_FILE"

# Backup main domains (websites)
while read -r WEBSITE_DOMAIN; do
    echo -e "\n\n\n-- Backing up website: $WEBSITE_DOMAIN" >>"$LOG_FILE"
    # Try to backup, keep log and keep track of failed backups
    "$CURRENT_DIR"/backup-domain.sh "$WEBSITE_DOMAIN" >>"$LOG_FILE" 2>&1 || FAILED_WEBSITE_BACKUPS+=("$WEBSITE_DOMAIN")
    echo "******************************************************" >>"$LOG_FILE"
done < <(echo "SELECT domain FROM websiteFunctions_websites" | mysql cyberpanel -s)

# Backup child domains (that belong to websites)
while read -r CHILD_DOMAIN; do
    echo -e "\n\n\n-- Backing up child domain: $CHILD_DOMAIN" >>"$LOG_FILE"
    # Try to backup, keep log and keep track of failed backups
    "$CURRENT_DIR"/backup-domain.sh "$CHILD_DOMAIN" >>"$LOG_FILE" 2>&1 || FAILED_CHILD_DOMAIN_BACKUPS+=("$CHILD_DOMAIN")
    echo "******************************************************" >>"$LOG_FILE"
done < <(echo "SELECT domain FROM websiteFunctions_childdomains" | mysql cyberpanel -s)

# Backup databases
while read -r DATABASE_NAME; do
    echo -e "\n\n\n-- Backing up database: $DATABASE_NAME" >>"$LOG_FILE"
    # Try to backup, keep log and keep track of failed backups
    "$CURRENT_DIR"/backup-database.sh "$DATABASE_NAME" >>"$LOG_FILE" 2>&1 || FAILED_DATABASE_BACKUPS+=("$DATABASE_NAME")
    echo "******************************************************" >>"$LOG_FILE"
done < <(echo "SELECT dbName FROM databases_databases" | mysql cyberpanel -s)

# Backup emails
while read -r EMAIL; do
    echo -e "\n\n\n-- Backing up email: $EMAIL" >>"$LOG_FILE"
    # Try to backup, keep log and keep track of failed backups
    "$CURRENT_DIR"/backup-email.sh "$EMAIL" >>"$LOG_FILE" 2>&1 || FAILED_EMAIL_BACKUPS+=("$EMAIL")
    echo "******************************************************" >>"$LOG_FILE"
done < <(echo "SELECT email FROM e_users" | mysql cyberpanel -s)

echo "---------- CRON BACKUP JOB COMPLETED! -----------" >>"$LOG_FILE"

END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))
EXECUTION_TIME=$(date -u -d @${RUN_TIME} +'%T')

echo "-- Execution time: $EXECUTION_TIME" >>"$LOG_FILE"

# -------------- BELOW IS THE EMAIL NOTIFICATION PART --------------

# Check remaining disk space at backup drive and send email if needed
"$CURRENT_DIR"/helpers/notify-if-backup-has-low-disk-space.sh >>"$LOG_FILE" 2>&1

# Get backup disk stats to include them in the mail
BACKUP_DISK_STATS=$("$CURRENT_DIR"/helpers/get-backup-disk-space.sh)

# We assume that the status was successful. Then we will check if we have any failed backups and change it.
BACKUP_STATUS="SUCCESS"

if [ ${#FAILED_WEBSITE_BACKUPS[@]} -gt 0 ]; then
    BACKUP_STATUS="FAILED"
    MAIL_MESSAGE_FAILED="The following websites failed to backup:"
    for WEBSITE_DOMAIN in "${FAILED_WEBSITE_BACKUPS[@]}"; do
        MAIL_MESSAGE_FAILED+="\n$WEBSITE_DOMAIN"
    done
fi

if [ ${#FAILED_CHILD_DOMAIN_BACKUPS[@]} -gt 0 ]; then
    BACKUP_STATUS="FAILED"
    MAIL_MESSAGE_FAILED="The following child domains failed to backup:"
    for CHILD_DOMAIN in "${FAILED_WEBSITE_BACKUPS[@]}"; do
        MAIL_MESSAGE_FAILED+="\n$CHILD_DOMAIN"
    done
fi

if [ ${#FAILED_DATABASE_BACKUPS[@]} -gt 0 ]; then
    BACKUP_STATUS="FAILED"
    MAIL_MESSAGE_FAILED="The following databases failed to backup:"
    for DATABASE_NAME in "${FAILED_DATABASE_BACKUPS[@]}"; do
        MAIL_MESSAGE_FAILED+="\n$DATABASE_NAME"
    done
fi

if [ ${#FAILED_EMAIL_BACKUPS[@]} -gt 0 ]; then
    BACKUP_STATUS="FAILED"
    MAIL_MESSAGE_FAILED="The following emails failed to backup:"
    for EMAIL in "${FAILED_EMAIL_BACKUPS[@]}"; do
        MAIL_MESSAGE_FAILED+="\n$EMAIL"
    done
fi

# # Prepare notification email content and subject
if [ "$BACKUP_STATUS" == "FAILED" ]; then
    MAIL_MESSAGE="$MAIL_MESSAGE_FAILED\n\nPlease check the log file for more details."
    MAIL_SUBJECT="WARNING - Backup job had issues"
else
    MAIL_MESSAGE="Backup execution time was: $EXECUTION_TIME \n\nBackup Disk Space Stats\n $BACKUP_DISK_STATS"
    MAIL_SUBJECT="SUCCESS - Backup job completed successfully"
fi

# Send the notification email to admin and attach the log file
echo -e "$MAIL_MESSAGE" | /usr/bin/mail -s "$MAIL_SUBJECT" -a From:"$EMAIL_FROM_NAME"\<"$EMAIL_FROM_EMAIL"\> "$ADMIN_EMAIL" -A "$LOG_FILE"
