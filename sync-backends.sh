#!/usr/bin/env bash

# ========================
# CONFIGURATION
# ========================
REMOTE_USER="ubuntu"
REMOTE_HOST="simplevm.bi.denbi.de"
REMOTE_DIR="/var/forc"

LOCAL_USER_DIR="/home/ubuntu/forc"
TARGET_DIR="/var/forc"
SERVICE_NAME="openresty"

SSH_KEY="/home/ubuntu/.ssh/id_rsa"
SSH_CONFIG="/home/ubuntu/.ssh/config"

RSYNC_REMOTE_OPTS="-avz --itemize-changes --delete --progress"
RSYNC_LOCAL_OPTS="-avz --itemize-changes --delete"

LOG_FILE="/var/log/sync-forc.log"

# ========================
# STEP 1: Sync remote → ubuntu home
# ========================
echo "[$(date)] Step 1: Sync remote folder to $LOCAL_USER_DIR" | tee -a "$LOG_FILE"

mkdir -p "$LOCAL_USER_DIR"

sudo -u ubuntu rsync $RSYNC_REMOTE_OPTS \
    -e "ssh -i $SSH_KEY -F $SSH_CONFIG" \
    --rsync-path="sudo rsync" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" \
    "$LOCAL_USER_DIR/" | tee -a "$LOG_FILE"

REMOTE_STATUS=${PIPESTATUS[0]}
echo "[$(date)] rsync remote exit code: $REMOTE_STATUS" | tee -a "$LOG_FILE"

if [ $REMOTE_STATUS -ne 0 ] && [ $REMOTE_STATUS -ne 24 ]; then
    echo "[$(date)] Error syncing remote folder. Exiting." | tee -a "$LOG_FILE"
    exit 1
fi

# ========================
# STEP 2: Compute checksum before local sync
# ========================
echo "[$(date)] Computing checksum of $TARGET_DIR before sync..." | tee -a "$LOG_FILE"
if [ -d "$TARGET_DIR" ]; then
    OLD_HASH=$(find "$TARGET_DIR" -type f -exec sha256sum {} \; | sha256sum)
else
    OLD_HASH=""
fi

# ========================
# STEP 3: Sync ubuntu home → /var/forc
# ========================
echo "[$(date)] Step 2: Sync $LOCAL_USER_DIR → $TARGET_DIR" | tee -a "$LOG_FILE"

rsync $RSYNC_LOCAL_OPTS "$LOCAL_USER_DIR/" "$TARGET_DIR/" | tee -a "$LOG_FILE"

# ========================
# STEP 4: Compute checksum after sync
# ========================
echo "[$(date)] Computing checksum of $TARGET_DIR after sync..." | tee -a "$LOG_FILE"
NEW_HASH=$(find "$TARGET_DIR" -type f -exec sha256sum {} \; | sha256sum)

# ========================
# STEP 5: Detect changes and restart service
# ========================
if [ "$OLD_HASH" != "$NEW_HASH" ]; then
    echo "[$(date)] File contents changed. Restarting service $SERVICE_NAME..." | tee -a "$LOG_FILE"
    systemctl restart "$SERVICE_NAME"
else
    echo "[$(date)] No changes in file contents. Service will NOT restart." | tee -a "$LOG_FILE"
fi

echo "[$(date)] Done." | tee -a "$LOG_FILE"
