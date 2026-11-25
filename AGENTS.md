# AGENTS.md — srot-esc-firmware

This is Compasless SROT ESC firmware. Read README.md, docs/BUILD.md and
docs/COMPATIBILITY.md. Active source starts at src/SrotEsc.asm.

The three existing SROT repositories must stay unchanged for this task.
Workspace links expose their canonical checkouts without copying firmware.
Never flash hardware from an automated build, test or packaging command.

Preserve COPYING and original author notices. Keep upstream credit in README.md
and NOTICE. Compasless identity is intentional; do not restore upstream branding
as the runtime firmware name. Describe changes and hardware evidence accurately.

Use the exact detected layout, MCU, deadtime and selected PWM target. Do not guess
from a board being 4-in-1. Preserve pin polarity, deadtime, EEPROM layout, bootloader
and DShot encoding. 3D is the only motor operating mode. Never reintroduce legacy direction flags,
one-way branches, turtle overrides or commands that can disable 3D.
Keep the inherited 3D-mode limitation visible until a validated fix supersedes it.

Build with tools/build.py. The ASEM-51 package is fetched unchanged with a pinned
hash; do not distribute modified assembler binaries or licensing material.
Targets have isolated build directories and may be assembled concurrently.
Validate protected-source hashes, approved image fingerprints and compiled policy
execution checks. A firmware change requires a documented validation update; never
update a hash merely to hide an unexplained difference.

Run Python unit tests and actual representative source builds after tool changes.
Before a release, build all targets and retain checksums/build manifest.
A compiled image is not evidence of hardware qualification or improved thrust.

The other repositories own the runtime wire contract:
MAV_CMD_SROT_MOVE=31000; movement ordering; FlightMode integers;
PCA_RELAY_BASE_CH=8; MAVLINK_BAUD=115200; GCS_FAILSAFE_MS=5000; negative underwater
VFR_HUD.alt; input freshness; terminal ACK guarantees. No NVS version changes.

Use the configured human Git author. Preserve history and author credit.
Do not add AI co-author trailers.
