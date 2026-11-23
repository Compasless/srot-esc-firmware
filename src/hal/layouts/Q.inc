; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; Hardware definition file "Q".
;
; PORT 0                   |  PORT 1                   |  PWM    COM    PWM    LED

;
; Hardware definition file "Q".
;
; PORT 0                   |  PORT 1                   |  PWM    COM    PWM    LED
; P0 P1 P2 P3 P4 P5 P6 P7  |  P0 P1 P2 P3 P4 P5 P6 P7  |  inv    inv    side    n
; -----------------------  |  -----------------------  |  -------------------------
; __ RX __ L0 L1 Ap Bp Cp  |  Ac Bc Cc Vn Cm Bm Am __  |  no     no     high   2
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

PWM_ACTIVE_HIGH EQU 1                   ; Pwm non-inverted
COM_ACTIVE_HIGH EQU 1                   ; Damping inverted

COMPARATOR_PORT EQU 1                   ; All comparator (mux) pins must be on the same port
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
C_Pwm EQU 7
B_Pwm EQU 6
A_Pwm EQU 5
LED_1 EQU 4
LED_0 EQU 3
;     EQU 2
RTX_PIN EQU 1
;     EQU 0

P0_DIGITAL EQU 0FFh
P0_INIT EQU (1 SHL RTX_PIN)
P0_PUSHPULL EQU (1 SHL LED_0) + (1 SHL LED_1) + (1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm)
P0_SKIP EQU 0FFh

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PORT 1 definitions
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;     EQU 7
A_Mux EQU 6
B_Mux EQU 5
C_Mux EQU 4
V_Mux EQU 3
C_Com EQU 2
B_Com EQU 1
A_Com EQU 0

P1_DIGITAL EQU (1 SHL A_Com) + (1 SHL B_Com) + (1 SHL C_Com)
P1_INIT EQU 00h
P1_PUSHPULL EQU (1 SHL A_Com) + (1 SHL B_Com) + (1 SHL C_Com)
P1_SKIP EQU 0FFh

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PORT 2 definitions
;**** **** **** **** **** **** **** **** **** **** **** **** ****
DebugPin EQU 0

P2_DIGITAL EQU (1 SHL DebugPin)
P2_PUSHPULL EQU (1 SHL DebugPin)
P2_SKIP EQU (1 SHL DebugPin)

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PWM Phase
;**** **** **** **** **** **** **** **** **** **** **** **** ****
P_A_Pwm EQU P0.A_Pwm
P_A_Com EQU P1.A_Com
P_B_Pwm EQU P0.B_Pwm
P_B_Com EQU P1.B_Com
P_C_Pwm EQU P0.C_Pwm
P_C_Com EQU P1.C_Com

Set_Pwm_Phase_A MACRO
IF DEADTIME == 0
    cON  P_A_Com
    mov  P0SKIP, #(NOT (1 SHL A_Pwm))
    mov  P1SKIP, #0FFh
ELSE
    mov  P0SKIP, #(NOT (1 SHL A_Pwm))
    mov  P1SKIP, #(NOT (1 SHL A_Com))
ENDIF
ENDM

Set_Pwm_Phase_B MACRO
IF DEADTIME == 0
    cON  P_B_Com
    mov  P0SKIP, #(NOT (1 SHL B_Pwm))
    mov  P1SKIP, #0FFh
ELSE
    mov  P0SKIP, #(NOT (1 SHL B_Pwm))
    mov  P1SKIP, #(NOT (1 SHL B_Com))
ENDIF
ENDM

Set_Pwm_Phase_C MACRO
IF DEADTIME == 0
    cON  P_C_Com
    mov  P0SKIP, #(NOT (1 SHL C_Pwm))
    mov  P1SKIP, #0FFh
ELSE
    mov  P0SKIP, #(NOT (1 SHL C_Pwm))
    mov  P1SKIP, #(NOT (1 SHL C_Com))
ENDIF
ENDM

Set_All_Pwm_Phases_Off MACRO
    mov  P0SKIP, #0FFh
    mov  P1SKIP, #0FFh
ENDM

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
    setb P0.LED_1
ENDM

Clear_LED_1 MACRO
    clr  P0.LED_1
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
$set (CUSTOM_PWM_PHASE,CUSTOM_LED)
$include (hal\layouts\Base.inc)
