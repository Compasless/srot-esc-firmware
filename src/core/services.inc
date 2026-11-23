; Compasless SROT ESC firmware
; Ordered application service modules.
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

CSEG AT CSEG_APP                        ; Code segment after interrupt vectors

; Submodule includes
$include (interrupts\vectors.asm)
$include (drivers\indicators.asm)
$include (drivers\power_stage.asm)
$include (core\scheduler.asm)
$include (control\timing.asm)
$include (control\commutation.asm)
$include (protocol\dshot.asm)
$include (storage\flash_settings.asm)
$include (config\settings.asm)

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Main program
;
; Main program entry point
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
