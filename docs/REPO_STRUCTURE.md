# Repository Structure

- `.github/`: CI workflows, issue templates, PR template.
- `artifacts/`: Optional local staging directory for release assets.
- `docs/`: Operational and policy documentation.
- `modelcards/`: Per-model cards and metadata snapshots.
- `models/model-index.yaml`: Machine-readable source of truth for models.
- `models/model-manifest.json`: Generated checksums and file metadata.
- `scripts/build_manifest.py`: SHA256 and size manifest generation.
- `scripts/validate_repo.py`: Structural and metadata validation.

## Design Principles

- Single source of truth for model metadata (`model-index.yaml`).
- Human-readable model cards for each catalog entry.
- Artifact integrity through checksums.
- CI-enforced validation on pull requests.
