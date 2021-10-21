#!/bin/bash

# This script will display a list of the excluded files in the given domain directory

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

USAGE="-- Usage example \ntest-file-exclude.sh domain.com \n-- NOTE: you can specify either a website domain or a child domain that belongs to a website"
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
    DIR_FOR_BACKUP="$HOME_DIR/$WEBSITE/public_html"
fi

# Set borg repo path
DOMAIN_REPO=$REPO_DOMAINS_DIR/$DOMAIN

# This doesn't make any difference, but I added that to avoid having a fixed dummy date
DATE=$(date +'%F')

echo "-- The following files will NOT be backed up for domain $DOMAIN"

# This will just display the excluded files list without actually running the bakcup (dry run)
borg create --list --dry-run "$DOMAIN_REPO"::"$DATE" "$DIR_FOR_BACKUP" --exclude-from=backup-file-exclude.lst --filter=x # --filter=x will make sure that only the excluded files are displayed
