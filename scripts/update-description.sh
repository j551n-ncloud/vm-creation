#!/usr/bin/env bash
set -euo pipefail

GITLAB_URL="${GITLAB_URL:-}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
PROJECT_ID="${GITLAB_PROJECT_ID:-}"
ENVIRONMENT="${DEPLOY_ENV:-production}"
VERSION="${1:-}"
SERVICE="${2:-${CI_PROJECT_NAME:-unknown}}"

usage() {
  echo "Usage: $0 [VERSION] [SERVICE_NAME]"
  echo "  Env vars: GITLAB_URL, GITLAB_TOKEN, GITLAB_PROJECT_ID, DEPLOY_ENV"
  exit 1
}

if [[ -z "$GITLAB_URL" || -z "$GITLAB_TOKEN" || -z "$PROJECT_ID" ]]; then
  echo "ERROR: GITLAB_URL, GITLAB_TOKEN, GITLAB_PROJECT_ID must be set"
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "${CI_COMMIT_SHORT_SHA:-unknown}")
fi

DEPLOY_DATE=$(date "+%Y-%m-%d %H:%M")

case "$ENVIRONMENT" in
  staging)    ICON="🚀"; LABEL="STAGING" ;;
  production) ICON="🚀"; LABEL="PRODUCTION" ;;
  *)          ICON="🚀"; LABEL="${ENVIRONMENT^^}" ;;
esac

DEPLOY_LINE="${ICON} ${LABEL} | ${VERSION} | deployed ${DEPLOY_DATE} | ${SERVICE}"

# Read current description to preserve health line if present
CURRENT=$(curl --silent \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" | grep -o '"description":"[^"]*"' | cut -d'"' -f4 || echo "")

HEALTH_LINE=$(echo "$CURRENT" | grep -E "^(✅|❌)" || echo "")

if [[ -n "$HEALTH_LINE" ]]; then
  DESCRIPTION="${DEPLOY_LINE}
${HEALTH_LINE}"
else
  DESCRIPTION="${DEPLOY_LINE}"
fi

curl --silent --fail --request PUT \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  --data-urlencode "description=${DESCRIPTION}" \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" > /dev/null

echo "Updated: ${DEPLOY_LINE}"
