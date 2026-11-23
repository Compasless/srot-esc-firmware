# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Build the active Compasless SROT ESC assembly source with licensed Keil tools."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import tempfile

from srot import ROOT, fetch_reference, image_info, lock, parse_hex, save_json, select_target, sha256, verify_source
from firmware_equivalence import verify as verify_firmware


def build_plan(target, keil_bin, wine=False):
    filename, record = select_target(target)
    layout = record["layout"]
    escno = 27 if layout == "OA" else ord(layout) - ord("A") + 1
    defines = {
        "ESCNO": escno, "MCU_TYPE": {"H":1, "X":2}[record["mcu"]],
        "DEADTIME": record["deadtime"], "PWM_FREQ": {24:0,48:1,96:2}[record["pwm_khz"]],
    }
    def exe(name):
        path = str(Path(keil_bin) / name)
        return ["wine", path] if wine else [path]
    return filename, record, [
        exe("AX51.exe") + ["src/SrotEsc.asm",
            *[f"DEFINE({key}={value})" for key,value in defines.items()],
            "OBJECT(firmware.OBJ)", "PRINT(firmware.LST)",
            "NOMOD51", "REGISTERBANK(0,1,2)", "NOLIST", "NOSYMBOLS"],
        exe("LX51.exe") + ["firmware.OBJ", "TO", "firmware.OMF"],
        exe("Ohx51.exe") + ["firmware.OMF", "HEXFILE(firmware.hex)"],
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", required=True, help="Exact target from tools/reference.py list")
    parser.add_argument("--keil-bin", default=os.environ.get("KEIL_C51_BIN"))
    parser.add_argument("--wine", action="store_true", help="Run licensed Windows tools through Wine")
    parser.add_argument("--output", type=Path, default=ROOT / "build")
    parser.add_argument("--reference-directory", type=Path, default=ROOT / ".cache/reference")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    verify_source()
    verify_firmware()
    filename, record, commands = build_plan(args.target, args.keil_bin or "<KEIL_C51_BIN>", args.wine)
    if args.dry_run:
        print(json.dumps({"target":record, "commands":commands, "source_rebuilt":False}, indent=2))
        return
    if not args.keil_bin:
        parser.error("Set --keil-bin or KEIL_C51_BIN to your licensed AX51/LX51/Ohx51 installation")
    for tool in ("AX51.exe", "LX51.exe", "Ohx51.exe"):
        if not (Path(args.keil_bin) / tool).is_file():
            parser.error(f"Tool not found: {Path(args.keil_bin) / tool}")
    args.output.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="srot-" + record["target"] + "-", dir=args.output))
    shutil.copytree(ROOT / "src", work / "src")
    # Serial execution matches upstream: AX51 shares temporary state across invocations.
    for index, command in enumerate(commands):
        result = subprocess.run(command, cwd=work, capture_output=True)
        (work / f"step-{index+1}.log").write_bytes(result.stdout + result.stderr)
        allowed = (0,1) if index == 1 else (0,)
        if result.returncode not in allowed:
            raise RuntimeError(f"Keil step {index+1} failed ({result.returncode}); see {work}")
        if index == 1:
            maps = list(work.glob("*.MAP"))
            if len(maps) != 1 or "1 WARNING" not in maps[0].read_text(errors="replace"):
                raise RuntimeError("Linker warning count differs from upstream's expected one warning")
    generated = work / "firmware.hex"
    if not generated.is_file():
        raise RuntimeError("Toolchain produced no Intel HEX output")
    reference = fetch_reference(args.target, args.reference_directory)
    rebuilt = generated.read_bytes()
    if parse_hex(rebuilt) != parse_hex(reference.read_bytes()):
        raise RuntimeError("Rebuilt flash bytes differ from the pinned upstream target; output is not verified")
    target = args.output / "hex" / filename
    target.parent.mkdir(exist_ok=True)
    target.write_bytes(rebuilt)
    save_json(args.output / (record["target"] + "-build.json"), {
        "target":record["target"], "upstream_commit":lock()["commit"],
        "source_rebuilt":True, "flash_bytes_match_upstream":True,
        "active_entry":"src/SrotEsc.asm",
        "file_sha256":sha256(rebuilt), **image_info(rebuilt),
        "hardware_tested":False, "commands":commands,
    })
    verify_source()
    verify_firmware()
    print("Source build verified against upstream flash bytes: " + str(target))


if __name__ == "__main__":
    main()
