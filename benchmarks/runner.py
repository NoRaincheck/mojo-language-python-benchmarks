"""
Benchmark runner: measures four execution scenarios for each algorithm.

  1. python        - pure Python, run as a standalone program (subprocess)
  2. mojo          - pure Mojo, run as a standalone program (subprocess)
  3. py->mojo (py) - Python calls Mojo via the PythonObject boundary
                     (extension module imported once, timed in-process)
  4. py->mojo (nat)- Python calls Mojo via a native Mojo struct exposed
                     through add_type (extension module imported once,
                     timed in-process)

Scenarios 1 and 2 measure standalone program performance (includes interpreter
/compiler startup). Scenarios 3 and 4 measure the cost of calling into Mojo from
Python, which is the integration path this repo investigates.

Usage:
    uv run python benchmarks/runner.py               # all benchmarks
    uv run python benchmarks/runner.py nbody lru       # specific benchmarks
    uv run python benchmarks/runner.py --mojo-only     # only scenarios 2
    uv run python benchmarks/runner.py --python-only   # only scenario 1
    uv run python benchmarks/runner.py --no-integration# only scenarios 1, 2
    uv run python benchmarks/runner.py --warmup N       # warmup runs
    uv run python benchmarks/runner.py --runs N         # timed runs per benchmark
"""

import argparse
import os
import statistics
import subprocess
import sys
import time
from dataclasses import dataclass, field
from typing import Callable, Optional


PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXT_DIR = os.path.join(PROJECT_ROOT, "benchmarks", "mojo_ext")
PY_DIR = os.path.join(PROJECT_ROOT, "benchmarks", "python")
MOJO_DIR = os.path.join(PROJECT_ROOT, "benchmarks", "mojo")

sys.path.insert(0, PROJECT_ROOT)
sys.path.insert(0, EXT_DIR)

import mojo_tool  # noqa: E402

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

# Per-benchmark call specs for the two integration scenarios.
#   pyobj_call(module) -> result
#   native_call(module) -> result
BENCH_SPECS: dict[str, dict] = {
    "binarytrees": {
        "args": [15],
        "pyobj_call": lambda m: m.compute(15),
        "native_call": lambda m: m.Sim(4).run(15),
    },
    "nbody": {
        "args": [50000],
        "pyobj_call": lambda m: m.compute(50000),
        "native_call": lambda m: m.Sim().run(50000),
    },
    "nsieve": {
        "args": [4],
        "pyobj_call": lambda m: m.compute(4),
        "native_call": lambda m: m.Sim(3).run(4),
    },
    "pidigits": {
        "args": [4000],
        "pyobj_call": lambda m: m.compute(4000),
        "native_call": lambda m: m.Sim().run(4000),
    },
    "edigits": {
        "args": [100000],
        "pyobj_call": lambda m: m.compute(100000),
        "native_call": lambda m: m.Sim().run(100000),
    },
    "mandelbrot": {
        "args": [1000],
        "pyobj_call": lambda m: m.compute(1000),
        "native_call": lambda m: m.Sim(50).run(1000),
    },
    "fannkuch": {
        "args": [7],
        "pyobj_call": lambda m: m.compute(7),
        "native_call": lambda m: m.Sim(0).run(7),
    },
    "fasta": {
        "args": [250000],
        "pyobj_call": lambda m: m.compute(250000),
        "native_call": lambda m: m.Sim(42).run(250000),
    },
    "lru": {
        "args": [100, 500000],
        "pyobj_call": lambda m: m.compute(100, 500000),
        "native_call": lambda m: m.Sim(100).run(500000),
    },
    "spectral_norm": {
        "args": [2000],
        "pyobj_call": lambda m: m.compute(2000),
        "native_call": lambda m: m.Sim(10).run(2000),
    },
}


@dataclass
class BenchmarkResult:
    name: str
    python_times: list[float] = field(default_factory=list)
    mojo_times: list[float] = field(default_factory=list)
    pyobj_times: list[float] = field(default_factory=list)
    native_times: list[float] = field(default_factory=list)
    python_output: str = ""
    mojo_output: str = ""
    pyobj_output: str = ""
    native_output: str = ""
    python_error: Optional[str] = None
    mojo_error: Optional[str] = None
    pyobj_error: Optional[str] = None
    native_error: Optional[str] = None


def _median(times: list[float]) -> Optional[float]:
    return statistics.median(times) if times else None


def run_python_benchmark(name: str, *args) -> tuple[str, float, Optional[str]]:
    script = os.path.join(PY_DIR, f"{name}.py")
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
    script = os.path.join(MOJO_DIR, f"{name}.mojo")
    if not os.path.exists(script):
        return "", 0, f"Mojo benchmark not found: {script}"
    cmd = mojo_tool.mojo_args() + [script] + [str(a) for a in args]
    start = time.perf_counter()
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=PROJECT_ROOT,
            env=mojo_tool.mojo_env(),
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


