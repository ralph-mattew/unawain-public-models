# Unawain Public Models

Production-ready, quantized on-device models for the Unawain stack, with reproducible conversion pipelines and release-quality documentation.

## Goals

- Publish quantized model artifacts with clear provenance.
- Keep model metadata machine-readable and human-readable.
- Enforce reproducibility, validation, and release checks.
- Make downstream integration (iOS/Core ML) straightforward.

## Repository Layout

- `models/model-index.yaml`: Canonical machine-readable model catalog.
- `modelcards/`: Per-model cards (capabilities, limits, eval snapshots, licenses).
- `artifacts/`: Optional local staging area for release artifacts.
- `scripts/build_manifest.py`: Generates checksums and size metadata.
- `scripts/validate_repo.py`: Validates index, model cards, and artifacts.
- `docs/`: Development and release documentation.
- `.github/`: CI workflow, issue templates, PR template.

## Current Models

See `models/model-index.yaml` and `modelcards/` for details.

Current tracked packages include:

- `NllbEncoder.mlpackage` (int8)
- `NllbDecoderStep.mlpackage` (int8)
- `NllbEncoder_pruned.mlpackage` (int8)
- `NllbDecoderStep_pruned.mlpackage` (int8)
- `BartEncoder.mlpackage` (int8)
- `BartDecoderStep.mlpackage` (int8)
- `QwenSummarizer.mlpackage` (int8)

## Quick Start

1. Create virtual environment and install tooling:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pyyaml
```

2. Build checksums and manifest from staged artifacts:

```bash
python scripts/build_manifest.py --artifacts-dir artifacts --output models/model-manifest.json
```

3. Validate repository integrity:

```bash
python scripts/validate_repo.py --repo-root .
```

## Versioning and Releases

- Use semantic version tags: `vMAJOR.MINOR.PATCH`
- Update `CHANGELOG.md` for every release
- Attach artifact files plus generated `models/model-manifest.json`

Release process is documented in `docs/RELEASE_PROCESS.md`.

## License Notes

This repository includes both code and model artifacts.

- Repository code is licensed under Apache-2.0 (`LICENSE`).
- Model artifacts may inherit upstream or dataset-specific licenses.
- Each model card must explicitly state upstream model and license terms.

## Security and Responsible Use

Please read:

- `SECURITY.md`
- `docs/RESPONSIBLE_USE.md`

## Contributing

See `CONTRIBUTING.md`.
