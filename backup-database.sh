#!/bin/bash
set -o errexit  # script will exit if a command fails
set -o pipefail # catch | (pipe) fails. The exit status of the last command that threw a non-zero exit code is returned

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

# Check if repo was initialized, if it is not, we perform borg init
if ! [ -d "$DB_REPO/data" ]; then
    echo "-- No repo found for db $DB_NAME. This is the first time you take a backup of it."
    echo "-- Initializing a new borg repository $DB_REPO"

    # We should create the backup directory for this repo.
    # But we should first check if we are in ssh or plain filesystem as the commands differ
    if [[ -z $SSH_HOST ]]; then
        # Plain file system
        mkdir -p "$DB_REPO"
    else
        # SSH filesystem. We must perform sftp actions
        # The following script will create the dir if not exists
        bash sftp-mkdir.sh "$DB_REPO"
    fi

    borg init $OPTIONS_INIT "$DB_REPO"
fi

DATE=$(date +'%F')

echo "-- Creating new backup archive $DB_REPO::$DATE"
mysqldump "$DB_NAME" --opt --routines --skip-comments | borg create $OPTIONS_CREATE "$DB_REPO"::"$DATE" -

echo "-- Cleaning old backup archives"
borg prune $OPTIONS_PRUNE "$DB_REPO"

echo "---------- BACKUP COMPLETED! -----------"
END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))
echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
