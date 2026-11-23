; Compasless SROT ESC firmware
; Application composition root. Active source is maintained under src/.
; Source architecture/refactor Copyright (C) 2026 Compasless contributors.
; Derived from Bluejay v0.21.0; original notices are preserved below.
; SPDX-License-Identifier: GPL-3.0-or-later
; Original source: Bluejay.asm
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Bluejay digital ESC firmware for controlling brushless motors in multirotors
;
; Copyleft  2022-2023 Daniel Mosquera
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
;
; This file is part of Bluejay.
;
; Bluejay is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; Bluejay is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with Bluejay.  If not, see <http://www.gnu.org/licenses/>.
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Bluejay is a fork of BLHeli_S <https://github.com/bitdump/BLHeli> by Steffen Skaug.
;

; Target constants, clocks and hardware selection.
$include (config\target_setup.inc)

; Persistent setting defaults; values unchanged.
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
