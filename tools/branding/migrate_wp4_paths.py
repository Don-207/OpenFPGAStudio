#!/usr/bin/env python3
"""Apply the mechanical YiFPGA WP4 path and file-list migration."""

from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
TEXT_SUFFIXES = {".md", ".tcl", ".v", ".sv", ".vh", ".xpr", ".py"}
CURRENT_DOCS = {
    ROOT / "README.md",
    *(ROOT / "doc").glob("*使用说明.md"),
    ROOT / "doc/YiFPGA_品牌与代码兼容迁移计划.md",
    ROOT / "doc/YiFPGA_品牌迁移说明.md",
}


def candidates() -> list[Path]:
    paths = [ROOT / "justfile", *CURRENT_DOCS]
    for directory in (ROOT / "rtl", ROOT / "sim", ROOT / "prj/scripts"):
        paths.extend(
            path for path in directory.rglob("*")
            if path.is_file() and path.suffix in TEXT_SUFFIXES
        )
    paths.append(ROOT / "prj/YiFPGAStudio.xpr")
    paths.extend((ROOT / "tools").rglob("*.py"))
    return sorted(set(paths) - {Path(__file__).resolve()})


def migrate(text: str) -> str:
    replacements = (
        ("rtl/openfpga_debug", "rtl/yifpga_debug"),
        (r"rtl\openfpga_debug", r"rtl\yifpga_debug"),
        ("sim/openfpga_debug", "sim/yifpga_debug"),
        (r"sim\openfpga_debug", r"sim\yifpga_debug"),
        ("OpenFPGAStudio.xpr", "YiFPGAStudio.xpr"),
        ("OpenFPGAStudio.runs", "YiFPGAStudio.runs"),
        ("OpenFPGAStudio.cache", "YiFPGAStudio.cache"),
        ("OpenFPGAStudio.sim", "YiFPGAStudio.sim"),
        ("OpenFPGAStudio.hw", "YiFPGAStudio.hw"),
        ("tb_openfpga_", "tb_yifpga_"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    text = re.sub(
        r"openfpga_([a-z0-9_]+)\.(v|sv|vh|tcl)",
        r"yifpga_\1.\2",
        text,
    )
    # Current build/project entry points use canonical module names. ABI values
    # and compatibility wrapper declarations are deliberately not global-replaced.
    text = re.sub(r"(?<=-top )openfpga_", "yifpga_", text)
    text = re.sub(r"(?<=top )openfpga_", "yifpga_", text)
    text = text.replace('Val="openfpga_debug_board_demo"', 'Val="yifpga_debug_board_demo"')
    return text


def main() -> int:
    changed = 0
    for path in candidates():
        if not path.exists():
            continue
        original = path.read_text(encoding="utf-8")
        updated = migrate(original)
        if path.parent == ROOT / "prj/scripts" and "yifpga" in path.name:
            updated = updated.replace("rtl openfpga_debug", "rtl yifpga_debug")
            updated = updated.replace("openfpga_", "yifpga_")
        if path == ROOT / "prj/YiFPGAStudio.xpr":
            updated = updated.replace("OpenFPGAStudio", "YiFPGAStudio")
            updated = updated.replace("openfpga_", "yifpga_")
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            changed += 1
    print(f"updated {changed} current files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
