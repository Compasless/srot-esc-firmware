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

CSEG AT CSEG_RESET
Srot_reset:
    ljmp Srot_pgm_start

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Bootloader
;
; Include source code for BLHeli bootloader
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;CSEG AT 1C00h
$include (boot\serial_loader.inc)

END
