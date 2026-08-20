"""Locate the Mojo compiler executable across common install methods.

Mojo can be installed several ways (system PATH, `uv tool`, `uv run --from`).
This module tries each in turn and caches the resolved path so callers don't
pay for repeated discovery.
"""

import os
import shutil
import subprocess
import sys
from functools import lru_cache
from pathlib import Path


def _candidate_paths() -> list[Path]:
    """Paths where a mojo binary might already live (no resolution needed)."""
    candidates: list[Path] = []
    home = Path.home()
    for tool_dir in (
        home / ".local" / "share" / "uv" / "tools" / "mojo" / "bin",
        home / ".cargo" / "bin",
        home / ".local" / "bin",
        Path("/opt/homebrew/bin"),
        Path("/usr/local/bin"),
    ):
        candidates.append(tool_dir / "mojo")
    return candidates


def _mojo_venv_python() -> Path:
    """Path to the Python interpreter bundled inside the mojo uv tool."""
    return _candidate_paths()[0].parent / "python"


def _mojo_site_packages() -> str:
    """site-packages dir of the mojo venv Python (where the `mojo` package lives)."""
    py = _mojo_venv_python()
    if py.is_file():
        try:
            out = subprocess.run(
                [str(py), "-c",
                 "import sys; print(next(p for p in sys.path if 'site-packages' in p))"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if out.returncode == 0 and out.stdout.strip():
                return out.stdout.strip()
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass
    # Fallback: derive from the known venv layout.
    return str(
        Path.home()
        / ".local"
        / "share"
        / "uv"
        / "tools"
        / "mojo"
        / "lib"
        / f"python{sys.version_info.major}.{sys.version_info.minor}"
        / "site-packages"
    )


@lru_cache(maxsize=1)
def mojo_path() -> str:
    """Return the path to the `mojo` executable, or raise if not found."""
    # 1. Already on PATH?
    found = shutil.which("mojo")
    if found:
        return found

    # 2. Known uv-tool / install locations?
    for path in _candidate_paths():
        if path.is_file():
            return str(path)

    # 3. Fall back to resolving via uv (slower, first call only).
    try:
        result = subprocess.run(
            ["uv", "tool", "run", "--from", "mojo-compiler", "mojo", "--version"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode == 0:
            found = shutil.which("mojo")
            if found:
                return found
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    raise RuntimeError(
        "Mojo compiler not found. Install it with "
        "`uv tool install mojo` or put `mojo` on your PATH."
    )


@lru_cache(maxsize=1)
def mojo_env() -> dict:
    """Environment for spawning the mojo subprocess.

    The mojo launcher is a Python script that imports its own `mojo` package.
    Importing a compiled extension module in the parent process can disrupt the
    child's site-package discovery, so we set PYTHONPATH explicitly to the
    mojo venv's site-packages to make the subprocess robust.
    """
    env = dict(os.environ)
    site = _mojo_site_packages()
    existing = env.get("PYTHONPATH", "")
    env["PYTHONPATH"] = site if not existing else f"{site}{os.pathsep}{existing}"
    return env


def mojo_args() -> list[str]:
    """Return a cross-platform command prefix for invoking mojo."""
    path = mojo_path()
    # On Windows the launcher is mojo.exe; everywhere else it's mojo.
    exe = path + (".exe" if sys.platform == "win32" else "")
    return [exe] if Path(exe).is_file() else [path]


if __name__ == "__main__":
    print(mojo_path())