def _run_integration(
    name: str, call: Callable[["Callable", ...], object], warmup: int, runs: int
) -> tuple[list[float], str, Optional[str]]:
    """Time the Python->Mojo integration scenario in-process.

    The extension module is imported once (outside the timed region) so the
    measurement reflects steady-state interop cost, not one-time import.
    """
    try:
        mod = __import__(name)
    except Exception as e:
        return [], "", f"import failed: {e}"

    times: list[float] = []
    output = ""
    error: Optional[str] = None

    def do_call() -> str:
        result = call(mod)
        return str(result)

    # Warmup (also triggers any lazy JIT/module init on first call).
    try:
        for _ in range(max(0, warmup)):
            do_call()
    except Exception as e:
        return [], "", f"warmup raised: {e}"

    for i in range(runs):
        try:
            start = time.perf_counter()
            output = do_call()
            times.append(time.perf_counter() - start)
        except Exception as e:
            return times, output, f"raised: {e}"

    return times, output, error


def run_benchmark(
    name: str,
    run_python: bool = True,
    run_mojo: bool = True,
    run_integration: bool = True,
    warmup: int = 1,
    runs: int = 3,
) -> BenchmarkResult:
    spec = BENCH_SPECS.get(name, {"args": [10], "pyobj_call": None, "native_call": None})
    args = spec["args"]
    result = BenchmarkResult(name=name)

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

    if run_integration and spec["pyobj_call"] is not None:
        times, out, err = _run_integration(
            name, spec["pyobj_call"], warmup, runs
        )
        result.pyobj_times = times
        result.pyobj_output = out
        result.pyobj_error = err

    if run_integration and spec["native_call"] is not None:
        times, out, err = _run_integration(
            name, spec["native_call"], warmup, runs
        )
        result.native_times = times
        result.native_output = out
        result.native_error = err

    return result


def _fmt(avg: Optional[float]) -> str:
    return f"{avg:.4f}" if avg is not None else "N/A"


def _speedup(py_avg: Optional[float], t: Optional[float]) -> str:
    if py_avg and t and t > 0:
        return f"{py_avg / t:.2f}x"
    return "N/A"


def _status(r: BenchmarkResult) -> str:
    parts = []
    if r.python_error:
        parts.append(f"PY-ERR: {r.python_error[:25]}")
    if r.mojo_error:
        parts.append(f"MOJO-ERR: {r.mojo_error[:25]}")
    if r.pyobj_error:
        parts.append(f"PYOBJ-ERR: {r.pyobj_error[:25]}")
    if r.native_error:
        parts.append(f"NATIVE-ERR: {r.native_error[:25]}")
    has_time = any(
        [r.python_times, r.mojo_times, r.pyobj_times, r.native_times]
    )
    if not has_time:
        parts.append("FAILED")
    elif r.python_times and r.mojo_times and r.pyobj_times and r.native_times:
        parts.append("OK")
    return "; ".join(parts)


def print_results(results: list[BenchmarkResult]):
    print("\n" + "=" * 118)
    print(
        f"{'Benchmark':<14} "
        f"{'Python':>10} {'Mojo':>10} {'py->mojo(py)':>13} {'py->mojo(nat)':>13} "
        f"{'Mojo/Py':>9} {'py/obj':>8} {'py/nat':>8} {'Status':<20}"
    )
    print("-" * 118)

    for r in results:
        py_avg = _median(r.python_times)
        mojo_avg = _median(r.mojo_times)
        pyobj_avg = _median(r.pyobj_times)
        native_avg = _median(r.native_times)

        mojo_py = f"{py_avg / mojo_avg:.2f}x" if (py_avg and mojo_avg and mojo_avg > 0) else "N/A"
        pyobj_sp = _speedup(py_avg, pyobj_avg)
        native_sp = _speedup(py_avg, native_avg)

        print(
            f"{r.name:<14} "
            f"{_fmt(py_avg):>10} {_fmt(mojo_avg):>10} {_fmt(pyobj_avg):>13} "
            f"{_fmt(native_avg):>13} {mojo_py:>9} {pyobj_sp:>8} {native_sp:>8} "
            f"{_status(r):<20}"
        )

    print("=" * 118)
    print(
        "Times are median of timed runs. 'Python'/'Mojo' include process startup; "
        "'py->mojo' are in-process interop calls.\n"
        "'Mojo/Py' = Python time / Mojo time. 'py/obj' and 'py/nat' = Python time /\n"
        "integration-scenario time (values >1 mean the integration is faster than pure Python)."
    )


def main():
    parser = argparse.ArgumentParser(description="Run benchmarks")
    parser.add_argument(
        "benchmarks", nargs="*", default=BENCHMARKS, help="Benchmarks to run"
    )
    parser.add_argument("--mojo-only", action="store_true", help="Only run Mojo")
    parser.add_argument("--python-only", action="store_true", help="Only run Python")
    parser.add_argument(
        "--no-integration",
        action="store_true",
        help="Skip the Python->Mojo integration scenarios",
    )
    parser.add_argument("--warmup", type=int, default=1, help="Warmup runs")
    parser.add_argument("--runs", type=int, default=3, help="Timed runs per benchmark")
    args = parser.parse_args()

    run_python = not args.mojo_only
    run_mojo = not args.python_only
    run_integration = not (args.mojo_only or args.python_only or args.no_integration)

    valid = set(BENCHMARKS)
    for name in args.benchmarks:
        if name not in valid:
            print(f"Unknown benchmark: {name}. Available: {', '.join(sorted(valid))}")
            sys.exit(1)

    results = []
    for name in args.benchmarks:
        print(f"\nRunning {name}...")
        r = run_benchmark(
            name,
            run_python,
            run_mojo,
            run_integration,
            args.warmup,
            args.runs,
        )
        results.append(r)

    print_results(results)


if __name__ == "__main__":
    main()
