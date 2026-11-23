# Selecting the correct ESC target

Read the ESC through the SROT flasher's diagnostic mode. Its layout string and
MCU signature determine the hardware family. Keep gate-drive deadtime appropriate
to that exact ESC. Do not infer a layout from motor type or from another ESC's file.

The upstream filename format is:

```text
LAYOUT_MCU_DEADTIME_PWM_v0.21.0.hex
Example only: A_H_5_48_v0.21.0.hex
```

- `H`: the release's EFM8BB21/BB2 targets.
- `X`: the release's EFM8BB51 targets.
- `L`/BB10 is not present in the pinned v0.21.0 release and is rejected here.
- The manifest contains exactly the 1,008 published combinations.
- No target, PWM frequency or deadtime is selected automatically.

`tools/reference.py list` reads the locked manifest rather than synthesizing
guessed targets. `fetch` verifies the original file's size and SHA-256 before
returning it. `verify` additionally checks Intel HEX records, checksums, EOF and
overlapping addresses. A successful check establishes file identity, not hardware
compatibility; the physical target match is still required.

Branding is in this repository's documentation and distribution. Original HEX
names and Bluejay internal identifiers are preserved for configurator compatibility.
