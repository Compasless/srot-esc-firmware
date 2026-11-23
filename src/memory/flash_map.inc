; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft  2023 Chris Landa
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; Codespace segment definitions for different MCU types
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****


;
; Codespace segment definitions for different MCU types
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

    ; General
    CSEG_APP EQU 80h

IF MCU_TYPE == MCU_BB51
    ; BB51
    CSEG_RESET EQU 2FFDh
    CSEG_EEPROM EQU 3000h
    CSEG_LAYOUT_TAG EQU 3040h
    CSEG_MCU_TAG EQU 3050h
    CSEG_NAME EQU 3060h
    CSEG_MELODY EQU 3070h
    CSEG_BOOT_START EQU 0F000h
ELSE
    ; BB1 & BB21
    CSEG_RESET EQU 19FDh
    CSEG_EEPROM EQU 1A00h
    CSEG_LAYOUT_TAG EQU 1A40h
    CSEG_MCU_TAG EQU 1A50h
    CSEG_NAME EQU 1A60h
    CSEG_MELODY EQU 1A70h
    CSEG_BOOT_START EQU 1C00h
ENDIF
