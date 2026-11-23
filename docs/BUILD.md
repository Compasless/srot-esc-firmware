# Build and verification

The firmware snapshot uses Keil AX51, LX51 and Ohx51, as specified by the unchanged
upstream Makefile. The reference download package contains upstream release
binaries; it does not claim they were freshly assembled in this workspace.

## Requirements

- Python 3.11 or newer.
- An appropriately licensed Keil C51 toolchain containing all three executables.
- Native Windows, or Wine on Linux.
- Network access to fetch a hash-locked upstream reference, unless cached.

Keil's evaluation tools have a 2 KB object-code limit. The reference firmware is
larger than that limit. Use a licensed toolchain; Silicon Labs provides a
[free licensing route for its 8-bit MCUs](https://www.silabs.com/software-and-tools/keil-pk51).
Toolchain downloads, licenses and activation remain separate from this GPL source.

## Procedure

1. Obtain the layout/MCU/deadtime from the actual ESC through the existing flasher.
2. Select an exact supported target with `python tools/reference.py list`.
3. Run `python tools/verify_source.py`.
4. Set `KEIL_C51_BIN` or pass `--keil-bin`.
5. Run `python tools/build.py --target YOUR_TARGET`.

Use `--dry-run` to inspect the target's defines and commands without executing tools.
The wrapper copies source into a new build work directory, assembles serially,
retains logs and compares every generated flash byte with the upstream target.
The expected linker warning count is checked against the upstream build rule.
No compiler is silently downloaded and no hardware is flashed.

The output is written under `build/hex`. A successful build report records
`source_rebuilt=true` and `flash_bytes_match_upstream=true`. A dry run or upstream
download never sets those fields to true.

## Offline checks

```console
python tools/verify_source.py
python -m unittest discover -s tests -v
python tools/build.py --target A_H_5_48 --dry-run
```

The example target demonstrates syntax. It does not identify your ESC.
Local tests establish source/artifact integrity, not motor performance or safety.
