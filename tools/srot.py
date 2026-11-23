# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Source and firmware integrity helpers for the SROT Bluejay reference package."""
from pathlib import Path
from urllib.request import Request, urlopen
import hashlib
import json
import struct
import time

ROOT = Path(__file__).resolve().parents[1]


def read_json(path):
    return Path(path).read_text(encoding="utf-8")


def lock():
    return json.loads(read_json(ROOT / "upstream.lock.json"))


def assets():
    return json.loads(read_json(ROOT / "provenance/release-assets.json"))


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def save_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")


def verify_source():
    manifest = json.loads(read_json(ROOT / "provenance/source-manifest.json"))
    source = ROOT / lock()["source_directory"]
    found = {p.relative_to(source).as_posix() for p in source.rglob("*") if p.is_file()}
    if found != set(manifest):
        raise ValueError(f"Upstream file set changed: missing={set(manifest)-found}, extra={found-set(manifest)}")
    for relative, record in manifest.items():
        data = (source / relative).read_bytes()
        if len(data) != record["size"] or sha256(data) != record["sha256"]:
            raise ValueError("Upstream source differs from the pinned release: " + relative)
    if (ROOT / "COPYING").read_bytes() != (source / "COPYING").read_bytes():
        raise ValueError("Root COPYING differs from upstream license")
    return len(manifest)


def parse_hex(data):
    """Read Intel HEX with length, checksum, EOF and overlap validation."""
    if isinstance(data, bytes):
        data = data.decode("ascii")
    memory = {}
    base = 0
    ended = False
    for line_no, line in enumerate(data.splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        if ended:
            raise ValueError(f"Record after EOF at line {line_no}")
        if not line.startswith(":"):
            raise ValueError(f"Missing Intel HEX marker at line {line_no}")
        encoded = line[1:]
        if not encoded or len(encoded) % 2 or any(c not in "0123456789abcdefABCDEF" for c in encoded):
            raise ValueError(f"Invalid Intel HEX characters at line {line_no}")
        record = bytes.fromhex(encoded)
        if len(record) < 5 or len(record) != record[0] + 5:
            raise ValueError(f"Record length mismatch at line {line_no}")
        if sum(record) & 255:
            raise ValueError(f"Checksum mismatch at line {line_no}")
        size, high, low, kind = record[:4]
        address = (high << 8) | low
        payload = record[4:-1]
        if kind == 0:
            if address + size > 65536:
                raise ValueError(f"Record crosses address boundary at line {line_no}")
            for index, value in enumerate(payload):
                absolute = base + address + index
                if absolute in memory and memory[absolute] != value:
                    raise ValueError(f"Conflicting data at address {absolute:#x}")
                memory[absolute] = value
        elif kind == 1:
            if size or address:
                raise ValueError("Malformed EOF")
            ended = True
        elif kind in (2, 4):
            if size != 2 or address:
                raise ValueError("Malformed extended address")
            base = int.from_bytes(payload, "big") << (4 if kind == 2 else 16)
        elif kind in (3, 5):
            if size != 4 or address:
                raise ValueError("Malformed start address")
        else:
            raise ValueError(f"Unsupported Intel HEX record type: {kind}")
    if not ended or not memory:
        raise ValueError("Firmware must contain data and a final EOF record")
    return memory


def image_digest(memory):
    return sha256(b"".join(struct.pack(">IB", address, value)
                           for address, value in sorted(memory.items())))


def image_info(data):
    memory = parse_hex(data)
    return {
        "flash_bytes": len(memory),
        "first_address": min(memory),
        "last_address": max(memory),
        "image_sha256": image_digest(memory),
    }


def select_target(target):
    for filename, record in assets().items():
        if target == record["target"] or target == filename:
            return filename, record
    raise ValueError(
        f"Unsupported target {target!r}. Use tools/reference.py list. "
        "Read the actual ESC layout, MCU and deadtime; do not guess or override MCU layout."
    )


def verify_reference(path, record):
    data = Path(path).read_bytes()
    if len(data) != record["size"] or sha256(data) != record["sha256"]:
        raise ValueError("Reference firmware SHA-256/size mismatch: " + str(path))
    info = image_info(data)
    if record.get("image_sha256") and info["image_sha256"] != record["image_sha256"]:
        raise ValueError("Reference flash image digest mismatch: " + str(path))
    return info


def fetch_reference(target, directory):
    filename, record = select_target(target)
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / filename
    if path.exists():
        verify_reference(path, record)
        return path
    for attempt in range(3):
        try:
            request = Request(record["url"], headers={"User-Agent":"Compasless-SROT-reference/0.1"})
            with urlopen(request, timeout=45) as response:
                data = response.read()
            if len(data) != record["size"] or sha256(data) != record["sha256"]:
                raise ValueError("Downloaded upstream asset does not match release manifest")
            image_info(data)
            temporary = path.with_suffix(".hex.partial")
            temporary.write_bytes(data)
            temporary.replace(path)
            return path
        except (OSError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(attempt + 1)
