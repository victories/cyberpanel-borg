#!/bin/bash

# This script will backup your domain (either website domain or child-domain from within a website)

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

USAGE="-- Usage example \nbackup-domain.sh domain.com \n-- NOTE: you can specify either a website domain or a child domain that belongs to a website"
DOMAIN=$1

# Checking required arguments
if [[ -z $DOMAIN ]]; then
    echo "-- ERROR: arguments are missing..."
    echo -e "$USAGE"
    exit 1
fi

# Checking if given domain is a "main domain" aka website
WEBSITE=$(echo "SELECT domain FROM websiteFunctions_websites WHERE domain = '$DOMAIN'" | mysql cyberpanel -s)
if [[ -z $WEBSITE ]]; then

    # Domain was not found in main domains. We have to check if it is a child domain.
    # Checking if domain exists in cyberpanel child domains database
    read -r WEBSITE CHILD_DOMAIN_PATH < <(echo "SELECT w.domain, cd.path FROM websiteFunctions_childdomains cd LEFT JOIN websiteFunctions_websites w ON cd.master_id = w.id WHERE cd.domain = '$DOMAIN'" | mysql cyberpanel -s)
    if [[ -z $WEBSITE ]]; then
        echo "-- Domain $DOMAIN was not found in cyberpanel"
        exit 2
    fi
    DIR_FOR_BACKUP="$CHILD_DOMAIN_PATH"
else
    # When the domain is not a child domain the files are stored inside the public_html folder
    DIR_FOR_BACKUP="${HOME_DIR%/}/$WEBSITE/public_html"
fi

echo "---------- BACKUP STARTED! -----------"

# Set script start time to calculate duration
START_TIME=$(date +%s)

# Set borg repo path
DOMAIN_REPO=$REPO_DOMAINS_DIR/$DOMAIN
# This is the path that can contain the ssh:// config in case we have a remote ssh backup location
DOMAIN_REPO_DESTINATION="$DOMAIN_REPO"

if [[ -n $SSH_HOST ]]; then
    # We don't have to add / before DOMAIN_REPO because it is already added in the config.sh
    DOMAIN_REPO_DESTINATION="$SSH_DESTINATION$DOMAIN_REPO"
fi

# Check if repo was initialized, if it is not we perform a borg init
if ! "$CURRENT_DIR"/helpers/dir-exists.sh "$DOMAIN_REPO/data"; then
    echo "-- No repo found for $WEBSITE. This is the first time you take a backup of it."
    echo "-- Initializing a new borg repository $DB_REPO"

    # We should create the backup directory for this repo.
    "$CURRENT_DIR"/helpers/mkdir-if-not-exist.sh "$DOMAIN_REPO"

    borg init $OPTIONS_INIT "$DOMAIN_REPO_DESTINATION"

fi

DATE=$(date +'%F')

echo "-- Creating new backup archive $DOMAIN_REPO::$DATE"
# backup-file-exclude.lst file contains the pattern for the directories that should be excluded
# As a default we exclude the wordpress and drupal cache files
borg create $OPTIONS_CREATE "$DOMAIN_REPO_DESTINATION"::"$DATE" "$DIR_FOR_BACKUP" --exclude-from="$CURRENT_DIR"/backup-file-exclude.lst

echo "-- Cleaning old backup archives"
borg prune $OPTIONS_PRUNE "$DOMAIN_REPO_DESTINATION"

echo "---------- BACKUP COMPLETED! -----------"
END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))
echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
