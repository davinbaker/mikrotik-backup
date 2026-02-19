#!/bin/bash
set -euo pipefail

CRON_SCHEDULE="${CRON_SCHEDULE:-0 2 * * *}"   # default: 2 AM daily

echo "[entrypoint] Setting up cron: '${CRON_SCHEDULE}'"

# Write crontab for backup user
echo "${CRON_SCHEDULE} /app/backup.sh >> /proc/1/fd/1 2>> /proc/1/fd/2" \
    | crontab -u backup -

echo "[entrypoint] Running initial backup now..."
/app/backup.sh || echo "[entrypoint] Initial backup failed — will retry on next schedule"

echo "[entrypoint] Starting crond..."
exec crond -f -l 2
