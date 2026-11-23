# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Download the complete, unchanged ASEM-51 distribution from its author's site."""
from pathlib import Path
from urllib.request import urlopen
import os
import zipfile
from srot import ROOT, sha256

URL = "https://plit.de/asem-51/asem5113.zip"
ARCHIVE_SHA256 = "2ae4bd6cd66e568951e479f62da8934771d963fccb8630cf2929b5dfaa7fc6a9"

def ensure_assembler(cache=None):
    if os.name != "nt":
        raise RuntimeError("The verified build uses native Windows ASEMW.EXE; run on Windows.")
    cache = Path(cache or ROOT / ".cache/asem51")
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / "asem5113.zip"
    if not archive.exists():
        with urlopen(URL, timeout=90) as response:
            data = response.read()
        if sha256(data) != ARCHIVE_SHA256:
            raise ValueError("Assembler download SHA-256 mismatch")
        archive.write_bytes(data)
    if sha256(archive.read_bytes()) != ARCHIVE_SHA256:
        raise ValueError("Cached assembler archive SHA-256 mismatch")
    # Extract the entire original distribution, including its license.
    with zipfile.ZipFile(archive) as package:
        for name in package.namelist():
            destination = (cache / name).resolve()
            if not destination.is_relative_to(cache.resolve()):
                raise ValueError("Unsafe archive path")
        package.extractall(cache)
        executable = next(path for path in cache.rglob("*") if path.name.upper() == "ASEMW.EXE")
        member = next(name for name in package.namelist() if Path(name).name.upper() == "ASEMW.EXE")
        if executable.read_bytes() != package.read(member):
            raise ValueError("Assembler executable differs from original archive")
    return executable
