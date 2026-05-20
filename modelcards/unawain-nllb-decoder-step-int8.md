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
- Conversion script: `scripts/conversion/convert_nllb_to_coreml.py`
- Conversion notes: greedy decode compatible, iOS17+ target

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
- Compute assumptions: Apple Neural Engine preferred

## Latency Benchmarks

| Scenario | Device | Decode Length | p50 Latency (ms/token) | p95 Latency (ms/token) | Notes |
|---|---|---:|---:|---:|---|
| Decoder step | Apple Silicon / iOS17+ | 64 | Pending | Pending | Measure with greedy decode loop. |

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
