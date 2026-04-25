#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${TARGET_HOST:-}"
TARGET_PATH="${TARGET_PATH:-/opt}"
SERVICE_NAME="${SERVICE_NAME:-}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
RSYNC_CONFIG_SRC="${RSYNC_CONFIG_SRC:-}"
RSYNC_CONFIG_DEST="${RSYNC_CONFIG_DEST:-}"
SSH_KEY="${SSH_KEY:-}"

usage() {
  echo "Usage: $0 --host IP --service NAME [--tag TAG] [--rsync-src PATH] [--rsync-dest PATH]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --host)         TARGET_HOST="$2";       shift 2 ;;
    --service)      SERVICE_NAME="$2";      shift 2 ;;
    --tag)          IMAGE_TAG="$2";         shift 2 ;;
    --rsync-src)    RSYNC_CONFIG_SRC="$2";  shift 2 ;;
    --rsync-dest)   RSYNC_CONFIG_DEST="$2"; shift 2 ;;
    --help)         usage ;;
    *)              shift ;;
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
  rsync -avz --delete \
    -e "ssh $SSH_OPTS" \
    "$RSYNC_CONFIG_SRC" \
    "root@${TARGET_HOST}:${RSYNC_CONFIG_DEST}"
fi

echo "Deploy complete: $SERVICE_NAME on $TARGET_HOST"
