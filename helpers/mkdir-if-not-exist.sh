#!/bin/bash

CURRENT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PARENT_DIR="$(dirname "${CURRENT_DIR}")"

source "$PARENT_DIR"/config.sh

DIR="$1"

if [ -z "$DIR" ]; then
    echo "No directory specified"
    exit 1
fi

# But we should first check if we are in ssh or plain filesystem as the commands differ
if [[ -z $SSH_HOST ]]; then
    # Plain file system
    mkdir -p "$DIR"
else
    # SSH filesystem. We must perform sftp actions
    # The following script will create the dir if not exists
    "$CURRENT_DIR"/sftp-mkdir.sh "$DIR"
fi
