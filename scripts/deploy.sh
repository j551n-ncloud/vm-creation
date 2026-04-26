#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${TARGET_HOST:-}"
TARGET_PATH="${TARGET_PATH:-/opt}"
SERVICE_NAME="${SERVICE_NAME:-}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
RSYNC_CONFIG_SRC="${RSYNC_CONFIG_SRC:-}"
RSYNC_CONFIG_DEST="${RSYNC_CONFIG_DEST:-}"
RSYNC_BACKUP_DEST="${RSYNC_BACKUP_DEST:-}"
SSH_KEY="${SSH_KEY:-}"
RSYNC_TIMEOUT="${RSYNC_TIMEOUT:-30}"
RSYNC_BW_LIMIT="${RSYNC_BW_LIMIT:-0}"

usage() {
  echo "Usage: $0 --host IP --service NAME [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --host          Target LXC IP (required)"
  echo "  --service       Service name (required)"
  echo "  --tag           Docker image tag (default: latest)"
  echo "  --ssh-key       Path to SSH private key"
  echo "  --rsync-src     Local config path to sync"
  echo "  --rsync-dest    Remote destination path for config"
  echo "  --backup-dest   Remote path for rsync backup (e.g. /opt/backups/service-a)"
  echo "  --timeout       rsync network timeout in seconds (default: 30)"
  echo "  --bwlimit       rsync bandwidth limit in KB/s, 0=unlimited (default: 0)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --host)         TARGET_HOST="$2";       shift 2 ;;
    --service)      SERVICE_NAME="$2";      shift 2 ;;
    --tag)          IMAGE_TAG="$2";         shift 2 ;;
    --ssh-key)      SSH_KEY="$2";           shift 2 ;;
    --rsync-src)    RSYNC_CONFIG_SRC="$2";  shift 2 ;;
    --rsync-dest)   RSYNC_CONFIG_DEST="$2"; shift 2 ;;
    --backup-dest)  RSYNC_BACKUP_DEST="$2"; shift 2 ;;
    --timeout)      RSYNC_TIMEOUT="$2";     shift 2 ;;
    --bwlimit)      RSYNC_BW_LIMIT="$2";    shift 2 ;;
    --help)         usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$TARGET_HOST" || -z "$SERVICE_NAME" ]] && usage

SSH_OPTS="-o StrictHostKeyChecking=no -o BatchMode=yes"
[[ -n "$SSH_KEY" ]] && SSH_OPTS="$SSH_OPTS -i $SSH_KEY"

echo "Deploying $SERVICE_NAME:$IMAGE_TAG to $TARGET_HOST"

ssh $SSH_OPTS root@"$TARGET_HOST" bash <<EOF
  set -e
  cd ${TARGET_PATH}/${SERVICE_NAME}
  export IMAGE_TAG=${IMAGE_TAG}
  docker compose pull
  docker compose up -d --remove-orphans
  docker system prune -f --filter "until=24h"
EOF

if [[ -n "$RSYNC_CONFIG_SRC" && -n "$RSYNC_CONFIG_DEST" ]]; then
  echo "Syncing config: $RSYNC_CONFIG_SRC -> $TARGET_HOST:$RSYNC_CONFIG_DEST"

  RSYNC_OPTS=(
    -avz
    --delete
    --timeout="${RSYNC_TIMEOUT}"
    --exclude=".env"
    --exclude="secrets/"
    --exclude="*.key"
    --exclude="*.pem"
    --stats
    -e "ssh ${SSH_OPTS}"
  )

  [[ "$RSYNC_BW_LIMIT" -gt 0 ]] && RSYNC_OPTS+=(--bwlimit="${RSYNC_BW_LIMIT}")

  if [[ -n "$RSYNC_BACKUP_DEST" ]]; then
    BACKUP_STAMP=$(date +%Y%m%d-%H%M%S)
    RSYNC_OPTS+=(--backup --backup-dir="${RSYNC_BACKUP_DEST}/${BACKUP_STAMP}")
    echo "Backup enabled: ${RSYNC_BACKUP_DEST}/${BACKUP_STAMP}"
  fi

  rsync "${RSYNC_OPTS[@]}" \
    "$RSYNC_CONFIG_SRC" \
    "root@${TARGET_HOST}:${RSYNC_CONFIG_DEST}"
fi

echo "Deploy complete: $SERVICE_NAME on $TARGET_HOST"
