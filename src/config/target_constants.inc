; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft 2023 Chris Landa
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; Enums
;
; Enumerations to make code more readable
;

;
; Enums
;
; Enumerations to make code more readable
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; MCU Types
;**** **** **** **** **** **** **** **** **** **** **** **** ****
    MCU_BB51 EQU 2
    MCU_BB2 EQU 1
    MCU_BB1 EQU 0

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PWM frequency and resolution
;**** **** **** **** **** **** **** **** **** **** **** **** ****

    ; Frequency
    PWM_96 EQU 2
    PWM_48 EQU 1
    PWM_24 EQU 0

    ; Resolution
    PWM_11_BIT EQU 3
    PWM_10_BIT EQU 2
    PWM_9_BIT EQU 1
    PWM_8_BIT EQU 0

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; DSHOT Commands
;**** **** **** **** **** **** **** **** **** **** **** **** ****
    CMD_DIRECTION_USER_REVERSE EQU 21
    CMD_DIRECTION_USER_NORMAL EQU 20
    CMD_EXTENDED_TELEMETRY_DISABLE EQU 14
    CMD_EXTENDED_TELEMETRY_ENABLE EQU 13
    CMD_SAVE_SETTINGS EQU 12
    CMD_BIDIR_ON EQU 10
    CMD_BIDIR_OFF EQU 9
    CMD_DIRECTION_REVERSE EQU 8
    CMD_DIRECTION_NORMAL EQU 7
    CMD_ESC_INFO EQU 6
    CMD_BEEP_5 EQU 5
    CMD_BEEP_4 EQU 4
    CMD_BEEP_3 EQU 3
    CMD_BEEP_2 EQU 2
    CMD_BEEP_1 EQU 1
