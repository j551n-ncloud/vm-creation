#!/usr/bin/env bash
set -euo pipefail

GITLAB_URL="${GITLAB_URL:-}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
PROJECT_ID="${GITLAB_PROJECT_ID:-}"
ENVIRONMENT="${DEPLOY_ENV:-production}"
LXC_ID="${LXC_ID:-}"
VERSION="${1:-}"
SERVICE="${2:-${CI_PROJECT_NAME:-unknown}}"

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

LXC_PART=""
[[ -n "$LXC_ID" ]] && LXC_PART=" | LXC:${LXC_ID}"

DEPLOY_LINE="${ICON} ${LABEL} | ${VERSION}${LXC_PART} | deployed ${DEPLOY_DATE} | ${SERVICE}"

# Version line only set on production releases (git tag)
VERSION_LINE=""
if [[ "$ENVIRONMENT" == "production" ]]; then
  VERSION_LINE="${VERSION} | released $(date '+%Y-%m-%d') | ${SERVICE}"
fi

# Read current description — preserve health line and existing version line
CURRENT=$(curl --silent \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" \
  | grep -o '"description":"[^"]*"' | cut -d'"' -f4 || echo "")

HEALTH_LINE=$(printf '%s' "$CURRENT" | grep -E "^(✅|❌)" || echo "")

# For staging keep existing version line if present; for production overwrite it
if [[ "$ENVIRONMENT" != "production" ]]; then
  EXISTING_VERSION=$(printf '%s' "$CURRENT" | grep -Ev "^(🚀|✅|❌)" | head -1 || echo "")
  [[ -n "$EXISTING_VERSION" ]] && VERSION_LINE="$EXISTING_VERSION"
fi

# Assemble description — skip empty lines
DESCRIPTION="$DEPLOY_LINE"
[[ -n "$VERSION_LINE"  ]] && DESCRIPTION="${DESCRIPTION}
${VERSION_LINE}"
[[ -n "$HEALTH_LINE"   ]] && DESCRIPTION="${DESCRIPTION}
${HEALTH_LINE}"

curl --silent --fail --request PUT \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  --data-urlencode "description=${DESCRIPTION}" \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" > /dev/null

echo "Updated: ${DEPLOY_LINE}"
[[ -n "$VERSION_LINE" ]] && echo "Version: ${VERSION_LINE}"
