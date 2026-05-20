# Model Card: unawain-nllb-encoder-pruned-int8

## Summary

- Name: NLLB Encoder Pruned (int8)
- Family: NLLB
- Task: Translation (encoder component)
- Quantization: int8 per-channel
- Format: Core ML `.mlpackage`

## Intended Use

- Intended for: Lower-footprint translation pipeline variants.
- Not intended for: Quality-critical tasks without validation against full model.

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

- Input: `src_ids` `[1, src_len]` int32/int64
- Output: `enc_out` `[1, src_len, 1024]` float16

## Platform Constraints

- Minimum iOS: 17.0
- Minimum macOS: 14.0

## Latency Benchmarks

| Scenario | Device | Input Shape | p50 Latency (ms) | p95 Latency (ms) | Notes |
|---|---|---|---:|---:|---|
| Encoder forward pass (pruned) | Apple Silicon / iOS17+ | `[1, src_len, 1024]` | Pending | Pending | Compare against non-pruned encoder. |

## Quality Benchmarks

| Metric | Dataset | Score | Notes |
|---|---|---:|---|
| BLEU Delta vs full | FLORES-200 subset | Pending | Compare paired pipeline against full model. |
| chrF++ Delta vs full | FLORES-200 subset | Pending | Compare paired pipeline against full model. |

## Risks and Limitations

- Pruning may reduce translation fidelity on low-resource language pairs.

## Changelog

- 0.1.0: Initial public release card.
