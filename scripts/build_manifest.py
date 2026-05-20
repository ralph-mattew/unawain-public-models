#!/usr/bin/env python3
"""Build a JSON manifest with artifact checksums and sizes.

Reads models/model-index.yaml and computes metadata for each model artifact.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    if path.is_dir():
        files = sorted(p for p in path.rglob("*") if p.is_file())
        for file_path in files:
            digest.update(str(file_path.relative_to(path)).encode("utf-8"))
            with file_path.open("rb") as f:
                for chunk in iter(lambda: f.read(1024 * 1024), b""):
                    digest.update(chunk)
    else:
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                digest.update(chunk)
    return digest.hexdigest()


def size_bytes(path: Path) -> int:
    if path.is_file():
        return path.stat().st_size
    if path.is_dir():
        return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())
    return 0


def resolve_artifact(repo_root: Path, model: dict[str, Any], artifacts_dir: Path) -> Path | None:
    source_path = model.get("source_path", "")
    artifact_filename = model.get("artifact_filename", "")

    candidates = []
    if source_path:
        candidates.append((repo_root / source_path).resolve())
    if artifact_filename:
        candidates.append((artifacts_dir / artifact_filename).resolve())

    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".", help="Repository root path")
    parser.add_argument("--index", default="models/model-index.yaml", help="Path to model index")
    parser.add_argument("--artifacts-dir", default="artifacts", help="Fallback artifacts directory")
    parser.add_argument("--output", default="models/model-manifest.json", help="Manifest output path")
    parser.add_argument("--fail-missing", action="store_true", help="Fail if any artifact is missing")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    index_path = (repo_root / args.index).resolve()
    artifacts_dir = (repo_root / args.artifacts_dir).resolve()
    output_path = (repo_root / args.output).resolve()

    with index_path.open("r", encoding="utf-8") as f:
        index_data = yaml.safe_load(f)

    models = index_data.get("models", [])
    manifest_models = []
    missing = []

    for model in models:
        artifact_path = resolve_artifact(repo_root, model, artifacts_dir)
        entry = {
            "id": model.get("id"),
            "name": model.get("name"),
            "artifact_filename": model.get("artifact_filename"),
            "resolved_path": str(artifact_path) if artifact_path else None,
            "exists": bool(artifact_path),
            "sha256": sha256_path(artifact_path) if artifact_path else None,
            "size_bytes": size_bytes(artifact_path) if artifact_path else None,
            "quantization": model.get("quantization"),
            "format": model.get("format"),
        }
        if not artifact_path:
            missing.append(model.get("id", "unknown"))
        manifest_models.append(entry)

    manifest = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "model_count": len(manifest_models),
        "missing_count": len(missing),
        "missing_ids": missing,
        "models": manifest_models,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

    print(f"Wrote manifest: {output_path}")
    print(f"Models: {len(manifest_models)} | Missing artifacts: {len(missing)}")

    if args.fail_missing and missing:
        print("Missing artifact IDs:")
        for item in missing:
            print(f"- {item}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
