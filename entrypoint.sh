#!/bin/bash
set -euo pipefail

CRON_SCHEDULE="${CRON_SCHEDULE:-0 2 * * *}"   # default: 2 AM daily
CRONTAB_FILE="/tmp/crontab"

echo "[entrypoint] Setting up cron: '${CRON_SCHEDULE}'"
echo "${CRON_SCHEDULE} /app/backup.sh" > "$CRONTAB_FILE"

echo "[entrypoint] Running initial backup now..."
/app/backup.sh || echo "[entrypoint] Initial backup failed — will retry on next schedule"

echo "[entrypoint] Starting supercronic..."
exec supercronic "$CRONTAB_FILE"
