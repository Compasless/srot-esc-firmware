; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft  2022-2023 Daniel Mosquera
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
;

; Target constants, clocks and hardware selection.
$include (config\target_setup.inc)

; Persistent settings for reversible AUV thruster development.
$include (config\defaults.inc)

; Register aliases, fixed RAM state and stack layout.
$include (memory\runtime_state.inc)

; EEPROM image, configurator identity and startup melody.
$include (storage\eeprom_image.inc)

; Ordered application service modules.
$include (core\services.inc)

; Reset initialization, power-off state and input acquisition.
$include (core\startup.asm)

; Signal polarity and DShot rate acquisition.
$include (protocol\input_detection.asm)

; Arming, zero-throttle wait and startup request handling.
$include (control\arming.asm)

; Rotor startup setup and reversible-direction capture.
$include (control\startup.asm)

; Six-step running loop, startup transition and reversal.
$include (control\run.asm)

; Signal-loss shutdown, stall handling and stop/brake behavior.
$include (control\stop.asm)

; Reset vector, bootloader inclusion and assembly termination.
$include (boot\reset.asm)
