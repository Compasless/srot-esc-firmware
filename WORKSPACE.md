# Five-repository SROT workspace

Keep these sibling checkouts in the same parent directory:

```text
srot-repos/
  srot-control-board/
  srot-ground-station/
  srot-esc-flasher/
  srot-esc-firmware/
```

Open `srot-esc-firmware/srot.code-workspace` in VS Code. The workspace file lives in
this firmware repository and includes the other four through relative paths.

```console
python tools/check_workspace.py --require-all
```

The checker reads each repository's origin, branch, commit and working-tree
status. It does not fetch, switch branches, change files, commit, push or flash.
Each repository retains its own Git history, issues, pull requests and build tools.

The dependency chain is vehicle control → RP2350 DShot output → ESC firmware →
thruster. The ESC flasher installs the ESC firmware at the bench. Bondor monitors
and configures the vehicle; it is a parallel operator link.

The active firmware refactor changes only `srot-esc-firmware`. The existing three repos'
branches, runtime protocols, ESC settings and firmware behavior remain as they were.


## Existing combined local workbench

The local workbench can keep its existing root and expose the five canonical Git
checkouts through repos/ directory junctions. Its SROT.code-workspace and
srot-workspace.json point to those five live views.

From that workbench:

    python tools/srot_repos.py status
    python tools/srot_repos.py fetch
    python tools/srot_repos.py pull
    python tools/srot_repos.py push --repo srot-esc-firmware

The wrapper delegates to tools/manage_workspace.py in this repository. Fetch does
not replace working files; pull is fast-forward-only; push selects exactly one
clean checkout and never force-pushes. The older combined root files are retained.

To recreate the local links and helper files on Windows, run in PowerShell 7:

    ./tools/link_workbench.ps1 -WorkbenchRoot PATH_TO_YOUR_EXISTING_WORKBENCH

The setup tool preserves existing files and refuses mismatched paths/content.
It never moves, deletes or copies firmware between repositories.

The standalone browser interface is maintained in srot-esc-configurator.
