#!/usr/bin/env bash
set -euo pipefail

GITLAB_URL="${GITLAB_URL:-}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
PROJECT_ID="${GITLAB_PROJECT_ID:-}"
LXC_ID="${LXC_ID:-$(hostname)}"
NODE_NAME="${NODE_NAME:-$(uname -n)}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --host)    HOST_IP="$2";    shift 2 ;;
    --project) PROJECT_ID="$2"; shift 2 ;;
    --lxc-id)  LXC_ID="$2";    shift 2 ;;
    --node)    NODE_NAME="$2";  shift 2 ;;
    *) shift ;;
  esac
done

check_docker() {
  if ! docker info &>/dev/null; then
    echo "UNHEALTHY"
    return
  fi
  stopped=$(docker ps --filter "status=exited" --filter "status=dead" -q | wc -l)
  [[ "$stopped" -gt 0 ]] && echo "UNHEALTHY" || echo "HEALTHY"
}

update_gitlab_description() {
  local status="$1"
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M")
  local icon
  [[ "$status" == "HEALTHY" ]] && icon="✅" || icon="❌"

  local health_line="${icon} ${status} | LXC:${LXC_ID} ${NODE_NAME} | ${timestamp}"

  if [[ -z "$GITLAB_URL" || -z "$GITLAB_TOKEN" || -z "$PROJECT_ID" ]]; then
    echo "GitLab vars not set, skipping description update"
    return 0
  fi

  # Read current description to preserve deploy line
  CURRENT=$(curl --silent \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" | grep -o '"description":"[^"]*"' | cut -d'"' -f4 || echo "")

  DEPLOY_LINE=$(echo "$CURRENT" | grep -E "^🚀" || echo "")

  if [[ -n "$DEPLOY_LINE" ]]; then
    DESCRIPTION="${DEPLOY_LINE}
${health_line}"
  else
    DESCRIPTION="${health_line}"
  fi

  curl --silent --request PUT \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    --data-urlencode "description=${DESCRIPTION}" \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" > /dev/null
}

STATUS=$(check_docker)
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "[${TIMESTAMP}] Health: ${STATUS} | LXC:${LXC_ID} | Node:${NODE_NAME}"

update_gitlab_description "$STATUS"
