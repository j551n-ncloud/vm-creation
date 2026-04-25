#!/usr/bin/env bash
set -euo pipefail

GITLAB_URL="${GITLAB_URL:-}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
PROJECT_ID="${GITLAB_PROJECT_ID:-}"
LXC_ID="${LXC_ID:-$(hostname)}"
NODE_NAME="${NODE_NAME:-$(uname -n)}"

usage() {
  echo "Usage: $0 [--host IP] [--project PROJECT_ID]"
  echo "  Env vars: GITLAB_URL, GITLAB_TOKEN, GITLAB_PROJECT_ID, LXC_ID, NODE_NAME"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --host) HOST_IP="$2"; shift 2 ;;
    --project) PROJECT_ID="$2"; shift 2 ;;
    --help) usage ;;
    *) shift ;;
  esac
done

check_docker() {
  if ! docker info &>/dev/null; then
    echo "UNHEALTHY"
    return 1
  fi

  stopped=$(docker ps --filter "status=exited" --filter "status=dead" -q | wc -l)
  if [[ $stopped -gt 0 ]]; then
    echo "UNHEALTHY"
    return 1
  fi

  echo "HEALTHY"
  return 0
}

update_gitlab_description() {
  local status="$1"
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M")

  if [[ "$status" == "HEALTHY" ]]; then
    icon="✅"
  else
    icon="❌"
  fi

  description="${icon} ${status} | LXC:${LXC_ID} ${NODE_NAME} | ${timestamp}"

  if [[ -z "$GITLAB_URL" || -z "$GITLAB_TOKEN" || -z "$PROJECT_ID" ]]; then
    echo "GitLab vars not set, skipping description update"
    return 0
  fi

  curl --silent --request PUT \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    --data-urlencode "description=${description}" \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" \
    > /dev/null
}

STATUS=$(check_docker)
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "[${TIMESTAMP}] Health: ${STATUS} | LXC:${LXC_ID} | Node:${NODE_NAME}"

update_gitlab_description "$STATUS"
