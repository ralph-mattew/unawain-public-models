# Model Card: unawain-nllb-decoder-step-pruned-int8

## Summary

- Name: NLLB Decoder Step Pruned (int8)
- Family: NLLB
- Task: Translation (decoder-step component)
- Quantization: int8 per-channel
- Format: Core ML `.mlpackage`

## Intended Use

- Intended for: Lower-footprint translation decode loops paired with pruned encoder.
- Not intended for: Standalone use or unvalidated high-stakes translation workflows.

## Provenance

- Upstream model: `facebook/nllb-200-distilled-600M`
- Upstream license: CC-BY-NC-4.0
- Conversion script: `scripts/conversion/convert_nllb_pruned.py`

## License and Usage Terms

- SPDX: CC-BY-NC-4.0
- Commercial use: Prohibited by upstream terms.
- Attribution: Required.
- Terms source: `models/nllb/nllb_600m/README.md`

## Inputs and Outputs

- Input: `dec_ids` `[1, dec_len]` int32/int64
- Input: `enc_out` `[1, src_len, 1024]` float16/float32
- Output: `logits` `[1, vocab_size]` float16

## Platform Constraints

- Minimum iOS: 17.0
- Minimum macOS: 14.0

## Latency Benchmarks

| Scenario | Device | Decode Length | p50 Latency (ms/token) | p95 Latency (ms/token) | Notes |
|---|---|---:|---:|---:|---|
| Decoder step (pruned) | Apple Silicon / iOS17+ | 64 | Pending | Pending | Compare against non-pruned decoder step. |

## Quality Benchmarks

| Metric | Dataset | Score | Notes |
|---|---|---:|---|
| BLEU Delta vs full | FLORES-200 subset | Pending | Evaluate with pruned encoder + decoder pair. |
| chrF++ Delta vs full | FLORES-200 subset | Pending | Evaluate with pruned encoder + decoder pair. |

## Risks and Limitations

- Pruning plus quantization can amplify decoding instability.

## Changelog

- 0.1.0: Initial public release card.
