#!/usr/bin/env python3
"""Inventory legacy OpenFPGA names without modifying repository content."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEGACY_RE = re.compile(r"OpenFPGA|openfpga|OPENFPGA|OFD_")
ABI_RE = re.compile(
    r"openfpga\.(?:diagnostic_snapshot|diagnostic_findings|ai_debug_report|"
    r"ai_debug_board_run|ai_debug_board_qualification)|openfpga-diagnosis-v1|OFD_"
)
SOURCE_SUFFIXES = {
    ".c", ".cc", ".cpp", ".h", ".hpp", ".html", ".js", ".py", ".tcl",
    ".v", ".vh", ".sv", ".svh", ".xdc",
}
HISTORY_MARKERS = (
    "验证", "验收", "收口", "测试清单", "测试报告", "实施计划", "检查清单",
    "qualification", "release_check",
)
GENERATED_PREFIXES = (
    "prj/YiFPGAStudio.cache/", "prj/YiFPGAStudio.hw/",
    "prj/OpenFPGAStudio.ioplanning/", "prj/OpenFPGAStudio.ip_user_files/",
    "prj/YiFPGAStudio.runs/", "prj/YiFPGAStudio.sim/",
    "prj/YiFPGAStudio.cache/", "prj/YiFPGAStudio.hw/",
    "prj/YiFPGAStudio.runs/", "prj/YiFPGAStudio.sim/",
)


def repository_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    return [ROOT / item.decode() for item in result.stdout.split(b"\0") if item]


def classify(relative: str, suffix: str, line: str) -> str:
    if relative.startswith(GENERATED_PREFIXES):
        return "generated"
    if ABI_RE.search(line):
        return "protocol_abi"
    if relative.startswith("artifacts/") or (
        relative.startswith("doc/") and any(marker in relative for marker in HISTORY_MARKERS)
    ):
        return "historical_evidence"
    if suffix in SOURCE_SUFFIXES or relative in {"justfile", "Makefile"}:
        return "source_identifier"
    return "brand_text"


def collect() -> dict[str, object]:
    occurrences: list[dict[str, object]] = []
    unreadable: list[str] = []
    for path in repository_files():
        relative = path.relative_to(ROOT).as_posix()
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            unreadable.append(relative)
            continue
        for line_number, line in enumerate(text.splitlines(), 1):
            matches = LEGACY_RE.findall(line)
            if not matches:
                continue
            occurrences.append(
                {
                    "category": classify(relative, path.suffix.lower(), line),
                    "file": relative,
                    "line": line_number,
                    "matches": matches,
                }
            )

    category_hits = Counter()
    category_files: dict[str, set[str]] = defaultdict(set)
    for item in occurrences:
        category = str(item["category"])
        category_hits[category] += len(item["matches"])
        category_files[category].add(str(item["file"]))

    return {
        "schema_version": 1,
        "patterns": ["OpenFPGA", "openfpga", "OPENFPGA", "OFD_"],
        "summary": {
            category: {
                "files": len(category_files[category]),
                "matches": category_hits[category],
            }
            for category in sorted(category_hits)
        },
        "total_files": len({str(item["file"]) for item in occurrences}),
        "total_matches": sum(category_hits.values()),
        "occurrences": occurrences,
        "unreadable_repository_files": unreadable,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--summary", action="store_true", help="print only the deterministic summary"
    )
    args = parser.parse_args()
    inventory = collect()
    output = inventory["summary"] if args.summary else inventory
    print(json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
