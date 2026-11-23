; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; Base layout
;
; The inheriting layout should

;
; Base layout
;
; The inheriting layout should
; - Specify PWM_ACTIVE_HIGH, COM_ACTIVE_HIGH and COMPARATOR_PORT
; - Set CUSTOM_* flags to override default implementation
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Bootloader definitions
;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Note: The RTX pin must be on port 0 because we use the IT01CF register for interrupts
RTX_PORT EQU P0                         ; Receive/Transmit port
RTX_MDOUT EQU P0MDOUT                   ; Set to 1 for PUSHPULL
RTX_MDIN EQU P0MDIN                     ; Set to 1 for DIGITAL
RTX_SKIP EQU P0SKIP                     ; Set to 1 for SKIP

RTX_BIT EQU RTX_PORT.RTX_PIN            ; RTX pin value

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PWM pin routing and polarity setup
;**** **** **** **** **** **** **** **** **** **** **** **** ****
$if NOT CUSTOM_PWM_SETUP

Initialize_Crossbar MACRO
    mov  XBR2, #40h                     ; Crossbar enabled
    mov  XBR1, #02h                     ; CEX0 and CEX1 routed to pins
ENDM

Set_Pwm_Polarity MACRO
IF PCA0CPM_POWER == PCA0CPM0
    mov  PCA0POL, #((COM_ACTIVE_HIGH SHL 1) + (1 - PWM_ACTIVE_HIGH))
ELSE
    mov  PCA0POL, #(((1 - PWM_ACTIVE_HIGH) SHL 1) + COM_ACTIVE_HIGH)
ENDIF
ENDM

$endif

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PWM channels and updating
;**** **** **** **** **** **** **** **** **** **** **** **** ****
$if NOT CUSTOM_PWM_UPDATE

Enable_Power_Pwm_Module MACRO
IF DEADTIME == 0
    mov  PCA0CPM_POWER, #4Ah            ; Enable comparator of module,enable match,set pwm mode
ELSE
    mov  PCA0CPM_POWER, #42h            ; Enable comparator of module,set pwm mode
ENDIF
ENDM

Enable_Damp_Pwm_Module MACRO
IF DEADTIME == 0
    mov  PCA0CPM_DAMP, #00h             ; Disable
ELSE
    mov  PCA0CPM_DAMP, #42h             ; Enable comparator of module,set pwm mode
ENDIF
ENDM

Set_Power_Pwm_Reg_L MACRO value
    mov  PCA0CPL_POWER, value
ENDM

Set_Power_Pwm_Reg_H MACRO value
    mov  PCA0CPH_POWER, value
ENDM

Set_Damp_Pwm_Reg_L MACRO value
    mov  PCA0CPL_DAMP, value
ENDM

Set_Damp_Pwm_Reg_H MACRO value
    mov  PCA0CPH_DAMP, value
ENDM

$endif

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Comparator setup and phase change
;**** **** **** **** **** **** **** **** **** **** **** **** ****
IF COMPARATOR_PORT == 0
    CMP_CN0 EQU CMP0CN0
    CMP_MD EQU CMP0MD
    CMP_MX EQU CMP0MX
ELSE
    CMP_CN0 EQU CMP1CN0
    CMP_MD EQU CMP1MD
    CMP_MX EQU CMP1MX
ENDIF

Initialize_Comparator MACRO
    mov  CMP_CN0, #80h                  ; Comparator enabled,no hysteresis
    mov  CMP_MD, #00h                   ; Comparator response time 100ns
IF COMPARATOR_INVERT == 1 AND MCU_TYPE >= 1
    mov  CMP_MD, #40h                   ; Output polarity inverted (Only supported on BB2 and BB51)
ENDIF
ENDM

Read_Comparator_Output MACRO
    mov  A, CMP_CN0                     ; Read comparator output
IF COMPARATOR_INVERT == 1 AND MCU_TYPE == 0
    cpl  A                              ; Invert output polarity manually on BB1
ENDIF
ENDM

; Set comparator multiplexer to phase A
Set_Comparator_Phase_A MACRO
IF MCU_TYPE == MCU_BB1 or MCU_TYPE == MCU_BB2
    mov  CMP_MX, #((A_Mux SHL 4) + V_Mux)
