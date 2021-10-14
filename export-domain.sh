#!/bin/bash
set -o errexit  # script will exit if a command fails
set -o pipefail # catch | (pipe) fails. The exit status of the last command that threw a non-zero exit code is returned

source config.sh

# This script will export a tar file from incremental backups for the specified date and domain.

USAGE="-- Usage example \nexport-domain.sh 2021-10-15 domain.com /my/export/location \n-- NOTE: you can specify either a website domain or a child domain that belongs to a website"

# Assign arguments
DATE=$1
DOMAIN=$2
EXPORT_DIR=$3

# Checking required arguments
if [[ "$#" -lt 3 ]]; then
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

# Set script start time to calculate duration
START_TIME=$(date +%s)

# Set user repository
DOMAIN_REPO=$REPO_DOMAINS_DIR/$DOMAIN

# TODO - also add the option to export the tar inside the ssh backup dir

# Create export dir if it doesn't exist
if [ ! -d "$EXPORT_DIR" ]; then
    mkdir -p "$EXPORT_DIR"
fi

# Check if user repo exist
if [ ! -d "$DOMAIN_REPO/data" ]; then
    echo "-- ERROR: There is no backup for domain $DOMAIN."
    exit 3
fi

# Check if backup archive date exist for the given domain
if ! borg list "$DOMAIN_REPO" | grep -q "$DATE"; then
    echo "-- ERROR: There is no backup for domain $DOMAIN for date $DATE."
    echo "-- The following backups are available for this domain"
    borg list "$DOMAIN_REPO"
    exit 4
fi

read -p "Are you sure you want to export tar for domain $DOMAIN for date $DATE to location $EXPORT_DIR? " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    [[ "$0" = "$BASH_SOURCE" ]]
    echo
    echo "---------- EXPORT CANCELED! -----------"
    exit 1
fi

borg export-tar --tar-filter="gzip -9" "$DOMAIN_REPO"::"$DATE" "$EXPORT_DIR/${DOMAIN}_$DATE.tar.gz"

echo "---------- EXPORT COMPLETED! -----------"
echo "-- Exported file: $EXPORT_DIR/${DOMAIN}_$DATE.tar.gz"

END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))

echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
