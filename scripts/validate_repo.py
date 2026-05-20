#!/usr/bin/env python3
"""Validate repository structure and metadata consistency."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import yaml


REQUIRED_TOP_LEVEL = [
    "README.md",
    "LICENSE",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "CHANGELOG.md",
    "models/model-index.yaml",
    "docs/RELEASE_PROCESS.md",
    "docs/RESPONSIBLE_USE.md",
]


REQUIRED_MODEL_FIELDS = [
    "id",
    "name",
    "family",
    "task",
    "format",
    "quantization",
    "artifact_filename",
    "source_path",
    "model_card",
    "upstream_model",
    "upstream_license",
    "upstream_license_spdx",
    "upstream_license_source",
    "commercial_use",
    "attribution_required",
    "upstream_terms_summary",
]


def check_file_exists(repo_root: Path, rel_path: str, errors: list[str]) -> None:
    if not (repo_root / rel_path).exists():
        errors.append(f"Missing required file: {rel_path}")


def validate_index(repo_root: Path, errors: list[str], warnings: list[str]) -> None:
    index_path = repo_root / "models/model-index.yaml"
    with index_path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    models: list[dict[str, Any]] = data.get("models", [])
    if not models:
        errors.append("model-index.yaml contains no models")
        return

    seen_ids: set[str] = set()
    for model in models:
        model_id = model.get("id", "<missing-id>")

        for field in REQUIRED_MODEL_FIELDS:
            if field not in model or model.get(field) in (None, ""):
                errors.append(f"{model_id}: missing required field '{field}'")

        if model_id in seen_ids:
            errors.append(f"Duplicate model id: {model_id}")
        seen_ids.add(model_id)

        model_card = model.get("model_card")
        source_path = model.get("source_path")
        if model_card and not (repo_root / model_card).exists():
            errors.append(f"{model_id}: missing model card at {model_card}")

        if source_path and not (repo_root / source_path).exists():
            warnings.append(f"{model_id}: source artifact not found at {source_path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".", help="Repository root")
    parser.add_argument("--strict-artifacts", action="store_true", help="Treat missing source artifacts as errors")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    errors: list[str] = []
    warnings: list[str] = []

    for rel_path in REQUIRED_TOP_LEVEL:
        check_file_exists(repo_root, rel_path, errors)

    index_file = repo_root / "models/model-index.yaml"
    if index_file.exists():
        validate_index(repo_root, errors, warnings)

    if args.strict_artifacts:
        errors.extend(warnings)
        warnings = []

    if warnings:
        print("WARNINGS:")
        for msg in warnings:
            print(f"- {msg}")

    if errors:
        print("ERRORS:")
        for msg in errors:
            print(f"- {msg}")
        return 1

    print("Repository validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
