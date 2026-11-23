# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Compile Compasless SROT ESC firmware from src/ using ASEM-51."""
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import argparse
import json
import subprocess
import zipfile
from assembler import assemble
from bootstrap import ARCHIVE_SHA256, ensure_assembler
from srot import ROOT, assets, image_digest, image_info, parse_hex, save_json, select_target, sha256

def build_plan(target):
    filename, record = select_target(target)
    defines = {
        "ESCNO": 27 if record["layout"] == "OA" else ord(record["layout"]) - 64,
        "MCU_TYPE": {"H":1, "X":2}[record["mcu"]],
        "DEADTIME": record["deadtime"],
        "PWM_FREQ": {24:0, 48:1, 96:2}[record["pwm_khz"]],
    }
    return filename, record, defines

def verify_image(data, record):
    memory = parse_hex(data)
    eeprom = 0x3000 if record["mcu"] == "X" else 0x1A00
    def read(address, length):
        return bytes(memory[address + offset] for offset in range(length))
    if read(eeprom, 3) != bytes([0, 3, 208]):
        raise ValueError("Firmware revision or EEPROM layout differs")
    if read(eeprom + 11, 1) != b"\x03":
        raise ValueError("Reversible thruster default is missing")
    if read(eeprom + 0x60, 16) != b"Compasless (.0) ":
        raise ValueError("Compasless runtime identity is missing")
    if b"Bluejay" in bytes(memory[address] for address in sorted(memory)):
        raise ValueError("Unexpected upstream runtime identity")
    expected = "#" + record["layout"] + "_" + record["mcu"] + "_" + f'{record["deadtime"]:02d}' + "#"
    if read(eeprom + 0x40, 16).decode("ascii").strip() != expected:
        raise ValueError("Compiled hardware-layout tag does not match selected target")
    # An independent baseline fingerprint catches compiler and firmware changes
    # outside this release's declared identity, version and direction changes.
    baseline = json.loads((ROOT / "tests/fixtures/compiler-baseline.json").read_text())[record["target"]]
    for address, expected in ((baseline["direction_address"], 3), (baseline["revision_address"], 3)):
        if memory[address] != expected:
            raise ValueError("Unexpected runtime default/revision instruction")
    restored = memory.copy()
    restored[eeprom + 1] = 21
    restored[eeprom + 11] = 1
    restored[baseline["direction_address"]] = 1
    restored[baseline["revision_address"]] = 21
    for index, value in enumerate(b"Bluejay (.0)    "):
        restored[eeprom + 0x60 + index] = value
    if image_digest(restored) != baseline["image_sha256"]:
        raise ValueError("Flash changed beyond the declared firmware modifications")
    return image_info(data)

def compile_target(target, executable, output):
    filename, record, defines = build_plan(target)
    result = assemble(ROOT / "src", "SrotEsc.asm", defines, executable, output / "work" / target)
    data = result.read_bytes()
    info = verify_image(data, record)
    destination = output / "hex" / filename
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    return {"filename":filename, **record, "sha256":sha256(data), **info}

def package(output, records):
    version = json.loads((ROOT / "project.json").read_text())["version"]
    checksums = "\n".join(item["sha256"] + "  hex/" + item["filename"] for item in records) + "\n"
    (output / "SHA256SUMS").write_text(checksums, encoding="ascii", newline="\n")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=normal"], cwd=ROOT, text=True).strip())
    source = {p.relative_to(ROOT).as_posix():sha256(p.read_bytes()) for p in sorted((ROOT / "src").rglob("*")) if p.is_file()}
    tool_sources = {p.relative_to(ROOT).as_posix():sha256(p.read_bytes()) for p in sorted((ROOT / "tools").glob("*.py"))}
    save_json(output / "build-manifest.json", {
        "firmware":"Compasless SROT ESC", "version":version, "source_built":True,
        "hardware_qualified":False, "source_commit":commit, "source_dirty":dirty,
        "source_files":source, "build_tools":tool_sources,
        "assembler":"ASEM-51 1.3", "assembler_archive_sha256":ARCHIVE_SHA256, "targets":records})
    archive = output / ("Compasless-SROT-ESC-v" + version + ".zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        for path in [output/"SHA256SUMS", output/"build-manifest.json",
                     *[output/"hex"/item["filename"] for item in records]]:
            info = zipfile.ZipInfo(path.relative_to(output).as_posix(), date_time=(2026,11,24,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED
            bundle.writestr(info, path.read_bytes())
    print("Source-built firmware package: " + str(archive), flush=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--target", help="Exact layout_MCU_deadtime_PWM, e.g. A_H_5_48")
    selection.add_argument("--all", action="store_true")
    selection.add_argument("--list", action="store_true")
    parser.add_argument("--assembler", type=Path, help="Optional original ASEMW.EXE path")
    parser.add_argument("--output", type=Path, default=ROOT/"build")
    parser.add_argument("--jobs", type=int, default=4)
    args = parser.parse_args()
    if args.list:
        print("\n".join(record["target"] for record in assets().values()))
        return
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    targets = [args.target] if args.target else [record["target"] for record in assets().values()]
    for target in targets:
        select_target(target)
    executable = args.assembler or ensure_assembler()
    if not executable.is_file():
        parser.error("ASEMW.EXE not found")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    records=[]
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures={pool.submit(compile_target, target, executable, output):target for target in targets}
        for future in as_completed(futures):
            records.append(future.result())
            if len(records) % 100 == 0:
                print(f"Built and checked {len(records)}/{len(targets)} targets", flush=True)
    package(output, sorted(records, key=lambda record:record["filename"]))

if __name__ == "__main__":
    main()
