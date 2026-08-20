#!/usr/bin/env python3
"""
Comprehensive benchmark profiler: Python vs Zig vs Mojo interop.

This profiler measures:
1. Pure Python execution time
2. Pure Zig execution time (compiled native binary)
3. Mojo's Python interop overhead (Mojo calling Python)

Usage:
    python benchmarks/profiler/profile.py                  # Full profile
    python benchmarks/profiler/profile.py --only-native    # Only Python vs Zig
    python benchmarks/profiler/profile.py --only-interop   # Only interop overhead
    python benchmarks/profiler/profile.py nbody lru        # Specific benchmarks
    python benchmarks/profiler/profile.py --runs 5         # More runs for accuracy
"""

import sys
import os
import time
import subprocess
import argparse
import json
from dataclasses import dataclass, field, asdict
from typing import Optional
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent
BENCHMARKS = ["binarytrees", "nbody", "lru"]

BENCH_ARGS = {
    "binarytrees": [15],
    "nbody": [50000],
    "lru": [100, 500000],
}


@dataclass
class BenchmarkResult:
    name: str
    python_time: Optional[float] = None
    zig_time: Optional[float] = None
    mojo_interop_time: Optional[float] = None
    python_output: str = ""
    zig_output: str = ""
    mojo_interop_output: str = ""
    errors: list[str] = field(default_factory=list)

    @property
    def speedups(self) -> dict[str, float]:
        speedups = {}
        if self.python_time and self.python_time > 0:
            for lang, time_attr in [("zig", "zig_time"), ("mojo_interop", "mojo_interop_time")]:
                t = getattr(self, time_attr)
                if t and t > 0:
                    speedups[lang] = self.python_time / t
        return speedups

    @property
    def interop_overhead(self) -> Optional[float]:
        if (self.mojo_interop_time and self.zig_time and self.zig_time > 0):
            return self.mojo_interop_time / self.zig_time
        return None


