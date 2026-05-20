# Contributing Guide

## Development Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pyyaml
```

## Contribution Flow

1. Fork and create a feature branch.
2. Make focused changes with clear commit messages.
3. Update docs and model cards if behavior or artifacts changed.
4. Run validation:

```bash
python scripts/build_manifest.py --artifacts-dir artifacts --output models/model-manifest.json
python scripts/validate_repo.py --repo-root .
```

5. Open a pull request using the provided template.

## Model Addition Requirements

Every new model submission must include:

- An entry in `models/model-index.yaml`
- A corresponding model card in `modelcards/`
- Explicit upstream model and license details
- Quantization and conversion metadata
- Intended platform and minimum deployment target
- Basic quality/evaluation snapshot

## Documentation Requirements

Keep these in sync when applicable:

- `README.md`
- `docs/RELEASE_PROCESS.md`
- `CHANGELOG.md`

## Review Criteria

Pull requests are reviewed for:

- Reproducibility
- Licensing clarity
- Responsible use notes
- Metadata completeness
- CI validation pass
