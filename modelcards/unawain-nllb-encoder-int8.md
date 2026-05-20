# Model Card: unawain-nllb-encoder-int8

## Summary

- Name: NLLB Encoder (600M distilled)
- Family: NLLB
- Task: Translation (encoder component)
- Quantization: int8 per-channel
- Format: Core ML `.mlpackage`

## Intended Use

- Intended for: On-device multilingual translation pipelines paired with NLLB decoder-step model.
- Not intended for: Standalone text generation without corresponding decoder and decode loop.

## Provenance

- Upstream model: `facebook/nllb-200-distilled-600M`
- Upstream license: CC-BY-NC-4.0
- Conversion script: `scripts/conversion/convert_nllb_to_coreml.py`
- Conversion notes: mask-free exact-length inputs, iOS17+ target

## License and Usage Terms

- SPDX: CC-BY-NC-4.0
- Commercial use: Prohibited by upstream terms.
- Attribution: Required.
- Terms source: `models/nllb/nllb_600m/README.md`

## Inputs and Outputs

- Input: `src_ids` `[1, src_len]` int32/int64 (runtime-managed)
- Output: `enc_out` `[1, src_len, 1024]` float16

## Platform Constraints

- Minimum iOS: 17.0
- Minimum macOS: 14.0
- Compute assumptions: Apple Neural Engine preferred

## Latency Benchmarks

| Scenario | Device | Input Shape | p50 Latency (ms) | p95 Latency (ms) | Notes |
|---|---|---|---:|---:|---|
| Encoder forward pass | Apple Silicon / iOS17+ | `[1, src_len, 1024]` | Pending | Pending | Publish with paired decoder benchmark run. |

## Quality Benchmarks

| Metric | Dataset | Score | Notes |
|---|---|---:|---|
| BLEU | FLORES-200 subset | Pending | Report jointly with decoder-step model. |
| chrF++ | FLORES-200 subset | Pending | Report jointly with decoder-step model. |

## Risks and Limitations

- Domain shift can significantly degrade translation quality.
- Quantization may reduce quality in low-resource language pairs.

## Changelog

- 0.1.0: Initial public release card.