def compile_zig(src: Path, out: Path) -> Optional[str]:
    cmd = ["zig", "build-exe", str(src), "-femit-bin=" + str(out), "-O", "ReleaseFast"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if result.returncode != 0:
            return result.stderr.strip()
        return None
    except FileNotFoundError:
        return "zig compiler not found"
    except subprocess.TimeoutExpired:
        return "zig compilation timeout"


def run_benchmark(cmd: list[str], timeout: int = 120) -> tuple[str, float, Optional[str]]:
    start = time.perf_counter()
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        elapsed = time.perf_counter() - start
        if result.returncode != 0:
            return result.stdout.strip(), elapsed, result.stderr.strip()
        return result.stdout.strip(), elapsed, None
    except subprocess.TimeoutExpired:
        return "", time.perf_counter() - start, "Timeout"
    except Exception as e:
        return "", 0, str(e)


def run_python_bench(name: str) -> tuple[str, float, Optional[str]]:
    script = PROJECT_ROOT / "benchmarks" / "python" / f"{name}.py"
    args = BENCH_ARGS.get(name, [])
    return run_benchmark([sys.executable, str(script)] + [str(a) for a in args])


def run_zig_bench(compiled: Path) -> tuple[str, float, Optional[str]]:
    return run_benchmark([str(compiled)])


def run_mojo_interop(name: str) -> tuple[str, float, Optional[str]]:
    """Run Mojo benchmark that calls Python via interop.
    
    This measures the cost of Mojo calling Python functions.
    """
    interop_script = PROJECT_ROOT / "benchmarks" / "profiler" / f"_interop_{name}.mojo"
    args = BENCH_ARGS.get(name, [])
    
    setup = '''    from std.python import Python
    var sys = Python.import_module("sys")
    var os = Python.import_module("os")
    var cwd = os.getcwd()
    sys.path.insert(0, cwd)
'''
    
    if name == "binarytrees":
        code = f"""def main() raises:
{setup}    var bt = Python.import_module("benchmarks.python.binarytrees")
    var result = bt.main({args[0]})
"""
    elif name == "nbody":
        code = f"""def main() raises:
{setup}    var nbody = Python.import_module("benchmarks.python.nbody")
    var result = nbody.run({args[0]})
    print(t"{{result}}")
"""
    elif name == "lru":
        code = f"""def main() raises:
{setup}    var lru = Python.import_module("benchmarks.python.lru")
    var result = lru.run({args[0]}, {args[1]})
    print(t"{{result[0]}}")
    print(t"{{result[1]}}")
"""
    else:
        code = f"""def main() raises:
{setup}    var py = Python.import_module("benchmarks.python.{name}")
    var result = py.main({",".join(str(a) for a in args)})
"""

    interop_script.write_text(code)
    
    args_list = [str(a) for a in args]
    output, elapsed, error = run_benchmark(["mojo", str(interop_script)] + args_list)
    
    try:
        interop_script.unlink()
    except:
        pass
    
    return output, elapsed, error


def run_all_runs(runner, runs: int) -> tuple[Optional[float], str, Optional[str]]:
    times = []
    output = ""
    error = None
    
    for i in range(runs):
        out, elapsed, err = runner()
        if err is None:
            times.append(elapsed)
            output = out
        else:
            error = err
            break
    
    if times:
        return sum(times) / len(times), output, error
    return None, output, error


def profile_benchmark(name: str, runs: int = 3) -> BenchmarkResult:
    result = BenchmarkResult(name=name)
    
    # Python
    py_avg, py_out, py_err = run_all_runs(lambda: run_python_bench(name), runs)
    result.python_time = py_avg
    result.python_output = py_out
    if py_err:
        result.errors.append(f"Python: {py_err}")
    
    # Zig
    zig_dir = PROJECT_ROOT / "benchmarks" / "zig"
    zig_bin = zig_dir / f"{name}_bench"
    zig_err = compile_zig(zig_dir / f"{name}.zig", zig_bin)
    
    if zig_err is None:
        zig_avg, zig_out, zig_err2 = run_all_runs(lambda: run_zig_bench(zig_bin), runs)
        result.zig_time = zig_avg
        result.zig_output = zig_out
        if zig_err2:
            result.errors.append(f"Zig: {zig_err2}")
    else:
        result.errors.append(f"Zig compile: {zig_err}")
    
    # Mojo interop
    interop_avg, interop_out, interop_err = run_all_runs(
        lambda: run_mojo_interop(name), runs
    )
    result.mojo_interop_time = interop_avg
    result.mojo_interop_output = interop_out
    if interop_err:
        result.errors.append(f"Mojo interop: {interop_err}")
    
    return result


def print_table(results: list[BenchmarkResult]):
    print("\n" + "=" * 100)
    print("NATIVE EXECUTION COMPARISON (lower is better)")
    print("=" * 100)
    print(f"{'Benchmark':<15} {'Python':>10} {'Zig':>10} {'Mojo+Py':>10} {'Zig/Py':>10} {'Mojo/Py':>10} {'Mojo/Zig':>10}")
    print("-" * 100)
    
    for r in results:
        py = r.python_time
        zig = r.zig_time
        interop = r.mojo_interop_time
        
        py_s = f"{py:.4f}s" if py else "N/A"
        zig_s = f"{zig:.4f}s" if zig else "N/A"
        interop_s = f"{interop:.4f}s" if interop else "N/A"
        
        zig_py = f"{py/zig:.2f}x" if py and zig and zig > 0 else "N/A"
        interop_py = f"{py/interop:.2f}x" if py and interop and interop > 0 else "N/A"
        interop_zig = f"{interop/zig:.2f}x" if interop and zig and zig > 0 else "N/A"
        
        print(f"{r.name:<15} {py_s:>10} {zig_s:>10} {interop_s:>10} {zig_py:>10} {interop_py:>10} {interop_zig:>10}")
    
    print("=" * 100)


def print_analysis(results: list[BenchmarkResult]):
    print("\n" + "=" * 80)
    print("KEY INSIGHTS")
    print("=" * 80)
    
    zig_speedups = []
    interop_ratios = []
    
    for r in results:
        if r.python_time and r.zig_time and r.zig_time > 0:
            zig_speedups.append(r.python_time / r.zig_time)
        if r.interop_overhead:
            interop_ratios.append(r.interop_overhead)
    
    if zig_speedups:
        avg_zig = sum(zig_speedups) / len(zig_speedups)
        print(f"\n1. Zig average speedup over Python: {avg_zig:.2f}x")
    
    if interop_ratios:
        avg_overhead = sum(interop_ratios) / len(interop_ratios)
        print(f"2. Mojo interop overhead (vs Zig): {avg_overhead:.2f}x ({(avg_overhead-1)*100:.1f}%)")
    
    print("\n" + "-" * 80)
    print("INTERPRETATION:")
    print("-" * 80)
    
    if zig_speedups:
        avg_zig = sum(zig_speedups) / len(zig_speedups)
        if avg_zig > 10:
            print(f"  Zig is {avg_zig:.1f}x faster than Python - expected for a compiled language.")
            print("  This confirms that compilation provides significant speedup over interpreted Python.")
        elif avg_zig > 3:
            print(f"  Zig is {avg_zig:.1f}x faster than Python - solid compiled language performance.")
        else:
            print(f"  Zig is {avg_zig:.1f}x faster than Python - modest improvement.")
    
    if interop_ratios:
        avg_overhead = sum(interop_ratios) / len(interop_ratios)
        if avg_overhead > 3.0:
            print(f"  Mojo->Python interop adds significant overhead ({avg_overhead:.1f}x).")
            print("  If Mojo calls Python frequently, this overhead dominates execution time.")
            print("  For Mojo to be truly fast, it must avoid Python interop in hot paths.")
        else:
            print(f"  Mojo->Python interop overhead is modest ({avg_overhead:.1f}x).")
    
    print("\n" + "=" * 80)


def main():
    parser = argparse.ArgumentParser(description="Comprehensive benchmark profiler")
    parser.add_argument("benchmarks", nargs="*", default=BENCHMARKS,
                       help="Benchmarks to profile")
    parser.add_argument("--runs", type=int, default=3, help="Number of timed runs")
    parser.add_argument("--only-native", action="store_true",
                       help="Only run native benchmarks (Python vs Zig)")
    parser.add_argument("--only-interop", action="store_true",
                       help="Only measure interop overhead")
    parser.add_argument("--json", dest="output_json", action="store_true",
                       help="Output results as JSON")
    args = parser.parse_args()
    
    valid = set(BENCHMARKS)
    for name in args.benchmarks:
        if name not in valid:
            print(f"Unknown benchmark: {name}. Available: {', '.join(valid)}")
            sys.exit(1)
    
    results = []
    for name in args.benchmarks:
        print(f"\nProfiling {name}...")
        r = profile_benchmark(name, args.runs)
        results.append(r)
        
        if r.errors:
            print(f"  Errors: {'; '.join(r.errors)}")
    
    if not args.only_interop:
        print_table(results)
    
    if not args.only_native:
        print_analysis(results)
    
    if args.output_json:
        json_data = {"benchmarks": [asdict(r) for r in results]}
        print("\n" + json.dumps(json_data, indent=2))


if __name__ == "__main__":
    main()
