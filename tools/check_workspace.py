# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Inspect the five sibling repositories without changing them."""
import argparse
import json
import subprocess
from srot import ROOT


def git(path, *arguments):
    return subprocess.run(["git", "-C", str(path), *arguments],
                          capture_output=True, text=True, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-all", action="store_true")
    args = parser.parse_args()
    entries = json.loads((ROOT / "workspace.json").read_text())["repositories"]
    report = []
    failures = []
    for entry in entries:
        path = (ROOT / entry["path"]).resolve()
        if not (path / ".git").exists():
            report.append({"repository":entry["name"], "present":False})
            if args.require_all:
                failures.append("Missing repository: " + entry["name"])
            continue
        origin = git(path, "remote", "get-url", "origin")
        head = git(path, "rev-parse", "HEAD")
        branch = git(path, "branch", "--show-current")
        status = git(path, "status", "--porcelain")
        result = {
            "repository":entry["name"], "present":True,
            "origin":origin.stdout.strip(), "head":head.stdout.strip(),
            "branch":branch.stdout.strip(), "working_tree_clean":not status.stdout.strip(),
        }
        if any(x.returncode for x in (origin,head,branch,status)):
            failures.append("Could not read Git state: " + entry["name"])
        elif result["origin"].removesuffix(".git") != entry["url"].removesuffix(".git"):
            failures.append("Unexpected origin: " + entry["name"])
        report.append(result)
    print(json.dumps(report, indent=2))
    if failures:
        raise SystemExit("\n".join(failures))


if __name__ == "__main__":
    main()
