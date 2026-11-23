# Compatibility and inherited limitations

The baseline preserves Bluejay v0.21.0 source, defaults, EEPROM layout, bootloader
identity, protocol behavior and HEX images. It adds no new DShot commands and
requires no change to the existing SROT board, RP2350, flasher or Bondor code.

The ESC flasher is a separate ESP32 firmware. This repository's HEX files execute
on the ESC's Silicon Labs MCU; they must not be uploaded to an ESP32 or RP2350.
Use the existing flasher/configurator to identify hardware and install a matching
HEX only after deciding that the baseline is suitable.

## Forward/reverse 3D mode

The [upstream v0.21.0 release notes](https://github.com/bird-sanctuary/bluejay/releases/tag/v0.21.0)
report 3D-mode performance issues and advise against its use. That is material for
SROT because its existing thruster path uses forward/reverse 3D operation.
An unchanged copy inherits this issue.

The baseline still defaults to normal direction; it does not silently enable 3D
mode, alter startup power or patch an installed ESC's settings. Existing hardware
and tuning are untouched by publishing or checking this repository.

This release is a source/binary reference, not a claim of qualified AUV operation.
The qualification record needs actual ESC layout, motor, voltage, load and
reversal measurements. See [QUALIFICATION.md](QUALIFICATION.md).

## RPM and control

Bidirectional DShot telemetry and reversible motor direction are different
features. Returning RPM does not establish calibrated thrust or position control.
The vehicle's established control and RPM-loop choices belong to the board repo.
This import changes none of them.
