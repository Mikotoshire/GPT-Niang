"""Compatibility entry point for the Windows maintenance release builder."""
import runpy
from pathlib import Path

if __name__ == "__main__":
    runpy.run_path(str(Path(__file__).with_name("build-release.py")), run_name="__main__")
