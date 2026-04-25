#!/usr/bin/env bash
set -euo pipefail

GITLAB_URL="${GITLAB_URL:-}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"
PROJECT_ID="${GITLAB_PROJECT_ID:-}"

if [[ -z "$GITLAB_URL" || -z "$GITLAB_TOKEN" || -z "$PROJECT_ID" ]]; then
  echo "ERROR: GITLAB_URL, GITLAB_TOKEN, GITLAB_PROJECT_ID must be set"
  exit 1
fi

VERSION="${1:-}"
SERVICE="${2:-$CI_PROJECT_NAME}"

if [[ -z "$VERSION" ]]; then
  VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")
fi

DEPLOY_DATE=$(date "+%Y-%m-%d")
DESCRIPTION="${VERSION} | deployed ${DEPLOY_DATE} | ${SERVICE}"

curl --silent --fail --request PUT \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  --data-urlencode "description=${DESCRIPTION}" \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}"

echo "Updated project description: ${DESCRIPTION}"
