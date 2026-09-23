# Benchmarks

Latency and quality measurements for the models in this repository, published by
Makata AI Edge Lab. Each experiment states its question, hypothesis, and conditions
before any results, so a reader can tell what was measured, on what hardware, and
what the numbers do not show.

| ID | Experiment | Device | Status |
|---|---|---|---|
| 001 | [Host latency pilot: full vs pruned NLLB int8](#001--host-latency-pilot-full-vs-pruned-nllb-int8) | Apple M4 Pro (macOS) | Done — [results](results/001-host-latency-pilot.md) |
| 002 | [On-device latency (iPhone), same models](#002--on-device-latency-iphone-same-nllb-packages) | iPhone | Harness ready; device run not started |
| 003 | Translation quality, full vs pruned (FLORES-200: `tgl_Latn`, `ceb_Latn`, `ilo_Latn`, `pag_Latn`, `war_Latn`) | Any | Not started |

## Harness

Two harnesses, producing the same JSON fields: `bench_coreml_latency.py` (Python,
macOS, used for 001) and the native Swift harness in `swift/` (macOS and iOS, used for
002; described under 002).

`bench_coreml_latency.py` loads each `.mlpackage` with coremltools, builds synthetic
inputs from the model's declared input spec, and records load time, first-call
latency, and p50/p95/mean per-call `predict` latency for each compute-unit setting.
It also records the host (chip, memory, OS build, power source, thermal state before
and after) and the SHA-256 of each package (same algorithm as `scripts/build_manifest.py`,
so it can be checked against the release's `model-manifest.json`). Each (model,
compute-units) setting runs in its own process, so a Core ML crash is recorded as a
result instead of ending the run.

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install coremltools numpy
# download + unzip the release archives into artifacts/ first
python benchmarks/bench_coreml_latency.py \
  --model artifacts/NllbEncoder.mlpackage --model artifacts/NllbEncoder_pruned.mlpackage \
  --model artifacts/NllbDecoderStep.mlpackage --model artifacts/NllbDecoderStep_pruned.mlpackage \
  --warmup 10 --iters 100 \
  --out benchmarks/results/<run-id>.json
```

---

## 001 — Host latency pilot: full vs pruned NLLB int8

**Question.** On an Apple Silicon Mac, how do the pruned NLLB encoder and decoder-step
packages compare with the full int8 packages in package size and per-call latency,
and how much does Core ML compute-unit selection change the result?

**Hypotheses (stated before running).**
- H1: Each pruned package has lower p50 per-call latency than its full counterpart under the same compute units.
- H2: For these fixed-shape int8 graphs, `CPU_AND_NE` has lower p50 latency than `CPU_ONLY`.

**Why a host pilot first.** The Unawain app runs these models on iPhone; this run is
not a substitute for that. It validates the harness, establishes a reference point,
and checks the published model cards against the actual artifacts before the
on-device experiment (002).

**Variables.**
- Independent: package (full vs pruned), compute units (`ALL`, `CPU_ONLY`, `CPU_AND_GPU`, `CPU_AND_NE`).
- Held constant: host, release `v0.1.0` archives (SHA-256 recorded), synthetic inputs (seed 0, 64 unmasked of 256 positions), 10 warm-up calls, 100 timed calls.
- Recorded, not controlled: background load, thermal state (before/after).

**Validity checks.** A run is re-done if the host records a thermal or performance
warning, and any setting whose standard deviation exceeds 25% of its mean is flagged
as noisy in the results.

**Known limitations.**
- Per-call latency only. One translation is one encoder call plus one decoder-step call per generated token; end-to-end translation time is not measured here.
- Synthetic inputs. Latency for these fixed-shape graphs depends on shapes, not token values, but no real text is translated and quality is not measured.
- Timings include Python/coremltools call overhead, which native Swift calls do not have.
- Single run on a single machine, with a normal desktop session running in the background.

**Results.** See [`results/001-host-latency-pilot.md`](results/001-host-latency-pilot.md).

---

## 002 — On-device latency (iPhone), same NLLB packages

**Question.** On an iPhone, which compute units do the four v0.1.0 NLLB packages actually
run on, what are their load and per-call latencies, and how much memory does the app
process use while each one is loaded?

**Why.** Experiment 001 found that on a Mac no operation in these packages can run on the
Neural Engine and the GPU path aborts. The Unawain app requests
`.cpuAndNeuralEngine` for these models, so whether that holds on iPhone decides what the
app is really running on. Memory matters more on the phone than on the Mac, because iOS
terminates apps that exceed their memory limit.

**Hypotheses (stated before running).**
- H1: The compute plan on iPhone also reports 0 Neural Engine-supported operations, because the packages compute in fp32.
- H2: `CPU_AND_NE` p50 latency is within 5% of `CPU_ONLY` for every package (they run on the same hardware).
- H3: With `CPU_AND_NE`, memory after load is higher than with `CPU_ONLY`, as it was on the Mac (see harness check below).
- H4: Each pruned decoder step has lower p50 latency than the full decoder step under `CPU_ONLY`.

Open question, not a hypothesis: whether `ALL` / `CPU_AND_GPU` load on iOS or abort as on macOS.

**Variables.**
- Independent: package (full vs pruned), compute units (`ALL`, `CPU_ONLY`, `CPU_AND_GPU`, `CPU_AND_NE`).
- Held constant: release `v0.1.0` packages (SHA-256 recorded), synthetic inputs (seed 0, 64 unmasked positions), 10 warm-up calls, 100 timed calls, Release build.
- Recorded, not controlled: device model, iOS version and build, Low Power Mode, battery state and level, thermal state before and after each setting, memory footprint before load / after warm-up / after timed calls.

**Run conditions.** Low Power Mode off, phone charging, other apps closed, app kept in the
foreground (the app keeps the screen awake while running), phone at room temperature and
thermal state `nominal` at start.

**Validity checks.** A setting is flagged if thermal state is above `fair` at its end or
its standard deviation exceeds 25% of its mean. A setting that crashes the app is recorded
as failed and the run continues after relaunch.

**Known limitations.**
- Per-call latency only; end-to-end translation time is not measured (see 001).
- Memory is the benchmark process's physical footprint, not the Unawain app's, which also holds the summarizer and UI.
- One device, one run; results describe that device and iOS version.

### Swift harness (`swift/`)

Native Core ML timing with no Python in the loop. The same code (`Sources/BenchCore`) runs
as a macOS command-line tool and inside a small iOS app.

- Each package is copied into the app uncompiled and compiled on device, so compile time is recorded (`compile_s`).
- For each setting: cold load and first call on a fresh model instance, then a second instance for warm-up and timed calls.
- `MLComputePlan` (with `ALL`) records how many operations can run on the Neural Engine or GPU and which device Core ML prefers for each.
- Progress is saved after every step. If Core ML crashes the app, relaunching it records that setting as failed and continues. On the Mac, each setting runs in its own process, so a crash does not end the run.
- Output JSON uses the same field names as `bench_coreml_latency.py`, plus the fields above.

**Mac harness check.** Before any iPhone run, the Swift harness was run on the same M4 Pro
Mac as 001 ([`results/002-harness-check-mac.json`](results/002-harness-check-mac.json)).
It reproduced 001: identical SHA-256 and operation counts (0 of 440 / 774 operations Neural
Engine-supported), the same GPU abort under `ALL` and `CPU_AND_GPU`, and `CPU_ONLY` p50
within 1–3% below the Python harness (37.6 / 37.3 / 41.5 / 39.1 ms vs 38.4 / 38.4 / 41.9 /
40.4 ms), consistent with removing Python call overhead. It also recorded memory, which 001
did not: with `CPU_AND_NE`, the process footprint after load was 1.7–3.2 GB, compared with
under 70 MB for three of the four packages under `CPU_ONLY` (1.3 GB for the pruned decoder
step). Why the Neural Engine setting uses more memory when no operation runs there has not
been investigated.

### Running 002 on an iPhone

1. Download the four NLLB zips from the v0.1.0 release into `artifacts/` and unzip them
   there (the app build copies `artifacts/Nllb*.mlpackage`).
2. Open `benchmarks/swift/CoreMLBench.xcodeproj` in Xcode. If Xcode asks for the iOS
   platform component, install it (Xcode → Settings → Components).
3. Target *CoreMLBench* → Signing & Capabilities: choose your team. Change the bundle
   identifier if Xcode reports it is taken.
4. Connect the iPhone, set up the run conditions above, select the phone, and press Run.
   The scheme builds in Release. Tap **Start run** and keep the app in the foreground until
   the log shows `Wrote coreml-latency-….json`.
5. If the app closes mid-run, reopen it and tap **Resume run**. The setting that was
   running is recorded as failed. For a crash, also export the crash log (Xcode →
   Window → Devices and Simulators → View Device Logs).
6. Get the JSON with the share button in the app, or in Finder: select the iPhone →
   Files → Core ML Bench. Save it as `benchmarks/results/002-iphone-<model>.json`.

On the Mac, the command-line tool runs the same benchmark:

```bash
cd benchmarks/swift
swift build -c release
.build/release/coreml-bench \
  --model ../../artifacts/NllbEncoder.mlpackage --model ../../artifacts/NllbEncoder_pruned.mlpackage \
  --model ../../artifacts/NllbDecoderStep.mlpackage --model ../../artifacts/NllbDecoderStep_pruned.mlpackage \
  --warmup 10 --iters 100 --out ../results/<run-id>.json
```
