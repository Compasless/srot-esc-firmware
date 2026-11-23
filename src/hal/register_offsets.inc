; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft  2023 Chris Landa
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; MCU Offsets
;
; Offsets for memory space based on MCU
;

;
; MCU Offsets
;
; Offsets for memory space based on MCU
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

IF MCU_TYPE == MCU_BB51
    BOOTLOADER_OFFSET EQU 0F0h
ELSE
    BOOTLOADER_OFFSET EQU 1Ch
ENDIF
