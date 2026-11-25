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

- `hex/SROT_<layout>_<MCU>_<deadtime>_<PWM>_v0.4.0.hex`
- `SHA256SUMS` and `build-manifest.json`
- `Compasless-SROT-ESC-v0.4.0.zip`
- Per-target assembler input, listing and log under `work/`

The manifest records source commit, working-tree state, source/tool hashes,
toolchain pin, target configuration and flash/file SHA-256 values.
Release builds must use a clean committed tree.

The assembler was first validated by byte-identical builds of all 1,008 original
targets. Version 0.4.0 deliberately changes control behavior and instruction
addresses, so full upstream byte equality is no longer its validation criterion.

The build locks 49 untouched source modules to their previous release hashes,
including the hardware definitions, gate drivers, commutation timing and protection
implementation. A validation update is required to change those protected files.
Approved 0.4.0 image fingerprints detect later byte corruption or unexpected
compiler output, including changes to bootloader bytes.

For each compiled target, the build also executes the relevant machine-code paths
using a fail-closed subset of MCS-51 instructions. Checks cover legacy saved values,
mode commands, settings save, both throttle halves, timeout exit and reversal guards.
The fixture tests exhaust all 256 saved direction bytes, all 4,000 decoded throttle
values and legacy command/repeat combinations. Tests inject behavior changes to
confirm that the execution checks reject them independently of file fingerprints.

The checker is a software model of the exercised instruction subset. It does not
simulate power electronics, instruction timing, a motor or the physical input link.
Hardware and water qualification remain pending.
