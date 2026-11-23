# Building SROT ESC

Use native Windows and Python 3.11 or later. The verified assembler is ASEM-51 1.3,
downloaded as the complete original distribution from its author's site.
Its ZIP SHA-256 is
`2ae4bd6cd66e568951e479f62da8934771d963fccb8630cf2929b5dfaa7fc6a9`.
The package and original license remain under `.cache/asem51/` and are not shipped
as Compasless source.

```powershell
python -m unittest discover -s tests -v
python tools/build.py --list
python tools/build.py --target A_H_5_48
python tools/build.py --all --output build/release
```

An original local executable can be selected with `--assembler PATH/ASEMW.EXE`.
The automatic download verifies the complete archive and executable.
Python checks also run on Linux; the native compilation path is verified on Windows.

The Compasless frontend expands includes, conditional branches, macro-local labels,
wide integer expressions and layout overrides. It emits standard MCS-51 assembly.
The assembler driver relaxes calls/jumps until addresses stabilize. Each target
has its own working directory. Compilation uses the active `src/` tree.

Outputs include:

- `hex/SROT_<layout>_<MCU>_<deadtime>_<PWM>_v0.3.0.hex`
- `SHA256SUMS` and `build-manifest.json`
- `Compasless-SROT-ESC-v0.3.0.zip`
- Per-target assembler input, listing and log under `work/`

The manifest records source commit, working-tree state, source/tool hashes,
toolchain pin, target configuration and flash/file SHA-256 values.
Release builds must use a clean committed tree.

Before changing identity/defaults, this toolchain compiled all 1,008 original
targets to byte-for-byte identical flash images. Every Compasless output is checked
against those independent baseline fingerprints after reversing only the declared
name, revision and direction changes. Gate-drive code, protection, bootloader,
layout tags and DShot behavior must still match. HEX length/checksum/EOF checks
also run; these are software checks, not motor or water testing.
