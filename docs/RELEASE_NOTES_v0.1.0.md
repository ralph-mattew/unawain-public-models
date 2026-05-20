# Unawain Public Models v0.1.0

Initial public release of the Unawain quantized model repository, including model cataloging, governance, validation tooling, and release automation for reusable on-device model delivery.

## Highlights

- Introduced a machine-readable model catalog with per-model metadata.
- Published model cards for all currently tracked Core ML artifacts.
- Added repository-level governance and contribution standards.
- Added CI validation and manifest generation for release integrity.
- Added checksum manifest generation for artifact verification.

## Included Model Artifacts

- NllbEncoder.mlpackage
- NllbDecoderStep.mlpackage
- NllbEncoder_pruned.mlpackage
- NllbDecoderStep_pruned.mlpackage
- BartEncoder.mlpackage
- BartDecoderStep.mlpackage
- QwenSummarizer.mlpackage

## Documentation and Process

This release includes:

- Contributor guidance and code of conduct
- Security disclosure policy
- Responsible use guidance
- Release process documentation
- Model card template for future model additions

## License and Compliance Notes

- NLLB-derived artifacts are tracked with CC-BY-NC-4.0 metadata and explicit non-commercial use constraints.
- DistilBART and Qwen-derived artifacts are tracked with Apache-2.0 metadata.
- Model index now includes SPDX, license source, commercial-use flag, attribution requirements, and terms summary per model.

## Benchmarking Status

- Benchmark table sections are now present in every model card.
- Upstream DistilBART reference metrics are included where applicable.
- On-device latency and quality measurements are marked Pending where release-grade internal runs are not yet published.

## Breaking Changes

- None.

## Known Gaps

- Device-specific on-device benchmark results are pending publication for several artifacts.
- Additional evaluation datasets and task-specific quality metrics will be added in future releases.

## Upgrade Notes

- Consumers should use models/model-index.yaml as the source of truth for artifact metadata.
- Validate downloads against models/model-manifest.json checksums after release asset download.

## Acknowledgments

This release builds on upstream open-source model ecosystems, including Meta NLLB, DistilBART, and Qwen.
