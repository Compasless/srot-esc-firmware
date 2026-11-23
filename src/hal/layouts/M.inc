; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; Hardware definition file "M".
;
; PORT 0                   |  PORT 1                   |  PWM    COM    PWM    LED

;
; Hardware definition file "M".
;
; PORT 0                   |  PORT 1                   |  PWM    COM    PWM    LED
; P0 P1 P2 P3 P4 P5 P6 P7  |  P0 P1 P2 P3 P4 P5 P6 P7  |  inv    inv    side    n
; -----------------------  |  -----------------------  |  -------------------------
; __ __ L0 RX Bm Vn Cm Am  |  __ Ap Bp Cp Ac Bc Cc __  |  no     no     high   1
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

PWM_ACTIVE_HIGH EQU 1                   ; Pwm non-inverted
COM_ACTIVE_HIGH EQU 1                   ; Damping inverted

COMPARATOR_PORT EQU 0                   ; All comparator (mux) pins must be on the same port
COMPARATOR_INVERT EQU 0                 ; Comparator output non-inverted

PCA0CPM_POWER EQU PCA0CPM0
PCA0CPL_POWER EQU PCA0CPL0
PCA0CPH_POWER EQU PCA0CPH0

PCA0CPM_DAMP EQU PCA0CPM1
PCA0CPL_DAMP EQU PCA0CPL1
PCA0CPH_DAMP EQU PCA0CPH1

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PORT 0 definitions
;**** **** **** **** **** **** **** **** **** **** **** **** ****
A_Mux EQU 7
C_Mux EQU 6
V_Mux EQU 5
B_Mux EQU 4
RTX_PIN EQU 3
LED_0 EQU 2
;     EQU 1
;     EQU 0

P0_DIGITAL EQU NOT((1 SHL A_Mux) + (1 SHL B_Mux) + (1 SHL C_Mux) + (1 SHL V_Mux))
P0_INIT EQU NOT(1 SHL LED_0)
P0_PUSHPULL EQU (1 SHL LED_0)
P0_SKIP EQU 0FFh

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PORT 1 definitions
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;     EQU 7
C_Com EQU 6
B_Com EQU 5
A_Com EQU 4
C_Pwm EQU 3
B_Pwm EQU 2
A_Pwm EQU 1
;     EQU 0

P1_DIGITAL EQU (1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm) + (1 SHL A_Com) + (1 SHL B_Com) + (1 SHL C_Com)
P1_INIT EQU 00h
P1_PUSHPULL EQU (1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm) + (1 SHL A_Com) + (1 SHL B_Com) + (1 SHL C_Com)
P1_SKIP EQU 0FFh

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PORT 2 definitions
;**** **** **** **** **** **** **** **** **** **** **** **** ****
DebugPin EQU 0

P2_DIGITAL EQU (1 SHL DebugPin)
P2_PUSHPULL EQU (1 SHL DebugPin)
P2_SKIP EQU (1 SHL DebugPin)

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; LED configuration
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Set_LED_0 MACRO
    setb P0.LED_0
ENDM

Clear_LED_0 MACRO
    clr  P0.LED_0
ENDM

Set_LED_1 MACRO
ENDM

Clear_LED_1 MACRO
ENDM

Set_LED_2 MACRO
ENDM

Clear_LED_2 MACRO
ENDM

Set_LED_3 MACRO
ENDM

Clear_LED_3 MACRO
ENDM

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Inherit base layout
;**** **** **** **** **** **** **** **** **** **** **** **** ****
$set (CUSTOM_LED)
$include (hal\layouts\Base.inc)
