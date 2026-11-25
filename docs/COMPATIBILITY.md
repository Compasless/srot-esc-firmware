# Hardware and qualification

SROT ESC v0.4.0 is a development prerelease for reversible AUV/ROV thrusters.
No ESC has been flashed or hardware-qualified as part of this release.

## Separate target files

`A_H_5_48` means layout A, H MCU family (EFM8BB21), deadtime code 5 and 48 kHz PWM.
X identifies EFM8BB51. H supports A–W, Z and OA; X supports A, B and C.
The deadtime codes are 0, 5, 10, 15, 20, 25, 30, 40, 50, 70, 90 and 120.
PWM variants are 24, 48 and 96 kHz. Higher PWM frequency is not claimed to give
better thruster performance.

A 4-in-1 ESC has four independently addressed ESC channels. Read each channel's
actual layout, MCU and deadtime. Use the matching file for each channel; there is
no universal 4-in-1 image. Never bypass hardware-layout checks.

## What changed

The 16-byte firmware name is `Compasless 3D   `; the wire firmware revision is 0.4
and the project release version is 0.4.0. EEPROM layout remains 208.
The initial image and default-reset routine set direction field 3. Every settings
load, settings decode and settings save normalizes that compatibility field to 3.
Values 1, 2, 4 and invalid bytes cannot select another operating mode.

The one-way running branch and configurable direction flags are removed. Commands
7, 8, 9, 10, 20 and 21 have no action; they cannot disable 3D or select a direction
override. Commands 1–5 (beeps), 12 (save) and 13–14 (EDT) retain their roles.
The six-repeat requirement is retained for save/EDT commands.

DShot value 0 is stop. Values 48–1047 select one rotation half and 1048–2047 select
the opposite half; verify physical propeller direction on the bench. There is no
selectable orientation inversion or turtle mode. Saved non-direction settings
retain their layout and meanings; their tuning is not reset by this policy.

The power and reversal protections continue on the fixed 3D path. This software
change removes mode selection; it does not establish improved motor performance.

Commutation drivers, startup power limits, demagnetization protection, gate timing,
bootloader and DShot packet encoding remain unchanged. Signal-loss and reversal
guards remain in the specialized 3D control path.
Temperature protection retains its inherited disabled default; this release does
not add a new thermal protection policy.

## Configurator identity

[ESC Configurator identifies firmware families through their NAME](https://github.com/stylesuxx/esc-configurator#adding-new-firmware).
The stock configurator has no registered Compasless family. It may report an unknown
firmware or decline configuration after flashing. Full read/configure/reflash
support for this identity has not been validated. Do not assume that uploading
a local HEX also guarantees later configuration/recovery through the stock UI.
The SROT flasher repository's serial passthrough is unchanged.

## Remaining validation

[The base v0.21.0 release](https://github.com/bird-sanctuary/bluejay/releases/tag/v0.21.0)
reports performance problems in 3D mode and advises against its use.
The Compasless changes have not fixed that issue. The 3D-only policy makes this
an AUV development candidate; it does not make the inherited behavior qualified.

Before operational use, validate safe neutral/arming, blocked rotor protection,
startup under water load, forward/reverse transitions, signal loss, current and
temperature limits, RPM telemetry and flasher recovery on the exact hardware.
No improvement in thrust, efficiency, thermal behavior or reversal has been measured.
