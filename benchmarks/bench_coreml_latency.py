#!/usr/bin/env python3
"""Per-call latency benchmark for Core ML .mlpackage artifacts (macOS host).

Measures model load time and per-call `predict` latency for each model under each
requested compute-unit setting, and records the host conditions the numbers were
taken under. Inputs are synthetic tensors built from each model's declared input
spec: latency for these fixed-shape graphs depends on tensor shapes, not token
values. This script does not measure translation quality.

Usage:
  python benchmarks/bench_coreml_latency.py \
      --model artifacts/NllbEncoder.mlpackage --model artifacts/NllbEncoder_pruned.mlpackage \
      --compute-units ALL CPU_ONLY CPU_AND_NE --warmup 10 --iters 100 \
      --out benchmarks/results/<run-id>.json
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import platform
import statistics
import subprocess
import sys
import time
from pathlib import Path

import coremltools as ct
import numpy as np

DTYPES = {
    ct.proto.FeatureTypes_pb2.ArrayFeatureType.INT32: np.int32,
    ct.proto.FeatureTypes_pb2.ArrayFeatureType.FLOAT32: np.float32,
    ct.proto.FeatureTypes_pb2.ArrayFeatureType.FLOAT16: np.float16,
    ct.proto.FeatureTypes_pb2.ArrayFeatureType.DOUBLE: np.float64,
}


def sh(cmd: list[str]) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def host_conditions() -> dict:
    batt = sh(["pmset", "-g", "batt"])
    return {
        "timestamp_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "os": f"macOS {platform.mac_ver()[0]}",
        "os_build": sh(["sw_vers", "-buildVersion"]),
        "chip": sh(["sysctl", "-n", "machdep.cpu.brand_string"]),
        "memory_gb": round(int(sh(["sysctl", "-n", "hw.memsize"]) or 0) / 2**30, 1),
        "power_source": "AC" if "AC Power" in batt else ("battery" if "Battery Power" in batt else "unknown"),
        "thermal": sh(["pmset", "-g", "therm"]),
        "python": platform.python_version(),
        "coremltools": ct.__version__,
    }


def package_sha256(path: Path) -> str:
    """Same algorithm as scripts/build_manifest.py, so results match model-manifest.json."""
    h = hashlib.sha256()
    for f in sorted(p for p in path.rglob("*") if p.is_file()):
        h.update(str(f.relative_to(path)).encode("utf-8"))
        with f.open("rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
    return h.hexdigest()


def dir_size_mb(path: Path) -> float:
    return round(sum(p.stat().st_size for p in path.rglob("*") if p.is_file()) / 1e6, 1)


def synth_inputs(spec, rng: np.random.Generator, active_len: int) -> dict:
    """Build one input dict from the model's declared inputs, by name convention."""
    feeds = {}
    for inp in spec.description.input:
        arr = inp.type.multiArrayType
        shape = tuple(int(d) for d in arr.shape)
        dtype = DTYPES[arr.dataType]
        name = inp.name.lower()
        if "mask" in name:
            x = np.zeros(shape, dtype=dtype)
            x[..., :active_len] = 1
        elif "ids" in name or "token" in name:
            # Low ids exist in both full and vocabulary-pruned embeddings.
            x = rng.integers(4, 1000, size=shape).astype(dtype)
        elif "pos" in name:
            x = np.full(shape, active_len - 1, dtype=dtype)
        elif np.issubdtype(dtype, np.integer):
            x = np.zeros(shape, dtype=dtype)
        else:
            x = (rng.standard_normal(shape) * 0.1).astype(dtype)
        feeds[inp.name] = x
    return feeds


def describe_io(spec) -> dict:
    io = lambda f: {"name": f.name, "shape": [int(d) for d in f.type.multiArrayType.shape],
                    "dtype": ct.proto.FeatureTypes_pb2.ArrayFeatureType.ArrayDataType.Name(f.type.multiArrayType.dataType)}
    return {"inputs": [io(f) for f in spec.description.input], "outputs": [io(f) for f in spec.description.output]}


