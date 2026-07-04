#!/usr/bin/env bash
# Patch arc-one.agent.yaml connector URL from AWS_SERVICE_URL (CI / GHA).
set -euo pipefail

SRC="${1:-arc-one.agent.yaml}"
OUT="${2:-arc-one.agent.resolved.yaml}"
BASE="${AWS_SERVICE_URL:-}"

if [ -z "${BASE}" ]; then
  echo "AWS_SERVICE_URL not set — copying manifest unchanged" >&2
  cp "${SRC}" "${OUT}"
  exit 0
fi

BASE="${BASE%/}"
sed "s|__AWS_SERVICE_URL__/api/v1/chat|${BASE}/api/v1/chat|g" "${SRC}" > "${OUT}"
echo "Patched connector → ${BASE}/api/v1/chat"
