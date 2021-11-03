#!/bin/bash

CURRENT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PARENT_DIR="$(dirname "${CURRENT_DIR}")"

source "$PARENT_DIR"/config.sh

if [[ -z $SSH_HOST ]]; then
    BACKUP_DISK_STATS=$(df -h "$BACKUP_DIR")
else
    # Using tail -2 to remove the "sftp> df -h" line from the top
    BACKUP_DISK_STATS=$(echo "df -h" | sftp $SFTP_PIPE_OPTIONS | tail -2)
fi

echo "$BACKUP_DISK_STATS"
