# SROT ESC Firmware

**The ESC firmware component of the Compasless SROT AUV/ROV suite.**

Compasless maintains this repository's release packaging, target verification, build
tooling and underwater-thruster integration notes. The firmware engine is
**[Bluejay](https://github.com/bird-sanctuary/bluejay) v0.21.0**, derived upstream
from BLHeli_S. Its source, copyright notices, defaults, identifiers and executable
behavior are preserved.

| Baseline | Status |
|---|---|
| Upstream release | [Bluejay v0.21.0](https://github.com/bird-sanctuary/bluejay/releases/tag/v0.21.0) |
| Pinned source | `93bf3e1a081ee87357aface06e535480dcc191d8` |
| Hardware variants | 1,008 H/BB21 and X/BB51 layout/deadtime/PWM combinations |
| Compasless firmware changes | None in the reference baseline |
| Source rebuild | Requires locally licensed Keil AX51/LX51/Ohx51 tools |
| Thruster performance / hardware qualification | Not measured or established by this package |

**3D mode qualification is outstanding.** Upstream v0.21.0 reports performance
issues in forward/reverse 3D mode and advises against using that mode. SROT's
existing propulsion path uses forward/reverse operation, so these reference
artifacts are not a qualified replacement for an installed thruster configuration.
See [compatibility and known issues](docs/COMPATIBILITY.md).

## Download and select firmware

The [reference release](https://github.com/Compasless/srot-esc-firmware/releases/tag/v0.1.0-reference)
contains the unchanged upstream HEX files, SHA-256 checksums, license and provenance.
The archive is a Compasless distribution of upstream binaries, not evidence of a
fresh source compilation or improved thrust.

Read the actual ESC's layout, MCU and deadtime using
[srot-esc-flasher](https://github.com/Compasless/srot-esc-flasher). Then select the
exact matching filename. The build tools provide no default hardware target.
The examples below use `A_H_5_48` only to demonstrate the commands.

```console
python tools/verify_source.py
python tools/reference.py list
python tools/reference.py fetch --target A_H_5_48
python tools/reference.py verify --target A_H_5_48 --file .cache/reference/A_H_5_48_v0.21.0.hex
```

The original filenames and internal Bluejay identifiers remain intact so the
existing configurator and SROT flasher can recognize the correct hardware.
Do not override the detected MCU layout. See [target selection](docs/TARGETS.md).

## Build from source

Use a licensed Keil C51 installation. Python 3.11 or newer is sufficient for the
Compasless tooling; no Python packages are required.

```powershell
$env:KEIL_C51_BIN = 'C:\Keil_v5\C51\BIN'
python tools/build.py --target A_H_5_48
```

This assembles an isolated source copy, links it and generates Intel HEX. A build
is accepted only if its flash bytes equal the matching upstream reference.
On Linux, add `--wine` and provide the licensed Windows tool directory.
See [build and verification](docs/BUILD.md).

## The four connected repositories

| Repository | Responsibility |
|---|---|
| [srot-control-board](https://github.com/Compasless/srot-control-board) | Hengla vehicle control and RP2350 DShot/RPM co-processor |
| [srot-ground-station](https://github.com/Compasless/srot-ground-station) | Bondor operator tools and LoRa bridge |
| [srot-esc-flasher](https://github.com/Compasless/srot-esc-flasher) | ESP32 bench tool that reads, configures and flashes ESCs |
| **srot-esc-firmware** | Bluejay reference source, ESC images, build verification and qualification records |

Open [srot.code-workspace](srot.code-workspace) to work with the four sibling
checkouts. [WORKSPACE.md](WORKSPACE.md) describes their maintenance boundary.
Adding this fourth component makes no changes to the other three repositories.

## Repository layout

```text
vendor/bluejay/              unchanged upstream release source, Makefile and license
provenance/                 file hashes and release asset identity
tools/                      Compasless build, selection, integrity and workspace tools
tests/                      integrity and target-selection checks
docs/                       build, compatibility, targets and maintenance notes
upstream.lock.json          exact release and source commit
workspace.json              the four SROT repositories
```

## Credit and license

Bluejay and BLHeli_S authors retain their source copyright and authorship. All
upstream notices are preserved in [vendor/bluejay](vendor/bluejay); the original
README is [available here](vendor/bluejay/README.md). See [UPSTREAM.md](UPSTREAM.md)
for provenance and the scope of Compasless contributions.

Firmware and this repository's integration tooling are distributed under
**GPL-3.0-or-later**; see [COPYING](COPYING). Keil's proprietary toolchain is not
included and must be licensed separately.
