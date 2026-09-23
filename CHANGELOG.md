# Changelog

All notable changes to this repository are documented in this file.

## [Unreleased]

### Added

- `benchmarks/`: Core ML latency harness (`bench_coreml_latency.py`), experiment protocol, and results for experiment 001 (host latency pilot, full vs pruned NLLB int8 on Apple M4 Pro).
- `benchmarks/swift/`: native Swift harness (macOS command-line tool and iOS app) with compute-plan op placement, memory footprint, and crash-resumable runs; protocol for experiment 002 (iPhone latency) and a Mac harness check reproducing 001.

### Fixed

- `scripts/build_manifest.py` wrote absolute local paths into `resolved_path`; it now writes repo-relative paths (or the file name for anything outside the repository).

### Changed

- README no longer describes the models as production-ready; states that benchmarks marked "Pending" have not been measured.
- Model cards: NLLB input/output sections corrected to the shapes declared by the released artifacts; "Apple Neural Engine preferred" replaced with measured compute placement (CPU; GPU compile aborts on macOS 26.5.1); host latency rows added; conversion-script references marked as not yet included in this repository.

## [0.1.0] - 2026-05-20

### Added

- Initial public repository scaffold for Unawain quantized models.
- Model index (`models/model-index.yaml`) and model cards.
- Manifest and validation scripts.
- GitHub CI workflow, issue templates, and PR template.
- Governance docs: contributing, security, code of conduct.
- Hardened per-model license metadata (SPDX, source, commercial-use, attribution, terms summary).
- Latency and quality benchmark table sections across all model cards.
- Release-notes draft for GitHub Releases (`docs/RELEASE_NOTES_v0.1.0.md`).
