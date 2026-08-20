"""
Verify that the Mojo extension modules produce output matching the Python
reference implementations.

For every benchmark we compare three outputs:
  1. python  - pure Python implementation (benchmarks/python/<name>.py)
  2. pyobj   - Mojo extension called via the PythonObject boundary ("python objects")
  3. native  - Mojo extension called via a native Mojo struct ("native objects")

Usage:
    uv run python benchmarks/verify.py                 # all benchmarks
    uv run python benchmarks/verify.py nbody lru        # specific benchmarks
"""

import os
import sys
import subprocess
import argparse

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXT_DIR = os.path.join(PROJECT_ROOT, "benchmarks", "mojo_ext")
PY_DIR = os.path.join(PROJECT_ROOT, "benchmarks", "python")

sys.path.insert(0, EXT_DIR)

# (python_args, pyobj_call, native_call)
#   pyobj_call / native_call are Python expressions evaluated in the harness.
BENCHMARKS = {
    "binarytrees": {
        "args": [15],
        "pyobj": "mod.compute(15)",
        "native": "mod.Sim(4).run(15)",
    },
    "nbody": {
        "args": [50000],
        "pyobj": "mod.compute(50000)",
        "native": "mod.Sim().run(50000)",
    },
    "nsieve": {
        "args": [4],
        "pyobj": "mod.compute(4)",
        "native": "mod.Sim(3).run(4)",
    },
    "pidigits": {
        "args": [4000],
        "pyobj": "mod.compute(4000)",
        "native": "mod.Sim().run(4000)",
    },
    "edigits": {
        "args": [100000],
        "pyobj": "mod.compute(100000)",
        "native": "mod.Sim().run(100000)",
    },
    "mandelbrot": {
        "args": [1000],
        "pyobj": "mod.compute(1000)",
        "native": "mod.Sim(50).run(1000)",
    },
    "fannkuch": {
        "args": [7],
        "pyobj": "mod.compute(7)",
        "native": "mod.Sim(0).run(7)",
    },
    "fasta": {
        "args": [250000],
        "pyobj": "mod.compute(250000)",
        "native": "mod.Sim(42).run(250000)",
    },
    "lru": {
        "args": [100, 500000],
        "pyobj": "mod.compute(100, 500000)",
        "native": "mod.Sim(100).run(500000)",
    },
    "spectral_norm": {
        "args": [2000],
        "pyobj": "mod.compute(2000)",
        "native": "mod.Sim(10).run(2000)",
    },
}


def run_python(name: str, args):
    script = os.path.join(PY_DIR, f"{name}.py")
    cmd = [sys.executable, script] + [str(a) for a in args]
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=PROJECT_ROOT)
    return result.stdout.strip()


def run_extension(name: str, pyobj_expr: str, native_expr: str):
    module = __import__(name)
    env = {"__builtins__": __builtins__, "mod": module}
    pyobj_out = str(eval(pyobj_expr, env))
    native_out = str(eval(native_expr, env))
    return pyobj_out, native_out


def normalize(s: str) -> str:
    return "\n".join(line.strip() for line in s.splitlines()).strip()


def last_line(s: str) -> str:
    lines = [line.strip() for line in s.splitlines() if line.strip()]
    return lines[-1] if lines else ""


def numeric_close(a: str, b: str) -> bool:
    try:
        fa = float(a)
        fb = float(b)
    except ValueError:
        return False
    if fa == 0.0 and fb == 0.0:
        return True
    tol = max(abs(fa), abs(fb)) * 1e-6 + 1e-12
    return abs(fa - fb) <= tol


def outputs_match(a: str, b: str) -> bool:
    """Compare two benchmark outputs.

    Numeric results are compared with a relative tolerance (Python reference
    implementations format to a fixed number of decimals, Mojo prints full
    float precision). Everything else is compared as normalized text.
    """
    a_norm = normalize(a)
    b_norm = normalize(b)
    if a_norm == b_norm:
        return True
    # Fall back to comparing the last line numerically (e.g. nbody prints an
    # initial and a final energy; only the final is returned by the extension).
    if numeric_close(last_line(a_norm), last_line(b_norm)):
        return True
    return False


def main():
    parser = argparse.ArgumentParser(description="Verify Mojo extension outputs")
    parser.add_argument("benchmarks", nargs="*", default=list(BENCHMARKS.keys()))
    args = parser.parse_args()

    valid = set(BENCHMARKS)
    for name in args.benchmarks:
        if name not in valid:
            print(f"Unknown benchmark: {name}. Available: {', '.join(sorted(valid))}")
            sys.exit(1)

    all_ok = True
    for name in args.benchmarks:
        spec = BENCHMARKS[name]
        args_list = spec["args"]
        py_out = run_python(name, args_list)
        try:
            pyobj_out, native_out = run_extension(name, spec["pyobj"], spec["native"])
        except Exception as e:
            print(f"[FAIL] {name}: extension raised {e!r}")
            all_ok = False
            continue

        pyobj_ok = outputs_match(pyobj_out, py_out)
        native_ok = outputs_match(native_out, py_out)
        ok = pyobj_ok and native_ok
        all_ok = all_ok and ok
        status = "OK" if ok else "FAIL"
        print(f"[{status}] {name}")
        if not pyobj_ok:
            print(f"    pyobj mismatch:")
            print(f"      pyobj: {pyobj_out!r}")
            print(f"      py   : {py_out!r}")
        if not native_ok:
            print(f"    native mismatch:")
            print(f"      native: {native_out!r}")
            print(f"      py   : {py_out!r}")

    print("\nALL OK" if all_ok else "\nSOME FAILED")
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
