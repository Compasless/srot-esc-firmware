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
