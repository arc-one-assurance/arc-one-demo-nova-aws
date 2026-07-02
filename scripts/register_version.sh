#!/usr/bin/env bash
# Patch connector URL in manifest and register with Arc One.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -f .env.ci.local ]; then
  set -a
  # shellcheck disable=SC1091
  source .env.ci.local
  set +a
fi

BASE="${APP_RUNNER_URL:-}"
if [ -z "$BASE" ]; then
  echo "Set APP_RUNNER_URL in .env.ci.local (App Runner host, sin /api/v1/chat)" >&2
  exit 1
fi
BASE="${BASE%/}"
CHAT_URL="${BASE}/api/v1/chat"

TMP="$(mktemp)"
sed "s|https://__APP_RUNNER_URL__/api/v1/chat|${CHAT_URL}|g" arc-one.agent.yaml > "$TMP"

echo "→ Registering with connector: ${CHAT_URL}"
python scripts/register_arc_one_manifest.py "$TMP" "$@"
rm -f "$TMP"
