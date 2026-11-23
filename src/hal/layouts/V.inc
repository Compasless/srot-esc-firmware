; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; Hardware definition file "V".
;
; PORT 0                   |  PORT 1                   |  PWM    COM    PWM    LED

;
; Hardware definition file "V".
;
; PORT 0                   |  PORT 1                   |  PWM    COM    PWM    LED
; P0 P1 P2 P3 P4 P5 P6 P7  |  P0 P1 P2 P3 P4 P5 P6 P7  |  inv    inv    side    n
; -----------------------  |  -----------------------  |  -------------------------
; Am Bm Vn Cm __ RX __ Cc  |  Cp Bc __ __ Bp Ac Ap __  |  no     no     high   _
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

PWM_ACTIVE_HIGH EQU 1                   ; Pwm non-inverted
COM_ACTIVE_HIGH EQU 1                   ; Damping inverted

COMPARATOR_PORT EQU 0                   ; All comparator (mux) pins must be on the same port
COMPARATOR_INVERT EQU 0                 ; Comparator output non-inverted

IF DEADTIME == 0
    PCA0CPM_POWER EQU PCA0CPM0
    PCA0CPL_POWER EQU PCA0CPL0
    PCA0CPH_POWER EQU PCA0CPH0

    PCA0CPM_DAMP EQU PCA0CPM1
    PCA0CPL_DAMP EQU PCA0CPL1
    PCA0CPH_DAMP EQU PCA0CPH1
ELSE
    PCA0CPM_POWER EQU PCA0CPM1
    PCA0CPL_POWER EQU PCA0CPL1
    PCA0CPH_POWER EQU PCA0CPH1

    PCA0CPM_DAMP EQU PCA0CPM0
    PCA0CPL_DAMP EQU PCA0CPL0
    PCA0CPH_DAMP EQU PCA0CPH0
ENDIF

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PORT 0 definitions
;**** **** **** **** **** **** **** **** **** **** **** **** ****
C_Com EQU 7
;     EQU 6
RTX_PIN EQU 5
;     EQU 4
C_Mux EQU 3
V_Mux EQU 2
B_Mux EQU 1
A_Mux EQU 0

P0_DIGITAL EQU NOT((1 SHL A_Mux) + (1 SHL B_Mux) + (1 SHL C_Mux) + (1 SHL V_Mux))
P0_INIT EQU NOT(1 SHL C_Com)
P0_PUSHPULL EQU (1 SHL C_Com)
P0_SKIP EQU 0FFh

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PORT 1 definitions
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;     EQU 7
A_Pwm EQU 6
A_Com EQU 5
B_Pwm EQU 4
;     EQU 3
;     EQU 2
B_Com EQU 1
C_Pwm EQU 0

P1_DIGITAL EQU (1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm) + (1 SHL A_Com) + (1 SHL B_Com)
P1_INIT EQU 00h
P1_PUSHPULL EQU (1 SHL A_Pwm) + (1 SHL B_Pwm) + (1 SHL C_Pwm) + (1 SHL A_Com) + (1 SHL B_Com)
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
P_A_Pwm EQU P1.A_Pwm
P_A_Com EQU P1.A_Com
P_B_Pwm EQU P1.B_Pwm
P_B_Com EQU P1.B_Com
P_C_Pwm EQU P1.C_Pwm
P_C_Com EQU P0.C_Com

Set_Pwm_Phase_A MACRO
IF DEADTIME == 0
    cON  P_A_Com
    mov  P0SKIP, #0FFh
    mov  P1SKIP, #(NOT (1 SHL A_Pwm))
ELSE
    mov  P0SKIP, #0FFh
    mov  P1SKIP, #(NOT ((1 SHL A_Pwm) + (1 SHL A_Com)))
ENDIF
ENDM

Set_Pwm_Phase_B MACRO
IF DEADTIME == 0
    cON  P_B_Com
    mov  P0SKIP, #0FFh
    mov  P1SKIP, #(NOT (1 SHL B_Pwm))
ELSE
    mov  P0SKIP, #0FFh
    mov  P1SKIP, #(NOT ((1 SHL B_Pwm) + (1 SHL B_Com)))
ENDIF
ENDM

Set_Pwm_Phase_C MACRO
IF DEADTIME == 0
    cON  P_C_Com
    mov  P0SKIP, #0FFh
    mov  P1SKIP, #(NOT (1 SHL C_Pwm))
ELSE
    mov  P0SKIP, #(NOT (1 SHL C_Com))
    mov  P1SKIP, #(NOT (1 SHL C_Pwm))
ENDIF
ENDM

Set_All_Pwm_Phases_Off MACRO
    mov  P0SKIP, #0FFh
    mov  P1SKIP, #0FFh
ENDM

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Inherit base layout
;**** **** **** **** **** **** **** **** **** **** **** **** ****
$set (CUSTOM_PWM_PHASE)
$include (hal\layouts\Base.inc)