ELSEIF MCU_TYPE == MCU_BB51
    mov  CMP_MX, #12h
ENDIF
ENDM

; Set comparator multiplexer to phase B
Set_Comparator_Phase_B MACRO
IF MCU_TYPE == MCU_BB1 or MCU_TYPE == MCU_BB2
    mov  CMP_MX, #((B_Mux SHL 4) + V_Mux)
ELSEIF MCU_TYPE == MCU_BB51
    mov  CMP_MX, #10h
ENDIF
ENDM

; Set comparator multiplexer to phase C
Set_Comparator_Phase_C MACRO
IF MCU_TYPE == MCU_BB1 or MCU_TYPE == MCU_BB2
    mov  CMP_MX, #((C_Mux SHL 4) + V_Mux)
ELSEIF MCU_TYPE == MCU_BB51
    mov  CMP_MX, #11h
ENDIF
ENDM

; Toggle FETs 'on' and 'off'
IF PWM_ACTIVE_HIGH == 1                 ; PWM FET active high
    pON  LIT 'setb'
    pOFF LIT 'clr'
ELSE                                    ; PWM FET active low
    pON  LIT 'clr'
    pOFF LIT 'setb'
ENDIF

IF COM_ACTIVE_HIGH == 1                 ; COM FET active high
    cON  LIT 'setb'
    cOFF LIT 'clr'
ELSE                                    ; COM FET active low
    cON  LIT 'clr'
    cOFF LIT 'setb'
ENDIF

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; PWM phase change
;**** **** **** **** **** **** **** **** **** **** **** **** ****
$if NOT CUSTOM_PWM_PHASE

; All pwm and complementary pwm pins must be on port 1 to use the base code below
P_A_Pwm EQU P1.A_Pwm
P_A_Com EQU P1.A_Com
P_B_Pwm EQU P1.B_Pwm
P_B_Com EQU P1.B_Com
P_C_Pwm EQU P1.C_Pwm
P_C_Com EQU P1.C_Com

Set_Pwm_Phase_A MACRO
IF DEADTIME == 0
    cON  P_A_Com
    mov  P1SKIP, #(NOT (1 SHL A_Pwm))
ELSE
    mov  P1SKIP, #(NOT ((1 SHL A_Pwm) + (1 SHL A_Com)))
ENDIF
ENDM

Set_Pwm_Phase_B MACRO
IF DEADTIME == 0
    cON  P_B_Com
    mov  P1SKIP, #(NOT (1 SHL B_Pwm))
ELSE
    mov  P1SKIP, #(NOT ((1 SHL B_Pwm) + (1 SHL B_Com)))
ENDIF
ENDM

Set_Pwm_Phase_C MACRO
IF DEADTIME == 0
    cON  P_C_Com
    mov  P1SKIP, #(NOT (1 SHL C_Pwm))
ELSE
    mov  P1SKIP, #(NOT ((1 SHL C_Pwm) + (1 SHL C_Com)))
ENDIF
ENDM

Set_All_Pwm_Phases_Off MACRO
    mov  P1SKIP, #0FFh
ENDM

$endif

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Toggling FETs on/off
;**** **** **** **** **** **** **** **** **** **** **** **** ****
$if NOT CUSTOM_FET_TOGGLING

A_Pwm_Fet_On MACRO
    pON  P_A_Pwm
IF DEADTIME == 0
    cON  P_A_Com
ENDIF
ENDM

A_Pwm_Fet_Off MACRO
IF DEADTIME != 0
    pOFF P_A_Pwm
ELSE
    cOFF P_A_Com
ENDIF
ENDM

B_Pwm_Fet_On MACRO
    pON  P_B_Pwm
IF DEADTIME == 0
    cON  P_B_Com
ENDIF
ENDM

B_Pwm_Fet_Off MACRO
IF DEADTIME != 0
    pOFF P_B_Pwm
ELSE
    cOFF P_B_Com
ENDIF
ENDM

C_Pwm_Fet_On MACRO
    pON  P_C_Pwm
IF DEADTIME == 0
    cON  P_C_Com
ENDIF
ENDM

C_Pwm_Fet_Off MACRO
IF DEADTIME != 0
    pOFF P_C_Pwm
ELSE
    cOFF P_C_Com
ENDIF
ENDM

