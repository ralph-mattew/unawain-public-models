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
- Conversion script: `scripts/conversion/convert_nllb_pruned.py` (not yet included in this repository)

## License and Usage Terms

- SPDX: CC-BY-NC-4.0
- Commercial use: Prohibited by upstream terms.
- Attribution: Required.
- Terms source: `models/nllb/nllb_600m/README.md`

## Inputs and Outputs

- Input: `dec_ids` `[1, 128]` int32 (full decoded prefix; no key-value cache)
- Input: `enc_out` `[1, 256, 1024]` float32
- Input: `dec_mask` `[1, 128]` float32
- Input: `enc_mask` `[1, 256]` float32
- Input: `last_pos` `[1, 1]` int32
- Output: `mm` (next-token logits, pruned vocabulary) `[1, 136312]` float32

## Platform Constraints

- Minimum iOS: 17.0
- Minimum macOS: 14.0
- Compute placement (measured, benchmark 001): no ops are Neural Engine-eligible (int8 weights, fp32 compute); runs on CPU. On macOS 26.5.1 / M4 Pro, loading with `ALL` or `CPU_AND_GPU` aborts during GPU compilation — use `CPU_ONLY` or `CPU_AND_NE`.

## Latency Benchmarks

| Scenario | Device | Decode Length | p50 Latency (ms/token) | p95 Latency (ms/token) | Notes |
|---|---|---:|---:|---:|---|
| Decoder step (pruned, single call) | Apple M4 Pro, macOS 26.5.1, `CPU_ONLY` | 64 of 128 positions | 40.36 | 42.59 | [Benchmark 001](../benchmarks/results/001-host-latency-pilot.md): 4% faster than full decoder step; package 26% smaller. |
| Decoder step (pruned) | iPhone / iOS 17+ | 64 | Pending | Pending | Benchmark 002; compare against non-pruned decoder step. |

## Quality Benchmarks

| Metric | Dataset | Score | Notes |
|---|---|---:|---|
| BLEU Delta vs full | FLORES-200 subset | Pending | Evaluate with pruned encoder + decoder pair. |
| chrF++ Delta vs full | FLORES-200 subset | Pending | Evaluate with pruned encoder + decoder pair. |

## Risks and Limitations

- Pruning plus quantization can amplify decoding instability.

## Changelog

- 0.1.0: Initial public release card.
