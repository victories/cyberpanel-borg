#!/bin/bash

# This script will restore the domain to the given date backup

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

USAGE="-- Usage example \nrestore-domain.sh domain.com 2021-10-15 \n-- NOTE: you can specify either a website domain or a child domain that belongs to a website"

DOMAIN=$1
DATE=$2

# Checking required arguments
if [[ -z $DOMAIN || -z $DATE ]]; then
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

# Checking if given domain is a "main domain" aka website and getting the website owner (externalApp column in the db)
read -r WEBSITE DOMAIN_OWNER < <(echo "SELECT domain, externalApp FROM websiteFunctions_websites WHERE domain = '$DOMAIN'" | mysql cyberpanel -s)
if [[ -z $WEBSITE ]]; then

    # Domain was not found in main domains. We have to check if it is a child domain.
    # Checking if domain exists in cyberpanel child domains database
    read -r WEBSITE DOMAIN_OWNER CHILD_DOMAIN_PATH < <(echo "SELECT w.domain, w.externalApp, cd.path FROM websiteFunctions_childdomains cd LEFT JOIN websiteFunctions_websites w ON cd.master_id = w.id WHERE cd.domain = '$DOMAIN'" | mysql cyberpanel -s)
    if [[ -z $WEBSITE ]]; then
        echo "-- Domain $DOMAIN was not found in cyberpanel. Restoration is not possible. You have to create a website or a child domain into a website with this domain"
        exit 3
    fi
    DIR_TO_RESTORE="$CHILD_DOMAIN_PATH"
else
    # When the domain is not a child domain the files are stored inside the public_html folder
    DIR_TO_RESTORE="${HOME_DIR%/}/$WEBSITE/public_html"
fi

DOMAIN_REPO=$REPO_DOMAINS_DIR/$DOMAIN
# This is the path that can contain the ssh:// config in case we have a remote ssh backup location
DOMAIN_REPO_DESTINATION="$DOMAIN_REPO"

if [[ -n $SSH_HOST ]]; then
    # We don't have to add / before DOMAIN_REPO because it is already added in the config.sh
    DOMAIN_REPO_DESTINATION="$SSH_DESTINATION$DOMAIN_REPO"
fi

# Checking if backups exist for this domain
if ! "$CURRENT_DIR"/helpers/dir-exists.sh "$DOMAIN_REPO/data"; then
    echo "-- No repo found for domain $DOMAIN. Please make sure that you have backups for this domain"
    exit 4
fi

# Checking if we have backup for given date for this domain
if ! borg list "$DOMAIN_REPO_DESTINATION" | grep -q "$DATE"; then
    echo "-- No backup archive found for date $DATE. The following are available for this domain:"
    borg list "$DOMAIN_REPO_DESTINATION"
    exit 5
fi

read -p "Are you sure you want to restore domain $DOMAIN to date $DATE backup version? [y/n]" -n 1 -r
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

# Removing current files from the domain directory
echo "-- Removing old directory"
rm -rf "$DIR_TO_RESTORE"

# Recreating the directory
echo "-- Re-creating directory"
mkdir -p "$DIR_TO_RESTORE"

# Restoring the backup to the domain directory
echo "-- Restoring backup"

# This is a workaround. Borg will actually try to restore files in the home/domain.com directory because we are using the ${DIR_TO_RESTORE:1} as a restore pattern.
# Thus we need to be in the root dir, so that the restore is done in the right place.
# Unfortunately, it is not possible to use absolute paths for the restoration since borg will complain that "Include pattern '/home/domain.com/subdomain' never matched." if we just add $DIR_TO_RESTORE without removing the first /.
cd /

# Note that have to use ${DIR_TO_RESTORE:1} for the reason explained above.
borg extract --list "$DOMAIN_REPO_DESTINATION"::"$DATE" "${DIR_TO_RESTORE:1}"

# Fixing permissions
echo "-- Fixing directory and file ownership"
# The root folder that we restore should be owned by the group "nogroup"
# But all the children directories and files should be owned by the group with the same name as the user (e.g. examp9878)
# Otherwise we get a 404 error when trying to access the website and 403 if we try to access any location inside the website
chown -R "$DOMAIN_OWNER":"$DOMAIN_OWNER" "$DIR_TO_RESTORE"
chown "$DOMAIN_OWNER":nogroup "$DIR_TO_RESTORE"

echo "---------- RESTORATION COMPLETED! -----------"
END_TIME=$(date +%s)
RUN_TIME=$((END_TIME - START_TIME))
echo "-- Execution time: $(date -u -d @${RUN_TIME} +'%T')"