def pct(values: list[float], q: float) -> float:
    return float(np.percentile(values, q))


def bench(model_path: Path, cu: str, warmup: int, iters: int, active_len: int, seed: int) -> dict:
    t0 = time.perf_counter()
    model = ct.models.MLModel(str(model_path), compute_units=getattr(ct.ComputeUnit, cu))
    load_s = time.perf_counter() - t0

    rng = np.random.default_rng(seed)
    feeds = synth_inputs(model.get_spec(), rng, active_len)

    t0 = time.perf_counter()
    model.predict(feeds)
    first_call_ms = (time.perf_counter() - t0) * 1e3
    for _ in range(warmup):
        model.predict(feeds)

    times = []
    for _ in range(iters):
        t0 = time.perf_counter()
        model.predict(feeds)
        times.append((time.perf_counter() - t0) * 1e3)

    return {
        "compute_units": cu,
        "load_s": round(load_s, 2),
        "first_call_ms": round(first_call_ms, 2),
        "p50_ms": round(pct(times, 50), 2),
        "p95_ms": round(pct(times, 95), 2),
        "mean_ms": round(statistics.fmean(times), 2),
        "stdev_ms": round(statistics.stdev(times), 2),
        "min_ms": round(min(times), 2),
        "max_ms": round(max(times), 2),
        "iters": iters,
        "warmup": warmup,
    }


def bench_isolated(model_path: Path, cu: str, warmup: int, iters: int, active_len: int, seed: int) -> dict:
    """Run one (model, compute-units) benchmark in a child process.

    Core ML / MPSGraph compilation failures can abort the whole process, so each
    setting runs separately and a crash is recorded as a result, not lost.
    """
    cmd = [sys.executable, __file__, "--_child", str(model_path), cu, str(warmup), str(iters),
           str(active_len), str(seed)]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode == 0:
        return json.loads(proc.stdout.strip().splitlines()[-1])
    err = [ln for ln in proc.stderr.splitlines() if "assert" in ln.lower() or "error" in ln.lower()]
    return {"compute_units": cu, "failed": True, "returncode": proc.returncode,
            "error": (err[-1] if err else proc.stderr.strip()[-300:]).strip()}


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "--_child":
        path, cu, warmup, iters, active_len, seed = sys.argv[2:8]
        print(json.dumps(bench(Path(path), cu, int(warmup), int(iters), int(active_len), int(seed))))
        return

    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", action="append", required=True, type=Path)
    ap.add_argument("--compute-units", nargs="+", default=["ALL", "CPU_ONLY", "CPU_AND_GPU", "CPU_AND_NE"],
                    choices=["ALL", "CPU_ONLY", "CPU_AND_GPU", "CPU_AND_NE"])
    ap.add_argument("--warmup", type=int, default=10)
    ap.add_argument("--iters", type=int, default=100)
    ap.add_argument("--active-len", type=int, default=64, help="unmasked positions in *mask inputs")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--release", default="v0.1.0")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    run = {"host_before": host_conditions(), "release": args.release,
           "method": {"warmup": args.warmup, "iters": args.iters, "active_len": args.active_len,
                      "seed": args.seed, "inputs": "synthetic, from declared input spec"},
           "models": []}

    for path in args.model:
        spec = ct.models.MLModel(str(path), skip_model_load=True).get_spec()
        entry = {"artifact": path.name, "package_size_mb": dir_size_mb(path),
                 "package_sha256": package_sha256(path),
                 "io": describe_io(spec), "runs": []}
        for cu in args.compute_units:
            print(f"{path.name} [{cu}] ...", flush=True)
            r = bench_isolated(path, cu, args.warmup, args.iters, args.active_len, args.seed)
            if r.get("failed"):
                print(f"  FAILED (exit {r['returncode']}): {r['error']}", flush=True)
            else:
                print(f"  load {r['load_s']}s  p50 {r['p50_ms']}ms  p95 {r['p95_ms']}ms", flush=True)
            entry["runs"].append(r)
        run["models"].append(entry)

    run["host_after"] = host_conditions()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(run, indent=2) + "\n")
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
