# Release Process

## Preconditions

- `models/model-index.yaml` is updated.
- All changed models have updated model cards.
- Artifacts are staged in `artifacts/` (or attached directly during GitHub release).

## 1. Generate Manifest

```bash
python scripts/build_manifest.py --artifacts-dir artifacts --output models/model-manifest.json
```

## 2. Validate Repository

```bash
python scripts/validate_repo.py --repo-root .
```

## 3. Update Changelog

Add a version section in `CHANGELOG.md` with:

- Added/changed/removed models
- Quantization/conversion changes
- Breaking compatibility notes

## 4. Tag and Push

```bash
git tag vX.Y.Z
git push origin main --tags
```

## 5. Create GitHub Release

Attach:

- Model artifacts (`.mlpackage` as zipped bundles if needed)
- `models/model-manifest.json`
- Any evaluation snapshots

## 6. Post-Release Verification

- Download release assets and verify SHA256 matches manifest.
- Confirm model index and release notes are aligned.
- Confirm model cards include release tag.
