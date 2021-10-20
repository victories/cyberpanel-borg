#!/bin/bash
set -o nounset # exit when script tries to use undeclared variables.
set -o errexit # script will exit if a command fails

# This script will recursively create a dir if not exists

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

DIR=$1

if [[ -z $DIR ]]; then
    echo "-- Please set a directory to be created"
    echo "-- Usage: sftp-create-dir-recursively.sh the/directory/to/be/created"
    exit 1
fi

# IFS stands for "internal field separator". It is used by the shell to determine how to do word splitting, i. e. how to recognize word boundaries. More here https://unix.stackexchange.com/a/184867
IFS=/ read -r -a DIRS <<<"$DIR"

# This is usefull to add the next child dir to be created as a string (e.g. dir1, then dir1/dir2 and then dir1/dir2/dir3)
DIR_ACCUMULATOR=()

for DIR in "${DIRS[@]}"; do
    # This is to catch the empty string '' which is created when the given dir starts with a /
    if [[ ${#DIR} -ne 0 ]]; then
        DIR_ACCUMULATOR+=("$DIR")
        DIR_TO_CREATE=$(
            IFS=/
            echo "${DIR_ACCUMULATOR[*]}"
        )
        # We have to check if the dir already exists. Otherwise mkdir fails
        if ! echo "chdir '$DIR_TO_CREATE'" | sftp $SFTP_PIPE_OPTIONS >/dev/null 2>&1; then
            echo "mkdir '$DIR_TO_CREATE'" | sftp $SFTP_PIPE_OPTIONS >/dev/null 2>&1
        fi
    fi
done
