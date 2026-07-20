#!/usr/bin/env python3
"""Migrate RTL module identifiers to YiFPGA and append legacy wrappers."""

from __future__ import annotations

import argparse
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
RTL_DIRS = (ROOT / "rtl/yifpga_debug", ROOT / "rtl/vendor/xilinx", ROOT / "rtl/board")
MODULE_RE = re.compile(r"\bmodule\s+(openfpga_[A-Za-z0-9_]+)\b")
WRAPPER_MARKER = "// Deprecated v1.x compatibility wrapper; keep ports and defaults unchanged."


def balanced_end(text: str, start: int) -> int:
    depth = 0
    for index in range(start, len(text)):
        if text[index] == "(":
            depth += 1
        elif text[index] == ")":
            depth -= 1
            if depth == 0:
                semicolon = text.find(";", index)
                if semicolon < 0:
                    break
                return semicolon + 1
    raise ValueError("unterminated module header")


def matching_close(text: str, start: int) -> int:
    depth = 0
    for index in range(start, len(text)):
        if text[index] == "(":
            depth += 1
        elif text[index] == ")":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError("unterminated parenthesized list")


def split_top_level(value: str) -> list[str]:
    output: list[str] = []
    start = 0
    depth = 0
    for index, char in enumerate(value):
        if char in "([{" :
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == "," and depth == 0:
            output.append(value[start:index])
            start = index + 1
    output.append(value[start:])
    return output


def header_parts(header: str) -> tuple[list[str], list[str]]:
    # Locate the outer port list without confusing it with width expressions.
    name_end = re.search(r"\bmodule\s+[A-Za-z_]\w*", header).end()
    cursor = name_end
    if header[cursor:].lstrip().startswith("#"):
        hash_at = header.find("#", cursor)
        param_at = header.find("(", hash_at)
        param_end = matching_close(header, param_at)
        parameter_names = []
        for item in split_top_level(header[param_at + 1:param_end]):
            before_default = item.split("=", 1)[0]
            words = re.findall(r"[A-Za-z_]\w*", before_default)
            if words:
                parameter_names.append(words[-1])
        cursor = param_end + 1
    else:
        parameter_names = []
    port_at = header.find("(", cursor)
    port_end = matching_close(header, port_at)
    port_body = header[port_at + 1:port_end]
    port_names: list[str] = []
    for item in split_top_level(port_body):
        cleaned = re.sub(r"//.*", "", item).strip()
        words = re.findall(r"[A-Za-z_]\w*", cleaned)
        if words:
            port_names.append(words[-1])
    return parameter_names, port_names


def wrapper(header: str, legacy: str, canonical: str) -> str:
    parameters, ports = header_parts(header)
    legacy_header = re.sub(
        rf"\bmodule\s+{re.escape(canonical)}\b", f"module {legacy}", header, count=1
    )
    # A wrapper's outputs are driven by its canonical child instance and must be nets.
    legacy_header = re.sub(r"\boutput\s+(?:reg|logic)\b", "output wire", legacy_header)
    parameter_map = ""
    if parameters:
        parameter_map = " #(\n" + ",\n".join(
            f"    .{name}({name})" for name in parameters
        ) + "\n)"
    port_map = ",\n".join(f"    .{name}({name})" for name in ports)
    return (
        "\n\n// Deprecated v1.x compatibility wrapper; keep ports and defaults unchanged.\n"
        f"{legacy_header}\n"
        f"{canonical}{parameter_map} u_yifpga_compat (\n{port_map}\n);\n"
        "endmodule\n"
    )


def migrate_file(path: Path) -> tuple[str, str] | None:
    original = path.read_text(encoding="utf-8")
    if WRAPPER_MARKER in original:
        return None
    matches = list(MODULE_RE.finditer(original))
    if not matches:
        return None
    if len(matches) != 1:
        raise ValueError(f"{path}: expected one module, found {len(matches)}")
    match = matches[0]
    legacy = match.group(1)
    canonical = legacy.replace("openfpga_", "yifpga_", 1)
    header_end = balanced_end(original, original.find("(", match.end()))
    header = original[match.start():header_end]
    canonical_header = re.sub(
        rf"\bmodule\s+{re.escape(legacy)}\b", f"module {canonical}", header, count=1
    )
    migrated = original[:match.start()] + canonical_header + original[header_end:]
    migrated = migrated.rstrip() + wrapper(canonical_header, legacy, canonical)
    return original, migrated


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--repair-wrappers", action="store_true")
    args = parser.parse_args()
    if args.repair_wrappers:
        repaired = 0
        for directory in RTL_DIRS:
            for path in sorted((*directory.glob("*.v"), *directory.glob("*.sv"))):
                text = path.read_text(encoding="utf-8")
                if WRAPPER_MARKER not in text:
                    continue
                implementation, compatibility = text.split(WRAPPER_MARKER, 1)
                compatibility = re.sub(
                    r"\boutput\s+(?:reg|logic)\b", "output wire", compatibility
                )
                path.write_text(implementation + WRAPPER_MARKER + compatibility, encoding="utf-8")
                repaired += 1
        print(f"repaired {repaired} RTL wrappers")
        return 0
    changes: list[tuple[Path, str]] = []
    names: list[tuple[str, str]] = []
    for directory in RTL_DIRS:
        for path in sorted((*directory.glob("*.v"), *directory.glob("*.sv"))):
            result = migrate_file(path)
            if result is None:
                continue
            original, migrated = result
            legacy = MODULE_RE.search(original).group(1)
            canonical = legacy.replace("openfpga_", "yifpga_", 1)
            changes.append((path, migrated))
            names.append((legacy, canonical))
    if args.check:
        print(f"would migrate {len(changes)} RTL modules")
        return 1 if changes else 0
    for path, migrated in changes:
        path.write_text(migrated, encoding="utf-8")
    # Internal RTL instantiations use canonical names; wrapper declarations stay legacy.
    for directory in (ROOT / "rtl/yifpga_debug", ROOT / "rtl/vendor/xilinx", ROOT / "rtl/board"):
        for path in sorted((*directory.glob("*.v"), *directory.glob("*.sv"))):
            text = path.read_text(encoding="utf-8")
            for legacy, canonical in names:
                text = re.sub(
                    rf"(?m)^(\s*){re.escape(legacy)}(\s*(?:#\s*\(|[A-Za-z_]\w*\s*\())",
                    rf"\1{canonical}\2",
                    text,
                )
            path.write_text(text, encoding="utf-8")
    print(f"migrated {len(changes)} RTL modules")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
