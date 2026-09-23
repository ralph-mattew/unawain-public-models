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
- Conversion script: `scripts/conversion/convert_nllb_to_coreml.py` (not yet included in this repository)
- Conversion notes: mask-free exact-length inputs, iOS17+ target

## License and Usage Terms

- SPDX: CC-BY-NC-4.0
- Commercial use: Prohibited by upstream terms.
- Attribution: Required.
- Terms source: `models/nllb/nllb_600m/README.md`

## Inputs and Outputs

- Input: `src_ids` `[1, 256]` int32
- Input: `src_mask` `[1, 256]` float32
- Output: `native_layer_norm_24` (encoder hidden states) `[1, 256, 1024]` float32

## Platform Constraints

- Minimum iOS: 17.0
- Minimum macOS: 14.0
- Compute placement (measured, benchmark 001): no ops are Neural Engine-eligible (int8 weights, fp32 compute); runs on CPU. On macOS 26.5.1 / M4 Pro, loading with `ALL` or `CPU_AND_GPU` aborts during GPU compilation — use `CPU_ONLY` or `CPU_AND_NE`.

## Latency Benchmarks

| Scenario | Device | Input Shape | p50 Latency (ms) | p95 Latency (ms) | Notes |
|---|---|---|---:|---:|---|
| Encoder forward pass | Apple M4 Pro, macOS 26.5.1, `CPU_ONLY` | `[1, 256]` | 38.40 | 40.41 | [Benchmark 001](../benchmarks/results/001-host-latency-pilot.md); host Mac, synthetic input. |
| Encoder forward pass | iPhone / iOS 17+ | `[1, 256]` | Pending | Pending | Benchmark 002. |

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
