# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Manage five independent Git repositories from one local workbench."""
from pathlib import Path
import argparse
import json
import subprocess


def git(path, *arguments):
    result = subprocess.run(["git", "-C", str(path), *arguments],
                            capture_output=True, text=True, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path,
                        default=Path(__file__).resolve().parents[1] / "workspace.json")
    parser.add_argument("command", choices=["status", "fetch", "pull", "push"])
    parser.add_argument("--repo", help="A single repository name; required for push")
    options = parser.parse_args()
    manifest = options.workspace.resolve()
    entries = json.loads(manifest.read_text(encoding="utf-8"))["repositories"]
    if options.repo:
        entries = [item for item in entries if item["name"] == options.repo]
        if not entries:
            parser.error("Repository is not registered in this workspace")
    if options.command == "push" and not options.repo:
        parser.error("Push requires --repo NAME; repositories are published independently")
    targets = []
    for item in entries:
        path = (manifest.parent / item["path"]).resolve()
        origin = git(path, "remote", "get-url", "origin")
        if origin.removesuffix(".git") != item["url"].removesuffix(".git"):
            raise RuntimeError("Unexpected origin for " + item["name"] + ": " + origin)
        dirty = git(path, "status", "--porcelain")
        if options.command in {"pull","push"} and dirty:
            raise RuntimeError("Commit or save local changes before " + options.command + ": " + item["name"])
        targets.append((item,path))
    report = []
    for item,path in targets:
        if options.command == "fetch":
            git(path, "fetch", "--prune", "origin")
        elif options.command == "pull":
            git(path, "pull", "--ff-only")
        elif options.command == "push":
            git(path, "push")
        state = git(path, "status", "--short", "--branch").splitlines()
        report.append({
            "repository":item["name"], "path":str(path),
            "head":git(path, "rev-parse", "--short", "HEAD"),
            "status":state[0], "changed_paths":len(state)-1,
            "action":options.command,
        })
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
