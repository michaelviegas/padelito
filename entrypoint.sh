#!/bin/bash
set -e

# Create data file with empty values if it doesn't exist
if [ ! -f /app/padelito.data ]; then
    cat > /app/padelito.data <<EOF
TOKEN_ID=
CLUB_ID=
DAYS_TO_ADD=
COURT_IDS=
HOURS=
BOT_ID=
CHAT_ID=
EOF
fi

# Start cron daemon in background
service cron start

# Start Flask web app
exec gunicorn -w 1 -b 0.0.0.0:80 padelito_config:app
