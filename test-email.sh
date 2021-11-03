#!/bin/bash

# This script just verifies that the notification emails work fine. Just remember to setup properly the config file before testing...

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"

source "$CURRENT_DIR"/config.sh

TMP_FILE=$(mktemp)

MAIL_MESSAGE="This is a test email to verify that backup notifications work. It should also have an empty temp file attached to verify that email attachment works"
MAIL_SUBJECT="Backup Notification Check"

echo -e "$MAIL_MESSAGE" | /usr/bin/mail -s "$MAIL_SUBJECT" -a From:"$EMAIL_FROM_NAME"\<"$EMAIL_FROM_EMAIL"\> "$ADMIN_EMAIL" -A "$TMP_FILE"

rm "$TMP_FILE"

echo "Email sent! Check your inbox..."
