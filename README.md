# mojo-py

Performance comparison of Python vs Mojo, with a focus on **how Python and Mojo
are integrated**. This is a replication of the algorithm benchmarks from
[Programming-Language-Benchmarks](https://github.com/hanabi1224/Programming-Language-Benchmarks)
across four execution scenarios (ablations).

## Execution scenarios (ablations)

Each benchmark is measured in four ways:

| Column            | Scenario                                                        | How it's measured                              |
| ----------------- | --------------------------------------------------------------- | ---------------------------------------------- |
| `Python`          | Pure Python, standalone                                         | `python benchmarks/python/<name>.py` (subprocess) |
| `Mojo`            | Pure Mojo, standalone                                           | `mojo benchmarks/mojo/<name>.mojo` (subprocess) |
| `py->mojo (py)`   | Python calls Mojo via the **PythonObject** boundary             | extension module imported once, timed in-process |
| `py->mojo (nat)`  | Python calls Mojo via a **native Mojo struct** (`add_type`)     | extension module imported once, timed in-process |

Scenarios 1–2 measure standalone program performance and therefore **include
interpreter/compiler startup**. Scenarios 3–4 measure the cost of calling into
Mojo from Python (the integration path this repo investigates) and are timed
**in-process**, so they reflect steady-state interop cost, not one-time import.

The two integration scenarios differ in how data crosses the Python↔Mojo
boundary:

- **python objects** — arguments and results are passed as `PythonObject` values
  and converted at the boundary (`compute(n)`).
- **native objects** — a Mojo struct is exposed to Python via `add_type`; Python
  holds a native Mojo handle and calls methods on it (`Sim(...).run(...)`) with
  no per-call Python-object marshalling of the payload.

## Benchmark suite

Ten algorithm benchmarks (from the Computer Language Benchmarks Game and related
sets): `binarytrees`, `nbody`, `nsieve`, `pidigits`, `edigits`, `mandelbrot`,
`fannkuch`, `fasta`, `lru`, `spectral_norm`.

```
benchmarks/
  python/       pure Python reference implementations
  mojo/         pure Mojo implementations (standalone `mojo run`)
  mojo_ext/     Python-callable Mojo extension modules (.mojo source + built .so)
                each exposes both a `compute()` (py-objects) and a `Sim` struct
                (native objects)
  runner.py     runs all four scenarios and prints a comparison table
  verify.py     checks each extension module's output matches the Python reference
  build_ext.py  rebuilds the .so extension modules
  mojo_tool.py  locates the Mojo compiler and builds a correct subprocess env
```

## Setup

This project uses [`uv`](https://docs.astral.sh/uv/). Mojo is obtained through
`uv` (the `mojo` uv tool / `mojo-compiler`). The helper `benchmarks/mojo_tool.py`
auto-detects the `mojo` executable and constructs a subprocess environment that
finds Mojo's own `mojo` package (importing a compiled `.so` in the parent process
can otherwise break the Mojo launcher's site discovery in the child).

## Usage

```bash
# Build the extension modules (.so) once
uv run python benchmarks/build_ext.py

# Run all four scenarios for every benchmark
uv run python benchmarks/runner.py

# Specific benchmarks
uv run python benchmarks/runner.py nbody spectral_norm

# Only certain scenarios
uv run python benchmarks/runner.py --no-integration   # Python vs Mojo only
uv run python benchmarks/runner.py --mojo-only
uv run python benchmarks/runner.py --python-only

# Tuning
uv run python benchmarks/runner.py --warmup 2 --runs 5

# Verify correctness of the extension modules against the Python references
uv run python benchmarks/verify.py
```

### Output table

| Benchmark   | Python  | Mojo    | py->mojo(py) | py->mojo(nat) | Mojo/Py | py/obj | py/nat | Status |
| ----------- | ------- | ------- | ------------ | ------------- | ------- | ------ | ------ | ------ |
| spectral_norm | 16.44 | 0.602   | 0.167        | 0.161         | 27.29x  | 98.50x | 101.94x | OK |
| nbody       | 0.319   | 0.488   | 0.0036       | 0.0034        | 0.65x   | 88.90x | 93.38x  | OK |
| ...         | ...     | ...     | ...          | ...           | ...     | ...    | ...     | ... |

- Times are the **median** of timed runs (seconds; lower is better).
- `Mojo/Py` = Python time / Mojo time. `py/obj` and `py/nat` = Python time /
  integration time. Values `>1` mean that column is faster than pure Python.

## Results (representative, single run)

| Benchmark   | Python  | Mojo    | py→mojo(py) | py→mojo(nat) | Mojo/Py | py/obj | py/nat |
| ----------- | ------- | ------- | ----------- | ------------ | ------- | ------ | ------ |
| spectral_norm | 16.44 | 0.602   | 0.167       | 0.161        | 27.3x   | 98.5x  | 101.9x |
| nbody       | 0.319   | 0.488   | 0.0036      | 0.0034       | 0.65x   | 88.9x  | 93.4x  |
| mandelbrot  | 2.40    | 0.642   | 0.058       | 0.070        | 3.74x   | 41.4x  | 34.5x  |
| fannkuch    | 7.81    | 2.260   | 1.853       | 1.844        | 3.46x   | 4.2x   | 4.2x   |
| fasta       | 0.258   | 0.757   | 0.046       | 0.046        | 0.34x   | 5.6x   | 5.6x   |
| lru         | 0.376   | 0.497   | 0.030       | 0.031        | 0.76x   | 12.7x  | 12.3x  |
| nsieve      | 0.036   | 0.448   | 0.0012      | 0.0012       | 0.08x   | 30.5x  | 30.8x  |
| edigits     | 0.149   | 0.644   | 0.126       | 0.126        | 0.23x   | 1.2x   | 1.2x   |
| pidigits    | 0.792   | 1.268   | 0.767       | 0.766        | 0.62x   | 1.0x   | 1.0x   |
| binarytrees | 0.433   | 0.821   | 0.371       | 0.372        | 0.53x   | 1.2x   | 1.2x   |

Numbers vary by machine and warm state; run `runner.py` yourself to get local
figures. Run `verify.py` to confirm every extension matches its Python reference.

## Performance considerations & findings

1. **Integration is dramatically faster than pure Python for compute-heavy work.**
   `spectral_norm`, `nbody`, and `mandelbrot` see 30–100× speedups when called
   from Python into a compiled Mojo extension. The JIT-compiled floating-point
   kernels win big, and the per-call interop overhead is negligible next to the
   work.

2. **Both integration paths perform similarly.** `py->mojo (py)` and
   `py->mojo (nat)` times are close across the board. For these benchmarks the
   payload crossing the boundary is small (scalars / a few structs), so the
   PythonObject marshalling cost is minor. Native objects matter most when a
   large dataset would otherwise be copied into Python objects on every call.

3. **Pure `mojo run` includes per-invocation compilation.** The `Mojo` column
   compiles the `.mojo` file on every invocation, so for small benchmarks it
   looks *slower* than Python (`nsieve` 0.08×, `binarytrees` 0.53×). This is the
   realistic cost of "run a Mojo script from scratch", but it is not a fair
   measure of raw compute throughput — for that, use the in-process integration
   columns, which benefit from the pre-built `.so`.

4. **Big-integer benchmarks can't be natively accelerated.** `pidigits` and
   `edigits` rely on arbitrary-precision arithmetic, but Mojo's native `Int` is
   64-bit and overflows. Their implementations (both pure Mojo and the extension)
   delegate the spigot arithmetic to Python via `std.python` (`Python.evaluate`).
   Consequently the integration speedup is ~1× — Mojo is effectively a thin
   wrapper, which is an honest and important boundary to know about.

5. **The integration pattern is robust.** `mojo_tool.mojo_env()` pins
   `PYTHONPATH` to Mojo's site-packages when spawning the compiler, so building
   and running extensions works even after a `.so` has been imported into the
   parent interpreter.

## Extending

To add a benchmark: drop a `python/<name>.py` and `mojo/<name>.mojo` into the
respective dirs, then a `mojo_ext/<name>.mojo` exposing `compute()` and a `Sim`
struct, register it in `runner.py`'s `BENCH_SPECS`, and run
`build_ext.py` + `runner.py` + `verify.py`.
