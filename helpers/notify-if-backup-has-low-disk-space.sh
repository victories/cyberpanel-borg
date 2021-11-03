#!/bin/bash

CURRENT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PARENT_DIR="$(dirname "${CURRENT_DIR}")"

source "$PARENT_DIR"/config.sh

BACKUP_DISK_STATS=$("$CURRENT_DIR"/get-backup-disk-space.sh)

USED_DISK_PERCENTAGE=$(echo "$BACKUP_DISK_STATS" | tail -1 | awk '{print $5}' | sed 's/%//g')

if [[ USED_DISK_PERCENTAGE -gt $LOW_DISK_SPACE_THRESHOLD ]]; then
    echo -e "\n\n\n-- WARNING: Backup disk space is low"
    echo "$BACKUP_DISK_STATS"

    # Send additional email to admin
    if [[ -n $ADMIN_EMAIL ]]; then
        echo -e "$BACKUP_DISK_STATS" | /usr/bin/mail -s "WARNING: Backup disk space is low" -a From:"$EMAIL_FROM_NAME"\<"$EMAIL_FROM_EMAIL"\> "$ADMIN_EMAIL"
    fi
fi
