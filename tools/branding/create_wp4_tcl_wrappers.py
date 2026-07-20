#!/usr/bin/env python3
"""Create deprecated OpenFPGA Tcl entry wrappers for YiFPGA canonical scripts."""

from __future__ import annotations

import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_DIR = ROOT / "prj/scripts"
HEADER = "# Deprecated compatibility entry point; use {canonical}.\n"
BODY = "set script_dir [file dirname [file normalize [info script]]]\nsource [file join $script_dir {canonical}]\n"


def expected() -> dict[Path, str]:
    wrappers: dict[Path, str] = {}
    for canonical in sorted(SCRIPT_DIR.glob("*yifpga*.tcl")):
        legacy_name = canonical.name.replace("yifpga", "openfpga")
        wrapper = SCRIPT_DIR / legacy_name
        wrappers[wrapper] = HEADER.format(canonical=canonical.name) + BODY.format(
            canonical=canonical.name
        )
    return wrappers


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale = [path for path, content in expected().items()
             if not path.exists() or path.read_text(encoding="utf-8") != content]
    if args.check:
        if stale:
            print("stale Tcl wrappers: " + ", ".join(path.name for path in stale))
            return 1
        print(f"Tcl wrappers: PASS ({len(expected())})")
        return 0
    for path in stale:
        path.write_text(expected()[path], encoding="utf-8")
    print(f"wrote {len(stale)} Tcl wrappers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
