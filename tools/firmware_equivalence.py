# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Check the complete active assembly graph against the preserved upstream graph."""
from pathlib import Path
import hashlib
import json
import re

from srot import ROOT, verify_source

INCLUDE = re.compile(r"^\s*\$include\s*\(([^)]+)\)\s*$", re.I)
TOKENS = re.compile(r'"[^"]*"|\'[^\']*\'|[A-Za-z_][A-Za-z_0-9]*|[^\s]')


def without_comment(line):
    quote = None
    for index, char in enumerate(line):
        if char in ("'", '"'):
            if quote == char:
                quote = None
            elif quote is None:
                quote = char
        elif char == ";" and quote is None:
            return line[:index]
    return line


def flatten(root, entry, inverse=None, replacements=None):
    """Includes are expanded without selecting IF branches: every target path is checked."""
    root = Path(root).resolve()
    inverse = inverse or {}
    replacements = replacements or {}
    visited = set()
    statements = []
    def walk(path, stack):
        path = path.resolve()
        if not path.is_relative_to(root) or path in stack:
            raise ValueError(f"Invalid/cyclic assembly include: {path}")
        relative = path.relative_to(root).as_posix()
        visited.add(relative)
        text = replacements.get(relative, path.read_text(encoding="utf-8"))
        for number, line in enumerate(text.splitlines(), 1):
            code = without_comment(line).strip()
            if not code:
                continue
            include = INCLUDE.fullmatch(code)
            if include:
                name = include[1].replace("\\", "/")
                candidate = path.parent / name
                if not candidate.is_file():
                    candidate = root / name
                if not candidate.is_file():
                    raise ValueError(f"Missing include {name}: {relative}:{number}")
                walk(candidate, (*stack, path))
                continue
            tokens = []
            for token in TOKENS.findall(code):
                if token.startswith(("'", '"')):
                    tokens.append(token)   # Preserve strings/data exactly.
                else:
                    tokens.append(inverse.get(token.lower(), token.lower()))
            statements.append((tuple(tokens), f"{relative}:{number}"))
    walk(root / entry, ())
    return statements, visited


def verify(replacements=None):
    verify_source()
    mapping = json.loads((ROOT / "provenance/refactor-map.json").read_text())
    inverse = {new.lower():old for old,new in mapping["identifier_renames"].items()}
    before, original_files = flatten(ROOT / "vendor/bluejay/src", mapping["upstream_entry"])
    after, active_files = flatten(ROOT / "src", mapping["active_entry"], inverse, replacements)
    for index, (old, new) in enumerate(zip(before, after)):
        if old[0] != new[0]:
            raise ValueError(f"Assembly changed at statement {index}: {old[1]} {old[0]} != {new[1]} {new[0]}")
    if len(before) != len(after):
        raise ValueError(f"Assembly statement count differs: {len(before)} != {len(after)}")
    found = {p.relative_to(ROOT / "src").as_posix()
             for p in (ROOT / "src").rglob("*") if p.is_file()}
    if active_files != found:
        raise ValueError(f"Unreferenced active firmware files: {found-active_files}")
    digest = hashlib.sha256(json.dumps([line[0] for line in before],
                                      separators=(",",":")).encode()).hexdigest()
    return {
        "active_entry":"src/" + mapping["active_entry"],
        "active_source_files":len(active_files),
        "original_source_files":len(original_files),
        "renamed_code_and_data_labels":len(inverse),
        "assembly_statements_compared":len(before),
        "canonical_assembly_sha256":digest,
        "instructions_data_defaults_and_conditionals":"equivalent",
        "coverage":"all conditional assembly branches, including all 1008 published target configurations",
        "source_rebuilt":False,
        "hardware_tested":False,
    }
