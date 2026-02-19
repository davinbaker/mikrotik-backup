#!/bin/bash
set -euo pipefail

# ── Config (override via environment variables) ──────────────────────────────
MIKROTIK_HOST="${MIKROTIK_HOST:?MIKROTIK_HOST is required}"
MIKROTIK_USER="${MIKROTIK_USER:-rclone-backup}"
MIKROTIK_PORT="${MIKROTIK_PORT:-22}"
SSH_KEY_PATH="${SSH_KEY_PATH:-/secrets/mikrotik_id_rsa}"

RCLONE_REMOTE="${RCLONE_REMOTE:-onedrive}"
RCLONE_PATH="${RCLONE_PATH:-MikroTik-Backups}"
RETAIN_DAYS="${RETAIN_DAYS:-30}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/tmp/mikrotik-backup"
BACKUP_NAME="mikrotik_${MIKROTIK_HOST}_${TIMESTAMP}"

# Copy SSH key to temp location with correct permissions (mounted file may be 0755)
TEMP_KEY="/tmp/mikrotik_id_rsa_$$"
cp "${SSH_KEY_PATH}" "${TEMP_KEY}"
chmod 600 "${TEMP_KEY}"
trap 'rm -f "${TEMP_KEY}"' EXIT
SSH_KEY_PATH="${TEMP_KEY}"
# ─────────────────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

mkdir -p "$BACKUP_DIR"

log "Connecting to MikroTik at ${MIKROTIK_HOST}:${MIKROTIK_PORT} as ${MIKROTIK_USER}"

SSH_OPTS="-i ${SSH_KEY_PATH} -p ${MIKROTIK_PORT} -o StrictHostKeyChecking=no -o ConnectTimeout=15"

# 1. Create a .backup file on the router then download it
log "Creating .backup on router..."
ssh $SSH_OPTS "${MIKROTIK_USER}@${MIKROTIK_HOST}" \
    "/system backup save name=${BACKUP_NAME} dont-encrypt=yes"

sleep 3  # give router a moment to finish writing

log "Downloading .backup file..."
scp $SSH_OPTS \
    "${MIKROTIK_USER}@${MIKROTIK_HOST}:/${BACKUP_NAME}.backup" \
    "${BACKUP_DIR}/${BACKUP_NAME}.backup"

# 2. Export plaintext config (human-readable)
log "Exporting plaintext config..."
ssh $SSH_OPTS "${MIKROTIK_USER}@${MIKROTIK_HOST}" \
    "/export terse" > "${BACKUP_DIR}/${BACKUP_NAME}.rsc"

# 3. Clean up backup file from router
log "Removing backup file from router..."
ssh $SSH_OPTS "${MIKROTIK_USER}@${MIKROTIK_HOST}" \
    "/file remove ${BACKUP_NAME}.backup" || true

# 4. Upload both files to OneDrive
log "Uploading to ${RCLONE_REMOTE}:${RCLONE_PATH}..."
rclone copy "${BACKUP_DIR}/" "${RCLONE_REMOTE}:${RCLONE_PATH}/" \
    --include "${BACKUP_NAME}.*" \
    --config /config/rclone.conf \
    -v

# 5. Prune old backups from OneDrive
log "Pruning backups older than ${RETAIN_DAYS} days from OneDrive..."
rclone delete "${RCLONE_REMOTE}:${RCLONE_PATH}/" \
    --min-age "${RETAIN_DAYS}d" \
    --config /config/rclone.conf \
    -v || true

# 6. Clean up local temp files
rm -rf "${BACKUP_DIR}"

log "Backup complete: ${BACKUP_NAME}.backup + ${BACKUP_NAME}.rsc"
