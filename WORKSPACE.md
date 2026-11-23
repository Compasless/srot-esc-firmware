# Four-repository SROT workspace

Keep these sibling checkouts in the same parent directory:

```text
srot-repos/
  srot-control-board/
  srot-ground-station/
  srot-esc-flasher/
  srot-esc-firmware/
```

Open `srot-esc-firmware/srot.code-workspace` in VS Code. The workspace file lives in
this fourth repository and includes the other three through relative paths.

```console
python tools/check_workspace.py --require-all
```

The checker reads each repository's origin, branch, commit and working-tree
status. It does not fetch, switch branches, change files, commit, push or flash.
Each repository retains its own Git history, issues, pull requests and build tools.

The dependency chain is vehicle control → RP2350 DShot output → ESC firmware →
thruster. The ESC flasher installs the ESC firmware at the bench. Bondor monitors
and configures the vehicle; it is a parallel operator link.

This reference import changes only `srot-esc-firmware`. The existing three repos'
branches, runtime protocols, ESC settings and firmware behavior remain as they were.
