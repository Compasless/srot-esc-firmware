# Configurator instructions

This directory is part of the fourth SROT repository. Keep its source here;
dependency caches and Sites deployment mirrors are not additional SROT checkouts.

Read README.md and upstream.lock.json. Firmware bytes are copied from the pinned
published release only. Do not patch HEX data or restore upstream firmware branding.
Keep 3D fixed and normalize MOTOR_DIRECTION to 3 on every parameter write.
Preserve layout, MCU, CRC, erase/write/readback and bootloader checks.
Never expose a force/ignore-layout control or motor-test commands.

Use the existing SROT flasher's MSP/4-way interface at 115200 baud. Do not change
the flasher, control-board or ground-station source as part of a configurator edit.

Tests must use simulated ports, never request real serial hardware. Compile and
test changed browser/protocol behavior; preserve original AGPL notices and source
availability. Reuse the persisted Sites project ID. Keep source credentials out
of files and command lines.