All_Pwm_Fets_Off MACRO
    A_Pwm_Fet_Off
    B_Pwm_Fet_Off
    C_Pwm_Fet_Off
ENDM

A_Com_Fet_On MACRO
IF DEADTIME == 0
    pOFF P_A_Pwm
ENDIF
    cON  P_A_Com
ENDM

A_Com_Fet_Off MACRO
    cOFF P_A_Com
ENDM

B_Com_Fet_On MACRO
IF DEADTIME == 0
    pOFF P_B_Pwm
ENDIF
    cON  P_B_Com
ENDM

B_Com_Fet_Off MACRO
    cOFF P_B_Com
ENDM

C_Com_Fet_On MACRO
IF DEADTIME == 0
    pOFF P_C_Pwm
ENDIF
    cON  P_C_Com
ENDM

C_Com_Fet_Off MACRO
    cOFF P_C_Com
ENDM

All_Com_Fets_Off MACRO
    A_Com_Fet_Off
    B_Com_Fet_Off
    C_Com_Fet_Off
ENDM

$endif

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; ADC and temperature measurement
;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Temperature measurement ADC value for which main motor power is limited at 80degC (low byte, assuming high byte is 1)
TEMP_LIMIT_2S EQU 49                    ; When using vdd 3.3V reference
TEMP_LIMIT_1S EQU 92                    ; When using 1.65V internal reference
TEMP_LIMIT_STEP EQU 9                   ; Temperature measurement ADC value increment for another 10degC

Initialize_Adc MACRO
    LOCAL Srot_initialize_adc_use_internal_1v65_vref Srot_initialize_adc_use_vdd_3v3_vref Srot_initialize_adc_vref_selected
IF MCU_TYPE == MCU_BB1 or MCU_TYPE == MCU_BB2
    mov  Temp1, #Srot_pgm_power_rating
    cjne @Temp1, #01h, Srot_initialize_adc_use_vdd_3v3_vref

Srot_initialize_adc_use_internal_1v65_vref:
    mov  REF0CN, #1Ch                   ; Set internal 1.65V as reference on 1S. Enable temp sensor and bias
    sjmp Srot_initialize_adc_vref_selected
Srot_initialize_adc_use_vdd_3v3_vref:
    mov  REF0CN, #0Ch                   ; Set vdd (3.3V) as reference on 2S+. Enable temp sensor and bias

Srot_initialize_adc_vref_selected:
IF MCU_TYPE == MCU_BB1
    mov  ADC0CF, #59h                   ; ADC clock 2MHz,PGA gain 1
ELSEIF MCU_TYPE == MCU_BB2
    mov  ADC0CF, #0B9h                  ; ADC clock 2MHz,PGA gain 1
ENDIF
ELSEIF MCU_TYPE == MCU_BB51
    mov  CLKGRP0, #18h                  ; Enable SAR clock,at 12MHz
    mov  ADC0CF1, #0Ah                  ; 800ns tracking time
    mov  ADC0CF2, #2Fh                  ; 1.65V reference
ENDIF

    mov  ADC0MX, #10h                   ; Select temp sensor input
IF MCU_TYPE == MCU_BB1 or MCU_TYPE == MCU_BB2
    mov  ADC0CN0, #80h                  ; ADC enabled
    mov  ADC0CN1, #01h                  ; Common mode buffer enabled
ELSEIF MCU_TYPE == MCU_BB51
    mov  ADC0CN0, #85h                  ; ADC enabled (gain 0.5,temp sensor enabled)
    mov  ADC0CN1, #20h                  ; 10bit mode
ENDIF
ENDM

Start_Adc MACRO
IF MCU_TYPE == MCU_BB1 or MCU_TYPE == MCU_BB2
    mov  ADC0CN0, #90h                  ; Initiate conversion
ELSEIF MCU_TYPE == MCU_BB51
    mov  ADC0CN0, #95h                  ; Initiate conversion (gain 0.5,temp sensor enabled)
ENDIF
ENDM

Stop_Adc MACRO
ENDM

Restart_Adc MACRO
    Stop_Adc
    Start_Adc
ENDM

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; LEDs
;**** **** **** **** **** **** **** **** **** **** **** **** ****
$if NOT CUSTOM_LED

Set_LED_0 MACRO
ENDM

Clear_LED_0 MACRO
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

$endif
