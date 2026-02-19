#!/bin/bash
set -euo pipefail

CRON_SCHEDULE="${CRON_SCHEDULE:-0 2 * * *}"

# Parse hour and minute from cron expression (minute hour ...)
CRON_MINUTE=$(echo "$CRON_SCHEDULE" | awk '{print $1}')
CRON_HOUR=$(echo "$CRON_SCHEDULE"   | awk '{print $2}')

run_backup() {
    /app/backup.sh || echo "[scheduler] Backup failed — will retry at next scheduled time"
}

echo "[entrypoint] Schedule: '${CRON_SCHEDULE}' (daily at ${CRON_HOUR}:$(printf '%02d' "$CRON_MINUTE"))"
echo "[entrypoint] Running initial backup now..."
run_backup

while true; do
    NOW=$(date +%s)
    TARGET=$(date -d "$(date +%Y-%m-%d) ${CRON_HOUR}:$(printf '%02d' "$CRON_MINUTE"):00" +%s 2>/dev/null \
             || date -j -f "%Y-%m-%d %H:%M:%S" "$(date +%Y-%m-%d) ${CRON_HOUR}:$(printf '%02d' "$CRON_MINUTE"):00" +%s)

    # If target already passed today, aim for tomorrow
    [ "$TARGET" -le "$NOW" ] && TARGET=$((TARGET + 86400))

    SLEEP=$(( TARGET - NOW ))
    echo "[scheduler] Next backup in ${SLEEP}s ($(date -d "@${TARGET}" 2>/dev/null || date -r "${TARGET}"))"
    sleep "$SLEEP"

    run_backup
done
