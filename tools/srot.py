# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Hardware-target selection and Intel HEX integrity for Compasless SROT ESC."""
from pathlib import Path
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[1]

def sha256(data):
    return hashlib.sha256(data).hexdigest()

def save_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")

def assets():
    config = json.loads((ROOT / "targets.json").read_text())
    version = json.loads((ROOT / "project.json").read_text())["version"]
    result = {}
    for mcu, layouts in config["families"].items():
        for layout in layouts:
            for deadtime in config["deadtime"]:
                for pwm in config["pwm_khz"]:
                    target = f"{layout}_{mcu}_{deadtime}_{pwm}"
                    filename = f"SROT_{target}_v{version}.hex"
                    result[filename] = dict(target=target, layout=layout, mcu=mcu, deadtime=deadtime, pwm_khz=pwm)
    return result

def select_target(target):
    for filename, record in assets().items():
        if target in (record["target"], filename):
            return filename, record
    raise ValueError(f"Unsupported target {target!r}. Use python tools/build.py --list. Match the detected layout, MCU and deadtime.")

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
