#!/bin/bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

USAGE="-- Usage example: \nbackup-database.sh my_db_name"
DB_NAME=$1

# Checking required arguments
if [[ -z $DB_NAME ]]; then
    echo "-- ERROR: arguments are missing..."
    echo -e "$USAGE"
    exit 1
fi

# Check if database exists in cyberpanel db and get it's website to use this for the backup dir
DB_WEBSITE=$(echo "SELECT w.domain FROM databases_databases d LEFT JOIN websiteFunctions_websites w ON d.website_id = w.id WHERE d.dbName = '$DB_NAME'" | mysql cyberpanel -s)
if [[ -z $DB_WEBSITE ]]; then
    echo "-- ERROR: Database was not found in cyberpanel. Make sure you typed the db name correctly"
    exit 2
fi

echo "---------- BACKUP STARTED! -----------"

# Set script start time to calculate duration
START_TIME=$(date +%s)

DB_REPO="$REPO_DB_DIR/$DB_WEBSITE/$DB_NAME"
# This is the path that can contain the ssh:// config in case we have a remote ssh backup location
DB_REPO_DESTINATION="$DB_REPO"

if [[ -n $SSH_HOST ]]; then
    # We don't have to add / before DB_REPO because it is already added in the config.sh
    DB_REPO_DESTINATION="$SSH_DESTINATION$DB_REPO"
fi

# Check if repo was initialized, if it is not, we perform borg init
if ! "$CURRENT_DIR"/helpers/dir-exists.sh "$DB_REPO/data"; then
    echo "-- No repo found for db $DB_NAME. This is the first time you take a backup of it."
    echo "-- Initializing a new borg repository $DB_REPO"

    # We should create the backup directory for this repo.
    "$CURRENT_DIR"/helpers/mkdir-if-not-exist.sh "$DB_REPO"

    borg init $OPTIONS_INIT "$DB_REPO_DESTINATION"
fi

DATE=$(date +'%F')

echo "-- Creating new backup archive $DB_REPO::$DATE"
mysqldump "$DB_NAME" --opt --routines --skip-comments | borg create $OPTIONS_CREATE "$DB_REPO_DESTINATION"::"$DATE" -

echo "-- Cleaning old backup archives"
borg prune $OPTIONS_PRUNE "$DB_REPO_DESTINATION"

echo "---------- BACKUP COMPLETED! -----------"
END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))
echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
