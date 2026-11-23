# Working here with four independent repositories

This folder is the local workbench. The four Git checkouts are visible inside
`repos/`, through directory junctions to the existing sibling `srot-repos` folder.
These are live views of the existing repositories, not duplicate copies.

Open `SROT.code-workspace`, or continue in this folder and expand `repos`.

| Edit here | GitHub repository |
|---|---|
| `repos/srot-control-board/` | `Compasless/srot-control-board` |
| `repos/srot-ground-station/` | `Compasless/srot-ground-station` |
| `repos/srot-esc-flasher/` | `Compasless/srot-esc-flasher` |
| `repos/srot-esc-firmware/src/` | `Compasless/srot-esc-firmware` |

From this folder:

```console
python tools/srot_repos.py status
python tools/srot_repos.py fetch
python tools/srot_repos.py pull
python tools/srot_repos.py push --repo srot-esc-firmware
```

Fetch updates all four remote-tracking histories without replacing working files.
Pull requires clean working trees and fast-forwards only. Push requires one
explicit repository and a clean working tree; commit changes in that checkout first.
The tool never copies one repository's files over another, force-pushes or flashes.

The older combined firmware/app files at this folder's root are preserved.
For changes intended for GitHub, edit the corresponding `repos/...` checkout.
The ESC firmware entry point is `repos/srot-esc-firmware/src/SrotEsc.asm`.
