"""
Benchmark runner: measures Python vs Mojo implementations.

Usage:
    python3 benchmarks/runner.py              # Run all benchmarks
    python3 benchmarks/runner.py nbody        # Run specific benchmark
    python3 benchmarks/runner.py --mojo-only  # Only run Mojo versions
    python3 benchmarks/runner.py --python-only # Only run Python versions
    python3 benchmarks/runner.py --warmup N   # Number of warmup runs
    python3 benchmarks/runner.py --runs N     # Number of timed runs per benchmark
"""

import sys
import os
import time
import subprocess
import argparse
from dataclasses import dataclass, field
from typing import Optional


PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, PROJECT_ROOT)

BENCHMARKS = [
    "binarytrees",
    "nbody",
    "nsieve",
    "pidigits",
    "edigits",
    "mandelbrot",
    "fannkuch",
    "fasta",
    "lru",
    "spectral_norm",
]


@dataclass
class BenchmarkResult:
    name: str
    python_times: list[float] = field(default_factory=list)
    mojo_times: list[float] = field(default_factory=list)
    python_output: str = ""
    mojo_output: str = ""
    python_error: Optional[str] = None
    mojo_error: Optional[str] = None


def run_python_benchmark(name: str, *args) -> tuple[str, float, Optional[str]]:
    script = os.path.join(PROJECT_ROOT, "benchmarks", "python", f"{name}.py")
    if not os.path.exists(script):
        return "", 0, f"Python benchmark not found: {script}"
    cmd = [sys.executable, script] + [str(a) for a in args]
    start = time.perf_counter()
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=120, cwd=PROJECT_ROOT
        )
        elapsed = time.perf_counter() - start
        if result.returncode != 0:
            return result.stdout.strip(), elapsed, result.stderr.strip()
        return result.stdout.strip(), elapsed, None
    except subprocess.TimeoutExpired:
        return "", time.perf_counter() - start, "Timeout (120s)"
    except FileNotFoundError:
        return "", 0, f"Python not found: {sys.executable}"
    except Exception as e:
        return "", 0, str(e)


def run_mojo_benchmark(name: str, *args) -> tuple[str, float, Optional[str]]:
    script = os.path.join(PROJECT_ROOT, "benchmarks", "mojo", f"{name}.mojo")
    if not os.path.exists(script):
        return "", 0, f"Mojo benchmark not found: {script}"
    cmd = ["mojo", script] + [str(a) for a in args]
    start = time.perf_counter()
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=120, cwd=PROJECT_ROOT
        )
        elapsed = time.perf_counter() - start
        if result.returncode != 0:
            return result.stdout.strip(), elapsed, result.stderr.strip()
        return result.stdout.strip(), elapsed, None
    except FileNotFoundError:
        return "", 0, "Mojo compiler not found (install mojo)"
    except subprocess.TimeoutExpired:
        return "", time.perf_counter() - start, "Timeout (120s)"
    except Exception as e:
        return "", 0, str(e)


def get_benchmark_args(name: str) -> list:
    args_map = {
        "binarytrees": [15],
        "nbody": [50000],
        "nsieve": [4],
        "pidigits": [4000],
        "edigits": [100000],
        "mandelbrot": [1000],
        "fannkuch": [7],
        "fasta": [250000],
        "lru": [100, 500000],
        "spectral_norm": [2000],
    }
    return args_map.get(name, [10])


def run_benchmark(
    name: str,
    run_python: bool = True,
    run_mojo: bool = True,
    warmup: int = 1,
    runs: int = 3,
) -> BenchmarkResult:
    result = BenchmarkResult(name=name)
    args = get_benchmark_args(name)

    if run_python and warmup > 0:
        run_python_benchmark(name, *args)
    if run_mojo and warmup > 0:
        run_mojo_benchmark(name, *args)

    if run_python:
        for i in range(runs):
            out, elapsed, err = run_python_benchmark(name, *args)
            if err is None:
                result.python_times.append(elapsed)
                if i == 0:
                    result.python_output = out
            else:
                result.python_error = err
                break

    if run_mojo:
        for i in range(runs):
            out, elapsed, err = run_mojo_benchmark(name, *args)
            if err is None:
                result.mojo_times.append(elapsed)
                if i == 0:
                    result.mojo_output = out
            else:
                result.mojo_error = err
                break

    return result


def print_results(results: list[BenchmarkResult]):
    print("\n" + "=" * 100)
    print(f"{'Benchmark':<18} {'Python (s)':<14} {'Mojo (s)':<14} {'Speedup':<10} {'Status':<20}")
    print("-" * 100)

    for r in results:
        py_avg = sum(r.python_times) / len(r.python_times) if r.python_times else None
        mojo_avg = sum(r.mojo_times) / len(r.mojo_times) if r.mojo_times else None

        if py_avg and mojo_avg and mojo_avg > 0:
            speedup = py_avg / mojo_avg
            speedup_str = f"{speedup:.2f}x"
        elif py_avg:
            speedup_str = f"{py_avg:.3f}s (no mojo)"
        elif mojo_avg:
            speedup_str = f"{mojo_avg:.3f}s (no python)"
        else:
            speedup_str = "N/A"

        status_parts = []
        if r.python_error:
            status_parts.append(f"PY-ERR: {r.python_error[:25]}")
        if r.mojo_error:
            status_parts.append(f"MOJO-ERR: {r.mojo_error[:25]}")
        if not r.python_times and not r.mojo_times:
            status_parts.append("FAILED")
        elif r.python_times and r.mojo_times:
            status_parts.append("OK")
        elif r.python_times:
            status_parts.append("PY only")
        else:
            status_parts.append("MOJO only")
        status = "; ".join(status_parts)

        py_str = f"{py_avg:.4f}" if py_avg else "N/A"
        mojo_str = f"{mojo_avg:.4f}" if mojo_avg else "N/A"

        print(f"{r.name:<18} {py_str:<14} {mojo_str:<14} {speedup_str:<10} {status:<20}")

    print("=" * 100)


def main():
    parser = argparse.ArgumentParser(description="Run benchmarks")
    parser.add_argument(
        "benchmarks", nargs="*", default=BENCHMARKS, help="Benchmarks to run"
    )
    parser.add_argument("--mojo-only", action="store_true", help="Only run Mojo")
    parser.add_argument("--python-only", action="store_true", help="Only run Python")
    parser.add_argument("--warmup", type=int, default=1, help="Warmup runs")
    parser.add_argument("--runs", type=int, default=3, help="Timed runs per benchmark")
    args = parser.parse_args()

    run_python = not args.mojo_only
    run_mojo = not args.python_only

    valid = set(BENCHMARKS)
    for name in args.benchmarks:
        if name not in valid:
            print(f"Unknown benchmark: {name}. Available: {', '.join(sorted(valid))}")
            sys.exit(1)

    results = []
    for name in args.benchmarks:
        print(f"\nRunning {name}...")
        r = run_benchmark(name, run_python, run_mojo, args.warmup, args.runs)
        results.append(r)

    print_results(results)


if __name__ == "__main__":
    main()
