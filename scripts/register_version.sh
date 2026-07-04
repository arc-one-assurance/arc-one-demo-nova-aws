#!/usr/bin/env bash
# Patch connector URL and register with Arc One (local dev).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -f .env.ci.local ]; then
  set -a
  # shellcheck disable=SC1091
  source .env.ci.local
  set +a
fi

if ! command -v arc-one-manifest >/dev/null 2>&1; then
  echo "Install: pip install git+https://github.com/arc-one-assurance/arc-one-manifest-tools@v1.0.0" >&2
  exit 1
fi

BASE="${AWS_SERVICE_URL:-${APP_RUNNER_URL:-}}"
if [ -z "$BASE" ]; then
  echo "Set AWS_SERVICE_URL in .env.ci.local (ALB base URL, sin /api/v1/chat)" >&2
  exit 1
fi

chmod +x .github/scripts/patch-manifest-connector.sh
AWS_SERVICE_URL="$BASE" .github/scripts/patch-manifest-connector.sh \
  arc-one.agent.yaml arc-one.agent.resolved.yaml

echo "→ Registering with resolved manifest"
arc-one-manifest register arc-one.agent.resolved.yaml "$@"
