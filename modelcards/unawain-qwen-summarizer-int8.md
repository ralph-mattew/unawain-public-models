# Model Card: unawain-qwen-summarizer-int8

## Summary

- Name: Qwen Summarizer Step Model (2.5 1.5B Instruct)
- Family: Qwen2.5
- Task: English summarization (next-token logits)
- Quantization: int8 per-channel
- Format: Core ML `.mlpackage`

## Intended Use

- Intended for: On-device summarization decode loops in iOS/macOS apps.
- Not intended for: Fully autonomous factual summarization in high-stakes scenarios.

## Provenance

- Upstream model: `Qwen/Qwen2.5-1.5B-Instruct`
- Upstream license: Apache-2.0
- Conversion script: `scripts/conversion/convert_qwen_to_coreml.py`
- Conversion notes: causal-mask patch and int8 quantization

## License and Usage Terms

- SPDX: Apache-2.0
- Commercial use: Allowed.
- Attribution: Required (preserve license and notices).
- Terms source: `models/llama/qwen2_5_1b_instruct/LICENSE`

## Inputs and Outputs

- Input: `input_ids` `[1, seq_len]` int32
- Output: `logits` `[1, vocab_size]` float16

## Platform Constraints

- Minimum iOS: 17.0
- Minimum macOS: 14.0
- Compute assumptions: Apple Neural Engine preferred

## Latency Benchmarks

| Scenario | Device | Decode Length | p50 Latency (ms/token) | p95 Latency (ms/token) | Notes |
|---|---|---:|---:|---:|---|
| Decoder step | Apple Silicon / iOS17+ | 64 | Pending | Pending | Benchmark script and results pending publication. |

## Quality Benchmarks

| Metric | Dataset | Score | Notes |
|---|---|---:|---|
| ROUGE-1 | Internal transcript-summary set | Pending | Must be measured on converted Core ML package. |
| ROUGE-2 | Internal transcript-summary set | Pending | Must be measured on converted Core ML package. |
| ROUGE-L | Internal transcript-summary set | Pending | Must be measured on converted Core ML package. |

## Risks and Limitations

- Summaries may omit critical details or hallucinate unsupported claims.
- Quantization can impact token-level ranking for edge inputs.

## Changelog

- 0.1.0: Initial public release card.
