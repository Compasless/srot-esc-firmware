# SROT ESC — Compasless

**ESC firmware for the Compasless SROT AUV/ROV suite.**

The active firmware is in **[src/](src)**, starting at
**[src/SrotEsc.asm](src/SrotEsc.asm)**. This is a behavior-preserving firmware source
refactor derived from Bluejay v0.21.0: Compasless maintains the application
composition, module boundaries, namespaced routines/state and build integration.
The build compiles this active source tree.

Bluejay and BLHeli_S retain their original authorship and copyright. Their notices
are preserved, and an unchanged upstream snapshot remains in `vendor/bluejay` for
comparison. See [UPSTREAM.md](UPSTREAM.md) and [COPYING](COPYING).

## Firmware architecture

| Active source | Responsibility |
|---|---|
| [src/SrotEsc.asm](src/SrotEsc.asm) | Composition root and assembly order |
| [src/core](src/core) | Reset initialization, scheduler and instruction helpers |
| [src/control](src/control) | Arming, startup, commutation, timing, reversal and stopping |
| [src/protocol](src/protocol) | DShot acquisition, decoding and RPM/extended telemetry |
| [src/drivers](src/drivers) | FET power stage, beeper and LED routines |
| [src/hal](src/hal) | Target selection, register definitions and ESC pin layouts |
| [src/config](src/config) | Target constants, defaults and configuration decoding |
| [src/memory](src/memory) | Fixed RAM, stack and flash address maps |
| [src/storage](src/storage) | EEPROM image and settings persistence |
| [src/interrupts](src/interrupts) | Interrupt handlers and timer service |
| [src/boot](src/boot) | Reset jump and preserved serial bootloader |

The refactor reorganizes the former main source into 12 units and namespaces 535
code/data labels. There are 60 active source files. Instructions, literal data,
default settings, memory allocation and assembly order are preserved.
[Architecture and invariants](docs/ARCHITECTURE.md) explains the implementation.

## Verify and build

```console
python tools/verify_firmware.py
python -m unittest discover -s tests -v
python tools/build.py --target YOUR_LAYOUT_MCU_DEADTIME_PWM --keil-bin PATH_TO_C51_BIN
```

The source verifier expands every include and checks all conditional assembly
branches against the upstream baseline after reversing the documented label map.
It compares 13,644 assembly statements, including instruction order, constants and
data. Deliberate runtime edits cause verification to fail.

A fresh compilation uses licensed Keil AX51/LX51/Ohx51 tools and must additionally
match the selected upstream target's flash bytes. Source equivalence and a fresh
binary build are separate checks; no fresh compilation or water test is claimed
when it has not run. See [BUILD.md](docs/BUILD.md).

Select the exact layout, MCU, deadtime and PWM read from the actual ESC:

```console
python tools/reference.py list
python tools/reference.py fetch --target A_H_5_48
```

`A_H_5_48` is an example, not a recommended/default target. Original HEX filenames,
EEPROM identity and DShot behavior remain compatible with the existing flasher.
See [target selection](docs/TARGETS.md).

## Working here with four repositories

Your existing local workbench can expose all four independent Git checkouts under
`repos/`. Edits there change their actual checkouts; no file copying is required.
The central manager supports status, fetch-all, fast-forward pull and an explicit
single-repository push. See [WORKSPACE.md](WORKSPACE.md).

| Repository | Role |
|---|---|
| [srot-control-board](https://github.com/Compasless/srot-control-board) | Hengla vehicle control and RP2350 DShot/RPM co-processor |
| [srot-ground-station](https://github.com/Compasless/srot-ground-station) | Bondor and the LoRa bridge |
| [srot-esc-flasher](https://github.com/Compasless/srot-esc-flasher) | Bench flashing and ESC diagnostics |
| **srot-esc-firmware** | Active ESC firmware source and its build/verification tools |

The other three repositories' firmware is unchanged by this refactor.

## Compatibility and release status

The inherited [Bluejay v0.21.0 3D-mode limitation](https://github.com/bird-sanctuary/bluejay/releases/tag/v0.21.0)
still applies. Preserving behavior also preserves that limitation; no improved
thrust, efficiency or reversal performance is claimed.
[COMPATIBILITY.md](docs/COMPATIBILITY.md) and
[QUALIFICATION.md](docs/QUALIFICATION.md) record what requires hardware testing.

The earlier [v0.1.0 reference package](https://github.com/Compasless/srot-esc-firmware/releases/tag/v0.1.0-reference)
contains 1,008 upstream HEX files with checksums. Those remain identified as
upstream downloads. Source-refactor releases are distinct from fresh compiled
firmware and qualified hardware releases.
