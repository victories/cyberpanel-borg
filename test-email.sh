#!/bin/bash

# This script just verifies that the notification emails work fine. Just remember to setup properly the config file before testing...

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

mail -s 'Backup Notification' -a From:"$EMAIL_FROM_NAME"\<"$EMAIL_FROM_EMAIL"\> "$ADMIN_EMAIL" <<<'This is a test email to verify that backup notifications work.'
