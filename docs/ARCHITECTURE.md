# Active Compasless ESC firmware

The compiler entry point is `src/SrotEsc.asm`. The build copies `src/` into its
isolated work directory and compiles that entry point. The vendored Bluejay copy is
the reference used by verification; it is not the build input.

## Composition and control flow

The entry point includes target setup, persistent defaults, RAM state, EEPROM data
and ordered services. It then includes reset/input initialization, DShot-rate
detection, arming, motor startup, the six-step run/reversal loop, stop handling and
the reset/bootloader tail.

The split preserves the exact assembly sequence. No jump, call, interrupt, table
or state allocation is moved relative to the original sequence. Fixed address
segments, gate-drive settings and default values remain unchanged.

Application and bootloader labels use the `Srot_` namespace. The source map in
`provenance/refactor-map.json` records all 535 name substitutions, original-to-active
file paths and the main-file split. MCU register names, macro instructions,
command-line target selectors and configurator data remain compatible.

## Verification boundary

`tools/verify_firmware.py` expands both include graphs and reverses the label map.
It compares every assembly statement from all conditional branches. Literal
strings, instruction operands, macro definitions, RAM declarations, EEPROM data,
conditional expressions and ordering are checked. Changes to comments/formatting
are allowed; runtime changes are rejected.

This provides a source equivalence check across the 1,008 published H/X target
configurations. It is not a claim that 1,008 new binaries have been compiled.
A real compiled build must separately match the selected upstream flash image.
The build wrapper implements that additional check when licensed Keil tools are
available.

## Preserved interfaces

- DShot command encoding and RPM/extended telemetry.
- Forward/reverse configuration and neutral behavior.
- MCU/layout selection, FET polarity and gate deadtime.
- EEPROM ordering, firmware identity, settings and melody data.
- Reset addresses, bootloader protocol and flash locks.

Keeping these interfaces preserves the existing SROT board/flasher integration.
The inherited upstream 3D-mode issue is still present and requires separate work
before a claim of improved AUV behavior or hardware qualification.
