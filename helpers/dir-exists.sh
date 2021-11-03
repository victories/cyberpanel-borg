#!/bin/bash

# This script will check if the given dir exists or not. It supports ssh destinations and local destinations

CURRENT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PARENT_DIR="$(dirname "${CURRENT_DIR}")"

source "$PARENT_DIR"/config.sh

DIR="${1#/}"

if [ -z "$DIR" ]; then
    echo "-- ERROR: Please give a directory to check"
    exit 1
fi

# Checking if we are using ssh destination
if [[ -z $SSH_HOST ]]; then
    # Local destination
    [[ -d $DIR ]] && exit 0 || exit 1
else
    # Remote destination
    # If dir starts with / we have to remove it
    if [[ $DIR == /* ]]; then
        DIR=${DIR:1}
    fi
    echo
    echo "chdir '$DIR'" | sftp $SFTP_PIPE_OPTIONS >/dev/null 2>&1 && exit 0 || exit 1
fi
