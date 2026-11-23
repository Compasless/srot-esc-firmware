# AGENTS.md — srot-esc-firmware

This is the fourth Compasless SROT repository. Read README.md, UPSTREAM.md,
upstream.lock.json and docs/COMPATIBILITY.md before changing its artifacts.

The user requires the three existing repositories to remain untouched during this
baseline import. All new source packaging, tools, docs and workspace files belong
here. Do not edit, commit, flash or push changes to the siblings as part of this task.

## Firmware provenance

- Keep vendor/bluejay byte-identical to the pinned upstream release. Preserve all
  copyright notices, authorship and COPYING. Run tools/verify_source.py.
- Record a deliberate upstream update with its tag, commit, source manifest and
  binary manifest together. Never replace a locked hash to disguise a local edit.
- Compasless owns this integration layer; Bluejay remains the upstream engine.
  State measured behavior and performance evidence accurately.
- Distinguish downloaded upstream binaries, source-rebuilt bytes and hardware-
  qualified artifacts. A reference package is not a water-tested optimization.
- Retain the upstream 3D-mode warning until an actual validated fix supersedes it.

## Hardware and build rules

- Match the exact layout, MCU, deadtime and PWM target. No guessed default target.
- Never bypass the configurator's hardware-layout checks.
- Never change gate-drive polarity, deadtime, EEPROM layout, DShot encoding,
  bootloader identity or motor defaults as a branding exercise.
- Never flash hardware from a test, CI workflow or packaging command.
- Keep Keil licensed separately. Do not publish tool binaries, keys or license files.
- Builds run serially because upstream warns about AX51's shared temporary state.
- A claimed unchanged rebuild must match upstream flash bytes and pass HEX checks.

## Shared protocol guarantees

The other repositories own the runtime wire contract. This packaging does not change:
MAV_CMD_SROT_MOVE=31000; movement type ordering; FlightMode integers;
PCA_RELAY_BASE_CH=8; MAVLINK_BAUD=115200; GCS_FAILSAFE_MS=5000; negative underwater
VFR_HUD.alt; input freshness; or the terminal-ACK contract. No NVS defaults version bump.

## Workspace and commits

workspace.json and srot.code-workspace connect all four repositories without
modifying their contents. tools/check_workspace.py is read-only.

Use the configured human author identity. Preserve upstream credit and do not add
AI co-author trailers. Documentation and validation evidence accompany changes.
