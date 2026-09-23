# Model Card: unawain-bart-decoder-step-int8

## Summary

- Name: DistilBART Decoder Step (CNN 6-6)
- Family: BART
- Task: Summarization (decoder-step component)
- Quantization: int8 per-channel
- Format: Core ML `.mlpackage`

## Intended Use

- Intended for: Token decode loops that consume BART encoder outputs.
- Not intended for: Direct standalone use without proper encoder states and masks.

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

- Input: `dec_ids` `[1, 128]` int32
- Input: `enc_out` `[1, 512, 1024]` float32
- Input: `dec_mask` `[1, 128]` float32
- Input: `enc_mask` `[1, 512]` float32
- Input: `last_pos` `[1, 1]` int32
- Output: `logits` `[1, 50264]` float16

## Platform Constraints

- Minimum iOS: 17.0
- Minimum macOS: 14.0

## Latency Benchmarks

| Scenario | Device | Decode Length | p50 Latency (ms/token) | p95 Latency (ms/token) | Notes |
|---|---|---:|---:|---:|---|
| Decoder step | Apple Silicon / iOS17+ | 64 | Pending | Pending | On-device Core ML decode benchmark pending. |
| Upstream reference (full summarize) | A single GPU (HF card) | 1024 in / 128 out | 182 | N/A | DistilBART-6-6-CNN full pipeline reference. |

## Quality Benchmarks

| Metric | Dataset | Score | Notes |
|---|---|---:|---|
| ROUGE-2 | CNN/DailyMail | 20.17 | Upstream DistilBART-6-6-CNN reference. |
| ROUGE-L | CNN/DailyMail | 29.70 | Upstream DistilBART-6-6-CNN reference. |
| ROUGE-L (on-device conversion) | Internal validation set | Pending | To be published from Core ML runtime tests. |

## Risks and Limitations

- Decoder errors can compound over multi-step generation.
- Quality depends on decode policy and stopping strategy.

## Changelog

- 0.1.0: Initial public release card.
