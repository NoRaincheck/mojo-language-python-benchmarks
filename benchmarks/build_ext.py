"""Build all Mojo extension modules (.so) in benchmarks/mojo_ext/.

These are the Python-callable extension modules used by the benchmark runner to
measure the "Python calling Mojo" integration scenarios.

Usage:
    uv run python benchmarks/build_ext.py            # build every .mojo
    uv run python benchmarks/build_ext.py nbody lru  # build specific modules
"""

import argparse
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mojo_tool  # noqa: E402

EXT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mojo_ext")
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


def build_one(name: str) -> bool:
    src = os.path.join(EXT_DIR, f"{name}.mojo")
    dst = os.path.join(EXT_DIR, f"{name}.so")
    if not os.path.exists(src):
        print(f"[skip] {name}: source not found")
        return True

    cmd = mojo_tool.mojo_args() + [
        "build",
        "--emit",
        "shared-lib",
        src,
        "-o",
        dst,
    ]
    start = time.perf_counter()
    result = subprocess.run(
        cmd, capture_output=True, text=True, env=mojo_tool.mojo_env()
    )
    elapsed = time.perf_counter() - start
    if result.returncode != 0:
        print(f"[FAIL] {name} ({elapsed:.1f}s)")
        sys.stderr.write(result.stderr[-2000:])
        return False
    print(f"[ok]   {name} ({elapsed:.1f}s)")
    return True


def main():
    parser = argparse.ArgumentParser(description="Build Mojo extension modules")
    parser.add_argument(
        "benchmarks", nargs="*", default=BENCHMARKS, help="Modules to build"
    )
    args = parser.parse_args()

    valid = set(BENCHMARKS)
    for name in args.benchmarks:
        if name not in valid:
            print(f"Unknown benchmark: {name}. Available: {', '.join(sorted(valid))}")
            sys.exit(1)

    print(f"Mojo: {mojo_tool.mojo_path()}")
    print(f"Building {len(args.benchmarks)} extension module(s) in {EXT_DIR}")
    ok = all(build_one(name) for name in args.benchmarks)
    print("ALL OK" if ok else "SOME FAILED")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
