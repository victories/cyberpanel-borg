#!/bin/bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

USAGE="-- Usage example: \nrestore-database.sh my_db_name 2021-10-15"
DB_NAME=$1
DATE=$2

# Checking required arguments
if [[ -z $DB_NAME || -z $DATE ]]; then
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

# Check if database exists in cyberpanel db and get it's website to since it is part of the backup dir
DB_WEBSITE=$(echo "SELECT w.domain FROM databases_databases d LEFT JOIN websiteFunctions_websites w ON d.website_id = w.id WHERE d.dbName = '$DB_NAME'" | mysql cyberpanel -s)
if [[ -z $DB_WEBSITE ]]; then
    echo "-- ERROR: Database $DB_NAME was not found in cyberpanel"
    echo "-- Please create the db in the panel and then retry the restore"
    echo "-- Unfortunately we cannot perform the restore if the db doesn't exist in panel"
    exit 3
fi

DB_REPO="$REPO_DB_DIR/$DB_WEBSITE/$DB_NAME"
# This is the path that can contain the ssh:// config in case we have a remote ssh backup location
DB_REPO_DESTINATION="$DB_REPO"

if [[ -n $SSH_HOST ]]; then
    # We don't have to add / before DB_REPO because it is already added in the config.sh
    DB_REPO_DESTINATION="$SSH_DESTINATION$DB_REPO"
fi

# Checking if backups exist for this db
if ! "$CURRENT_DIR"/helpers/dir-exists.sh "$DB_REPO/data"; then
    echo "-- No repo found for db $DB_NAME. Please make sure that you have backups for this db"
    exit 4
fi

# Checking if we have backup for given date for this db
if ! borg list "$DB_REPO_DESTINATION" | grep -q "$DATE"; then
    echo "-- No backup archive found for date $DATE. The following are available for this db:"
    borg list "$DB_REPO_DESTINATION"
    exit 5
fi

read -p "Are you sure you want to restore database $DB_NAME owned by domain $DB_WEBSITE to date $DATE backup version? [y/n]" -n 1 -r
# Verify that we want to restore the selected backup
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    # This is to avoid exiting the script if the script is sourced
    [[ "$0" = "$BASH_SOURCE" ]]
    echo
    echo "---------- RESTORATION WAS CANCELED! -----------"
    exit 6
fi

echo
echo "---------- RESTORATION STARTED! -----------"

# Set script start time to calculate duration
START_TIME=$(date +%s)

echo "-- Removing current database $DB_NAME"
mysqladmin -f drop "$DB_NAME"

echo "-- Creating database $DB_NAME"
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME"

echo "-- Importing restored file to $DB_NAME database"
borg extract --stdout "$DB_REPO_DESTINATION::$DATE" | mysql "$DB_NAME"

echo "---------- RESTORATION COMPLETED! -----------"
END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))
echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
