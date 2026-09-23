# 001 — Results: host latency pilot, full vs pruned NLLB int8

Protocol: [`../README.md#001`](../README.md#001--host-latency-pilot-full-vs-pruned-nllb-int8) ·
Raw data: [`001-host-latency-pilot.json`](001-host-latency-pilot.json)

## Conditions

| | |
|---|---|
| Host | Apple M4 Pro, 24 GB, macOS 26.5.1 (25F80), AC power |
| Thermal state | No thermal or performance warning recorded before or after the run |
| Runtime | coremltools 9.0, Python 3.13.5 |
| Artifacts | Release `v0.1.0`; package SHA-256 matches `model-manifest.json` for all four packages |
| Method | Synthetic inputs (seed 0, 64 of 256 source positions unmasked), 10 warm-up + 100 timed `predict` calls per setting, each setting in its own process |
| Date | 2026-09-23 |

## Results

### Per-call latency (ms)

| Package | Size (MB) | Compute units | p50 | p95 | CV | Load (s) | First call |
|---|---:|---|---:|---:|---:|---:|---:|
| NllbEncoder | 416.4 | `CPU_ONLY` | 38.40 | 40.41 | 7.4% | 1.78 | 99.1 |
| | | `CPU_AND_NE` | 38.65 | 39.97 | 7.3% | 8.34 | 86.6 |
| | | `ALL`, `CPU_AND_GPU` | crash | | | | |
| NllbEncoder_pruned | 293.0 | `CPU_ONLY` | 38.36 | 40.09 | 7.9% | 0.89 | 98.0 |
| | | `CPU_AND_NE` | 38.57 | 40.84 | 3.8% | 4.69 | 90.4 |
| | | `ALL`, `CPU_AND_GPU` | crash | | | | |
| NllbDecoderStep | 468.3 | `CPU_ONLY` | 41.94 | 43.68 | 3.5% | 2.34 | 131.0 |
| | | `CPU_AND_NE` | 42.25 | 43.57 | 5.2% | 9.58 | 118.4 |
| | | `ALL`, `CPU_AND_GPU` | crash | | | | |
| NllbDecoderStep_pruned | 344.4 | `CPU_ONLY` | 40.36 | 42.59 | 3.9% | 1.78 | 116.0 |
| | | `CPU_AND_NE` | 39.43 | 40.97 | 2.2% | 5.61 | 105.6 |
| | | `ALL`, `CPU_AND_GPU` | crash | | | | |

CV = standard deviation / mean. No setting exceeded the 25% noise threshold.
Load time includes Core ML compilation of the `.mlpackage`.

### Findings

Each finding carries the Lab's epistemic label.

1. **MEASURED — The Neural Engine is never used.** Core ML's compute plan
   (`MLComputePlan`) reports that 0 of 440 encoder ops and 0 of 774 pruned
   decoder-step ops are supported on the Neural Engine. Under `CPU_AND_NE`, every op
   runs on the CPU, which is why `CPU_AND_NE` and `CPU_ONLY` latencies match within
   noise. The compiled programs contain 0 fp16 tensors: int8 weights are dequantized
   (`constexpr_affine_dequantize`) and all compute runs in fp32.
2. **OBSERVED — The GPU path aborts.** Loading any of the four packages with `ALL` or
   `CPU_AND_GPU` terminates the process (SIGABRT) with
   `MPSGraphExecutable.mm: failed assertion 'Error: MLIR pass manager failed'`.
   Under `ALL`, the compute plan assigns all 440 / 774 ops to the GPU, so `ALL` fails
   on the same compile. Reproduced in every run on this host; not yet tested on iOS.
3. **MEASURED — Pruning mainly reduces size.** Pruned packages are 30% smaller
   (encoder) and 26% smaller (decoder step). Latency changed little: the pruned
   encoder is identical within noise (38.36 vs 38.40 ms p50, `CPU_ONLY`), and the
   pruned decoder step is 4–7% faster (40.36 vs 41.94 ms `CPU_ONLY`; 39.43 vs
   42.25 ms `CPU_AND_NE`). This matches where pruning acts: the vocabulary shrinks
   from 256,206 to 136,312 tokens, which reduces the decoder's output projection but
   only the encoder's embedding lookup.
4. **MEASURED — Pruned packages load faster.** Load time dropped 38–50% (for
   example, 8.34 s → 4.69 s for the encoder under `CPU_AND_NE`).
5. **OBSERVED — The decoder step has no key-value cache.** Each call takes the full
   128-position `dec_ids` and has no past-key/value inputs, so every generated token
   recomputes attention over the whole prefix.

### Hypotheses

| | Hypothesis | Outcome |
|---|---|---|
| H1 | Pruned packages have lower p50 latency than their full counterparts | **Partly supported**: yes for the decoder step (4–7%); no for the encoder (no difference) |
| H2 | `CPU_AND_NE` is faster than `CPU_ONLY` | **Rejected**: no op is Neural Engine-eligible, so both run on the CPU |

### What this implies (INFERRED, not measured)

- A 64-token translation would take about one encoder call plus 64 decoder steps:
  roughly 38 + 64 × 40 ≈ 2.6 s of model time on this host's CPU, before tokenization
  and Python overhead are removed or added. End-to-end time was not measured.
- Converting with fp16 compute precision (and checking translation quality against
  the fp32 packages) is the most likely route to Neural Engine placement. Adding a
  key-value cache to the decoder step would reduce per-token work. Both are
  hypotheses for follow-up experiments, not results.

### Open questions

- An encoder forward pass and one decoder step cost nearly the same (~38 vs ~40 ms).
  This run does not establish why.
- Does the GPU compile failure also occur on iOS, or only on this macOS / Metal
  version?
- How do these numbers change on an iPhone, where the app actually runs
  (experiment 002)?

## Limitations

- Host Mac, not iPhone. Absolute numbers do not transfer to the app's devices.
- Synthetic inputs; no text was translated and quality was not measured.
- Timings include Python/coremltools call overhead.
- Single run, one machine, normal desktop session in the background.
