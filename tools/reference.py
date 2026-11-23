# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""List, fetch, verify or package the unchanged upstream release firmware."""
from pathlib import Path
import argparse
import json
import zipfile

from srot import ROOT, assets, fetch_reference, lock, save_json, sha256, verify_reference, verify_source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list")
    get = sub.add_parser("fetch")
    get.add_argument("--target", required=True)
    get.add_argument("--directory", type=Path, default=ROOT / ".cache/reference")
    check = sub.add_parser("verify")
    check.add_argument("--target", required=True)
    check.add_argument("--file", type=Path, required=True)
    package = sub.add_parser("package")
    package.add_argument("--directory", type=Path, default=ROOT / ".cache/reference")
    package.add_argument("--output", type=Path, default=ROOT / "dist")
    options = parser.parse_args()
    verify_source()
    records = assets()
    if options.command == "list":
        for record in records.values():
            print(record["target"])
        return
    if options.command == "fetch":
        print(fetch_reference(options.target, options.directory))
        return
    if options.command == "verify":
        from srot import select_target
        _, record = select_target(options.target)
        print(json.dumps(verify_reference(options.file, record), indent=2))
        return
    options.output.mkdir(parents=True, exist_ok=True)
    checksums = []
    results = {}
    source = lock()
    archive_path = options.output / "srot-esc-firmware-0.1.0-reference-bluejay-v0.21.0.zip"
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        def put(name, data):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
        for index, (filename, record) in enumerate(records.items(), 1):
            path = fetch_reference(record["target"], options.directory)
            results[filename] = verify_reference(path, record)
            put("hex/" + filename, path.read_bytes())
            checksums.append(f"{record['sha256']}  hex/{filename}")
            if index % 100 == 0:
                print(f"Verified and packaged {index}/{len(records)} targets", flush=True)
        checksum_data = ("\n".join(checksums) + "\n").encode()
        put("SHA256SUMS", checksum_data)
        put("COPYING", (ROOT / "COPYING").read_bytes())
        put("upstream.lock.json", (ROOT / "upstream.lock.json").read_bytes())
        put("release-assets.json", (ROOT / "provenance/release-assets.json").read_bytes())
        put("README.txt", (
            "SROT ESC Firmware by Compasless — unchanged Bluejay v0.21.0 reference binaries.\n"
            "These files were downloaded from upstream, not freshly compiled by Compasless.\n"
            "No AUV performance improvement or hardware qualification is claimed.\n"
            "Upstream reports 3D mode performance issues and advises against its use in this version.\n"
            "Match layout, MCU and deadtime to the actual ESC. Do not override the detected layout.\n"
            "Source, license, build tools and qualification notes:\n"
            "https://github.com/Compasless/srot-esc-firmware/tree/v0.1.0-reference\n"
            "Upstream source: " + source["url"] + "/tree/" + source["commit"] + "\n"
        ).encode("utf-8"))
    (options.output / "SHA256SUMS").write_text(
        sha256(archive_path.read_bytes()) + "  " + archive_path.name + "\n", encoding="ascii", newline="\n")
    save_json(options.output / "verification.json", {
        "upstream_commit": source["commit"], "source_files_verified": verify_source(),
        "firmware_variants_verified": len(results), "reference_assets": results,
        "source_rebuilt": False, "hardware_tested": False,
        "artifact_origin": "unmodified upstream Bluejay release downloads",
    })
    print(archive_path)


if __name__ == "__main__":
    main()
