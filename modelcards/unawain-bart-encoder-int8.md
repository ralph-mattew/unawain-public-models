# Model Card: unawain-bart-encoder-int8

## Summary

- Name: DistilBART Encoder (CNN 6-6)
- Family: BART
- Task: Summarization (encoder component)
- Quantization: int8 per-channel
- Format: Core ML `.mlpackage`

## Intended Use

- Intended for: On-device abstractive summarization pipelines with paired decoder-step model.
- Not intended for: Standalone generation without compatible decoder.

## Provenance

- Upstream model: `sshleifer/distilbart-cnn-6-6`
- Upstream license: Apache-2.0
- Conversion script: `scripts/conversion/convert_distilbart_fixed.py` (not yet included in this repository)

## License and Usage Terms

- SPDX: Apache-2.0
- Commercial use: Allowed.
- Attribution: Required (preserve license and notices).
- Terms source: `models/bart/distilbart_cnn_6_6/README.md`

## Inputs and Outputs

- Input: `src_ids` `[1, 512]` int32
- Input: `src_mask` `[1, 512]` float32
- Output: `enc_out` `[1, 512, 1024]` float16

## Platform Constraints

- Minimum iOS: 17.0
- Minimum macOS: 14.0

## Latency Benchmarks

| Scenario | Device | Sequence Length | p50 Latency (ms) | p95 Latency (ms) | Notes |
|---|---|---:|---:|---:|---|
| Encoder forward pass | Apple Silicon / iOS17+ | 512 | Pending | Pending | On-device Core ML measurement pending. |
| Upstream reference (full summarize) | A single GPU (HF card) | 1024 in / 128 out | 182 | N/A | DistilBART-6-6-CNN reference from upstream model card. |

## Quality Benchmarks

| Metric | Dataset | Score | Notes |
|---|---|---:|---|
| ROUGE-2 | CNN/DailyMail | 20.17 | Upstream DistilBART-6-6-CNN reference. |
| ROUGE-L | CNN/DailyMail | 29.70 | Upstream DistilBART-6-6-CNN reference. |
| ROUGE-L (on-device conversion) | Internal validation set | Pending | To be published from Core ML runtime tests. |

## Risks and Limitations

- Summarization may lose nuanced details.
- Input truncation at fixed lengths can drop context.

## Changelog

- 0.1.0: Initial public release card.
