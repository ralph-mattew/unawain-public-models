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
- Conversion script: `scripts/conversion/convert_nllb_pruned.py` (not yet included in this repository)

## License and Usage Terms

- SPDX: CC-BY-NC-4.0
- Commercial use: Prohibited by upstream terms.
- Attribution: Required.
- Terms source: `models/nllb/nllb_600m/README.md`

## Inputs and Outputs

- Input: `src_ids` `[1, 256]` int32 (ids from the pruned vocabulary)
- Input: `src_mask` `[1, 256]` float32
- Output: `native_layer_norm_24` (encoder hidden states) `[1, 256, 1024]` float32

## Platform Constraints

- Minimum iOS: 17.0
- Minimum macOS: 14.0
- Compute placement (measured, benchmark 001): no ops are Neural Engine-eligible (int8 weights, fp32 compute); runs on CPU. On macOS 26.5.1 / M4 Pro, loading with `ALL` or `CPU_AND_GPU` aborts during GPU compilation — use `CPU_ONLY` or `CPU_AND_NE`.

## Latency Benchmarks

| Scenario | Device | Input Shape | p50 Latency (ms) | p95 Latency (ms) | Notes |
|---|---|---|---:|---:|---|
| Encoder forward pass (pruned) | Apple M4 Pro, macOS 26.5.1, `CPU_ONLY` | `[1, 256]` | 38.36 | 40.09 | [Benchmark 001](../benchmarks/results/001-host-latency-pilot.md): same as full encoder within noise; package 30% smaller. |
| Encoder forward pass (pruned) | iPhone / iOS 17+ | `[1, 256]` | Pending | Pending | Benchmark 002. |

## Quality Benchmarks

| Metric | Dataset | Score | Notes |
|---|---|---:|---|
| BLEU Delta vs full | FLORES-200 subset | Pending | Compare paired pipeline against full model. |
| chrF++ Delta vs full | FLORES-200 subset | Pending | Compare paired pipeline against full model. |

## Risks and Limitations

- Pruning may reduce translation fidelity on low-resource language pairs.

## Changelog

- 0.1.0: Initial public release card.
