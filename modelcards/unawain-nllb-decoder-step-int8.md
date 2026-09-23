# Model Card: unawain-nllb-decoder-step-int8

## Summary

- Name: NLLB Decoder Step (600M distilled)
- Family: NLLB
- Task: Translation (decoder-step component)
- Quantization: int8 per-channel
- Format: Core ML `.mlpackage`

## Intended Use

- Intended for: Token-by-token decode loop with encoder output from NLLB encoder artifact.
- Not intended for: Standalone inference without valid encoder states.

## Provenance

- Upstream model: `facebook/nllb-200-distilled-600M`
- Upstream license: CC-BY-NC-4.0
- Conversion script: `scripts/conversion/convert_nllb_to_coreml.py` (not yet included in this repository)
- Conversion notes: greedy decode compatible, iOS17+ target

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
- Output: `mm` (next-token logits) `[1, 256206]` float32

## Platform Constraints

- Minimum iOS: 17.0
- Minimum macOS: 14.0
- Compute placement (measured, benchmark 001): no ops are Neural Engine-eligible (int8 weights, fp32 compute); runs on CPU. On macOS 26.5.1 / M4 Pro, loading with `ALL` or `CPU_AND_GPU` aborts during GPU compilation — use `CPU_ONLY` or `CPU_AND_NE`.

## Latency Benchmarks

| Scenario | Device | Decode Length | p50 Latency (ms/token) | p95 Latency (ms/token) | Notes |
|---|---|---:|---:|---:|---|
| Decoder step (single call) | Apple M4 Pro, macOS 26.5.1, `CPU_ONLY` | 64 of 128 positions | 41.94 | 43.68 | [Benchmark 001](../benchmarks/results/001-host-latency-pilot.md); per call, not a full decode loop. |
| Decoder step | iPhone / iOS 17+ | 64 | Pending | Pending | Benchmark 002; measure with greedy decode loop. |

## Quality Benchmarks

| Metric | Dataset | Score | Notes |
|---|---|---:|---|
| BLEU | FLORES-200 subset | Pending | Evaluate with encoder + decoder pair. |
| chrF++ | FLORES-200 subset | Pending | Evaluate with encoder + decoder pair. |

## Risks and Limitations

- Translation quality strongly depends on decoding strategy and prompt context.
- Low-frequency named entities can be mistranslated.

## Changelog

- 0.1.0: Initial public release card.
