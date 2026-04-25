#!/usr/bin/env bash
set -euo pipefail

GITLAB_URL="${GITLAB_URL:-}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
PROJECT_ID="${GITLAB_PROJECT_ID:-}"
LXC_ID="${LXC_ID:-$(hostname)}"
NODE_NAME="${NODE_NAME:-$(uname -n)}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --project) PROJECT_ID="$2"; shift 2 ;;
    --lxc-id)  LXC_ID="$2";    shift 2 ;;
    --node)    NODE_NAME="$2";  shift 2 ;;
    *) shift ;;
  esac
done

check_docker() {
  if ! docker info &>/dev/null; then
    echo "UNHEALTHY"; return
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

  # Read current description — preserve deploy line and version line
  CURRENT=$(curl --silent \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" \
    | grep -o '"description":"[^"]*"' | cut -d'"' -f4 || echo "")

  DEPLOY_LINE=$(  printf '%s' "$CURRENT" | grep -E "^🚀"        || echo "")
  VERSION_LINE=$( printf '%s' "$CURRENT" | grep -Ev "^(🚀|✅|❌)" | head -1 || echo "")

  # Assemble description — skip empty lines
  DESCRIPTION=""
  [[ -n "$DEPLOY_LINE"  ]] && DESCRIPTION="${DEPLOY_LINE}"
  [[ -n "$VERSION_LINE" ]] && DESCRIPTION="${DESCRIPTION}
${VERSION_LINE}"
  DESCRIPTION="${DESCRIPTION}
${health_line}"

  curl --silent --request PUT \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    --data-urlencode "description=${DESCRIPTION}" \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" > /dev/null
}

STATUS=$(check_docker)
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "[${TIMESTAMP}] Health: ${STATUS} | LXC:${LXC_ID} | Node:${NODE_NAME}"

update_gitlab_description "$STATUS"
