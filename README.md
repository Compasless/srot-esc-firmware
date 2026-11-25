# Compasless SROT ESC

ESC firmware maintained by **Compasless** for reversible AUV/ROV thruster development.
The source, firmware identity and compiled release are maintained here.

[Download firmware v0.4.0](https://github.com/Compasless/srot-esc-firmware/releases/tag/v0.4.0) · [Build instructions](docs/BUILD.md) · [Hardware compatibility](docs/COMPATIBILITY.md)

## Firmware

- Compasless runtime identity and version 0.4.0.
- **3D is the only motor operating mode**; forward/reverse thrust uses the fixed throttle halves.
- Old saved direction settings normalize to 3D on load, decode and save.
- One-way, reversed-mode and turtle-mode selection handlers are removed.
- Legacy direction/mode commands 7, 8, 9, 10, 20 and 21 are ignored.
- DShot input and bidirectional DShot RPM telemetry inherited from the base.
- Modular control, arming, startup, commutation, protection and hardware drivers in `src/`.
- Separate HEX files for 1,008 layout/MCU/deadtime/PWM combinations.

This is a **development prerelease**. It has been compiled and checked, but has not
been tested on an ESC or underwater. No measured thrust, efficiency or reversal
improvement is claimed. The base release reports 3D-mode performance problems;
that issue remains unresolved. See [compatibility and qualification](docs/COMPATIBILITY.md).

## ESC Configurator

[Open the Compasless configurator](https://compasless-srot-esc-configurator.plainlatte33.chatgpt.site)
for the existing SROT USB flasher: scan four ESC channels, flash a matching image,
and read or edit Compasless settings with 3D fixed.
[Source and local setup](configurator/README.md).

For the public site, download and extract the release ZIP, choose **Flash →
Select File Locally**, and select the exact matching HEX. Keep **Ignore MCU layout**
and **Migrate settings** unchecked. Stock local flashing/reflashing is software-tested
for all 1,008 targets; its settings UI does not recognize Compasless layout 208.
Use the Compasless interface for settings.

## Build

On Windows with Python 3.11 or later:

```powershell
python tools/build.py --list
python tools/build.py --target A_H_5_48
python tools/build.py --all
```

The target shown is an example: use the exact identity reported by your ESC.
A 4-in-1 board has four ESC channels; it does not identify their firmware target.
The build downloads the original free ASEM-51 distribution with a pinned SHA-256.
No licensed Keil installation is required.

The release ZIP contains separate `SROT_<target>_v0.4.0.hex` images, checksums and
a source/build manifest. Code starts at [src/SrotEsc.asm](src/SrotEsc.asm).
[WORKSPACE.md](WORKSPACE.md) explains how the four independent SROT repositories
are managed from one local workbench.

## Credits and license

Built on [Bluejay v0.21.0](https://github.com/bird-sanctuary/bluejay/tree/93bf3e1a081ee87357aface06e535480dcc191d8),
itself derived from [BLHeli_S](https://github.com/bitdump/BLHeli).
Compasless maintains this derivative's module architecture, namespaced source,
firmware identity, fixed 3D control policy and reproducible build tooling.

This is a derived firmware project, not an independently authored replacement for
the upstream motor-control algorithms. Original authors' notices are preserved;
see [NOTICE](NOTICE) and [COPYING](COPYING) for GPL-3.0-or-later terms.
