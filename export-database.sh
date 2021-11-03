#!/bin/bash

# This script will export a tar file from incremental backups for the specified date and database.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

USAGE="-- Usage example \nexport-database.sh database_name 2021-10-15"

# Assign arguments
DB_NAME=$1
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

# Check if database exists in cyberpanel db and get it's website to use this for the backup dir
DB_WEBSITE=$(echo "SELECT w.domain FROM databases_databases d LEFT JOIN websiteFunctions_websites w ON d.website_id = w.id WHERE d.dbName = '$DB_NAME'" | mysql cyberpanel -s)
if [[ -z $DB_WEBSITE ]]; then
    # TODO: Maybe I have to re-think about it. What would happen if we need to export a database backup for a db that doesn't exist in cyberpanel anymore?
    #       That should be doable... We just have to remove the domain from the export path, so that we don't need to query the cyberpanel db.
    #       On the other hand it is convinient to have the db exported under the domain dir to have it better organized. What if we would use a NO_DOMAIN
    #       folder for the ones that we cannot find a domain for, and give a warning message to the user instead of aborting the export.
    echo "-- ERROR: Database was not found in cyberpanel. Make sure you typed the db name correctly"
    exit 3
fi

# Set script start time to calculate duration
START_TIME=$(date +%s)

EXPORT_DIR="$EXPORT_DIR/databases/$DB_WEBSITE"

# Set user repository
DB_REPO="$REPO_DB_DIR/$DB_WEBSITE/$DB_NAME"
EXPORT_LOCATION="local"

# Check if user repo exist
if ! "$CURRENT_DIR"/helpers/dir-exists.sh "$DB_REPO/data"; then
    echo "-- ERROR: There is no backup for database $DB_NAME."
    exit 4
fi

# This should happen after checking if the dir exists because the dir-exists needs the pure path to directory and not the ssh one
if [[ -n $SSH_HOST ]]; then
    DB_REPO="$SSH_DESTINATION/${DB_REPO#/}"
    EXPORT_LOCATION="remote ssh"
fi

# Check if backup archive date exist for the given database
if ! borg list "$DB_REPO" | grep -q "$DATE"; then
    echo "-- ERROR: There is no backup for database $DB_NAME for date $DATE."
    echo "-- The following backups are available for this database"
    borg list "$DB_REPO"
    exit 5
fi

read -p "Are you sure you want to export tar for database $DB_NAME for date $DATE to $EXPORT_LOCATION location $EXPORT_DIR? " -n 1 -r
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
    borg export-tar --tar-filter="gzip -9" "$DB_REPO"::"$DATE" "$EXPORT_DIR/${DB_NAME}_$DATE.tar.gz"
else
    # remote export
    # We have to export to a temp file because borg export-tar doesn't support piping to a remote location
    TMP_FILE=/tmp/"${DB_NAME}_$DATE.tar.gz"

    echo "-- Creating tar.gz file from backup"
    borg export-tar --tar-filter="gzip -9" "$DB_REPO"::"$DATE" "$TMP_FILE"

    echo "-- Uploading $TMP_FILE to $EXPORT_DIR"
    # We have to remove the leading / in front of the export dir. Otherwise we get an error "No such file or directory"
    scp -P "$SSH_PORT" "$TMP_FILE" "$SSH_USER"@"$SSH_HOST":"${EXPORT_DIR#/}/"

    echo "-- Removing temp file $TMP_FILE"
    rm "$TMP_FILE"
fi

echo "---------- EXPORT COMPLETED! -----------"
echo "-- Exported file: $EXPORT_DIR/${DB_NAME}_$DATE.tar.gz"

END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))

echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
