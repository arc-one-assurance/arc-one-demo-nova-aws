#!/usr/bin/env python3
"""
Validate MADRE v1.1 manifest structure (mandatory fields + API-aligned rules).

Runs locally in CI before drift check and Arc One dry-run.

Usage:
  python scripts/validate_manifest.py arc-one.agent.yaml
  python scripts/validate_manifest.py arc-one.agent.resolved.yaml --no-placeholder
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

from manifest_madre_v11 import ManifestValidationError, validate_madre_manifest


def _load_yaml(path: str) -> dict:
    data = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: manifest must be a YAML mapping")
    return data


def main() -> None:
    ap = argparse.ArgumentParser(description="Validate MADRE v1.1 manifest structure")
    ap.add_argument("manifest", nargs="?", default="arc-one.agent.yaml")
    ap.add_argument(
        "--no-placeholder",
        action="store_true",
        help="Reject __AWS_SERVICE_URL__ in connector.endpointUrl (use after patch step)",
    )
    ap.add_argument(
        "--optional-connector",
        action="store_true",
        help="Do not require connector block (not recommended for assurance PoC)",
    )
    args = ap.parse_args()

    manifest = _load_yaml(args.manifest)
    try:
        validate_madre_manifest(
            manifest,
            allow_connector_placeholder=not args.no_placeholder,
            require_connector=not args.optional_connector,
        )
    except ManifestValidationError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1) from exc

    name = manifest.get("name", "?")
    version = manifest.get("agent_version") or manifest.get("agentVersion") or "?"
    print(f"Manifest OK · MADRE v1.1 · {name} · {version}")


if __name__ == "__main__":
    main()
