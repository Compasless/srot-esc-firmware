; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft  2022-2023 Daniel Mosquera
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-25; fixed 3D thruster operation.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; Settings
;

;
; Settings
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

; Sets default programming parameters
Srot_set_default_parameters:
    mov  Temp1, #Srot__pgm_gov_p_gain
    mov  @Temp1, #0FFh                  ; _Pgm_Gov_P_Gain
    imov Temp1, #DEFAULT_PGM_STARTUP_POWER_MIN ; Pgm_Startup_Power_Min
    imov Temp1, #DEFAULT_PGM_STARTUP_BEEP ; Pgm_Startup_Beep
    imov Temp1, #0FFh                   ; _Pgm_Dithering
    imov Temp1, #DEFAULT_PGM_STARTUP_POWER_MAX ; Pgm_Startup_Power_Max
    imov Temp1, #0FFh                   ; _Pgm_Rampup_Slope
    imov Temp1, #DEFAULT_PGM_RPM_POWER_SLOPE ; Pgm_Rpm_Power_Slope
    imov Temp1, #(24 SHL PWM_FREQ)      ; Pgm_Pwm_Freq
    imov Temp1, #SROT_3D_DIRECTION      ; Fixed 3D compatibility field
    imov Temp1, #0FFh                   ; _Pgm_Input_Pol

    inc  Temp1                          ; Skip Initialized_L_Dummy
    inc  Temp1                          ; Skip Initialized_H_Dummy

    imov Temp1, #0FFh                   ; _Pgm_Enable_TX_Program
    imov Temp1, #DEFAULT_PGM_BRAKING_STRENGTH ; Pgm_Braking_Strength
    imov Temp1, #0FFh                   ; _Pgm_Gov_Setup_Target
    imov Temp1, #0FFh                   ; _Pgm_Startup_Rpm
    imov Temp1, #0FFh                   ; _Pgm_Startup_Accel
    imov Temp1, #0FFh                   ; _Pgm_Volt_Comp
    imov Temp1, #DEFAULT_PGM_COMM_TIMING ; Pgm_Comm_Timing
    imov Temp1, #0FFh                   ; _Pgm_Damping_Force
    imov Temp1, #0FFh                   ; _Pgm_Gov_Range
    imov Temp1, #0FFh                   ; _Pgm_Startup_Method
    imov Temp1, #0FFh                   ; _Pgm_Min_Throttle
    imov Temp1, #0FFh                   ; _Pgm_Max_Throttle
    imov Temp1, #DEFAULT_PGM_BEEP_STRENGTH ; Pgm_Beep_Strength
    imov Temp1, #DEFAULT_PGM_BEACON_STRENGTH ; Pgm_Beacon_Strength
    imov Temp1, #DEFAULT_PGM_BEACON_DELAY ; Pgm_Beacon_Delay
    imov Temp1, #0FFh                   ; _Pgm_Throttle_Rate
    imov Temp1, #DEFAULT_PGM_DEMAG_COMP ; Pgm_Demag_Comp
    imov Temp1, #0FFh                   ; _Pgm_BEC_Voltage_High
    imov Temp1, #0FFh                   ; _Pgm_Center_Throttle
    imov Temp1, #0FFh                   ; _Pgm_Main_Spoolup_Time
    imov Temp1, #DEFAULT_PGM_ENABLE_TEMP_PROT ; Pgm_Enable_Temp_Prot
    imov Temp1, #0FFh                   ; _Pgm_Enable_Power_Prot
    imov Temp1, #0FFh                   ; _Pgm_Enable_Pwm_Input
    imov Temp1, #0FFh                   ; _Pgm_Pwm_Dither
    imov Temp1, #DEFAULT_PGM_BRAKE_ON_STOP ; Pgm_Brake_On_Stop
    imov Temp1, #DEFAULT_PGM_LED_CONTROL ; Pgm_LED_Control
    imov Temp1, #DEFAULT_PGM_POWER_RATING ; Pgm_Power_Rating
    imov Temp1, #DEFAULT_PGM_SAFETY_ARM ; Pgm_Safety_Arm

    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Decode settings
;
; Decodes programmed settings and set RAM variables accordingly
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_decode_settings:
    ; Old or externally written direction values never select an operating mode.
    mov  Temp1, #Srot_pgm_direction
    mov  @Temp1, #SROT_3D_DIRECTION
    clr  C                             ; Deterministic carry for the power-limit checks

Srot_decode_protection:
    ; Check startup power
    mov  Temp1, #Srot_pgm_startup_power_max
    mov  A, #80                         ; Limit to at most 80
    subb A, @Temp1
    jnc  Srot_decode_settings_check_low_rpm
    mov  @Temp1, #80

Srot_decode_settings_check_low_rpm:
    ; Check low rpm power slope
    mov  Temp1, #Srot_pgm_rpm_power_slope
    mov  A, #13                         ; Limit to at most 13
    subb A, @Temp1
    jnc  Srot_decode_settings_set_low_rpm
    mov  @Temp1, #13

Srot_decode_settings_set_low_rpm:
    mov  Srot_low_rpm_pwr_slope, @Temp1

    ; Decode demag compensation
    mov  Temp1, #Srot_pgm_demag_comp
    mov  A, @Temp1
    mov  Srot_demag_pwr_off_thresh, #255     ; Set default

    cjne A, #2, Srot_decode_demag_high

    mov  Srot_demag_pwr_off_thresh, #160     ; Settings for demag comp low

Srot_decode_demag_high:
    cjne A, #3, Srot_decode_demag_done

    mov  Srot_demag_pwr_off_thresh, #130     ; Settings for demag comp high

Srot_decode_demag_done:
    ; Decode temperature protection limit
    mov  Srot_temp_prot_limit, #0
    mov  Temp1, #Srot_pgm_enable_temp_prot
    mov  A, @Temp1
    mov  Temp2, A                       ; Temp2 = *Pgm_Enable_Temp_Prot;
    jz   Srot_decode_temp_done

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Power rating only applies to BB21 because voltage references behave diferently
; depending on if an external voltage regulator is used or not.
;
; NOTE: For BB51, the 1s power rating code path is mandatory
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
IF MCU_TYPE == MCU_BB1 or MCU_TYPE == MCU_BB2
    ; Read power rating and decode temperature limit
    mov  Temp1, #Srot_pgm_power_rating
    cjne @Temp1, #01h, Srot_decode_temp_use_adc_use_vdd_3v3_vref
ENDIF

; Set A to temperature limit depending on power rating
Srot_decode_temp_use_adc_use_internal_1v65_vref:
    mov  A, #(TEMP_LIMIT_1S - TEMP_LIMIT_STEP)
    sjmp Srot_decode_temp_step
Srot_decode_temp_use_adc_use_vdd_3v3_vref:
    mov  A, #(TEMP_LIMIT_2S - TEMP_LIMIT_STEP)

; Increase A while Temp2-- != 0;
Srot_decode_temp_step:
    add  A, #TEMP_LIMIT_STEP
    djnz Temp2, Srot_decode_temp_step

; Set Temp_Prot_Limit to the temperature limit calculated in A
Srot_decode_temp_done:
    mov  Srot_temp_prot_limit, A

    mov  Temp1, #Srot_pgm_beep_strength      ; Read programmed beep strength setting
    mov  Srot_beep_strength, @Temp1          ; Set beep strength

    mov  Temp1, #Srot_pgm_braking_strength   ; Read programmed braking strength setting
    mov  A, @Temp1
IF PWM_BITS_H == PWM_11_BIT             ; Scale braking strength to pwm resolution
    ; Note: Added for completeness
    ; Currently 11-bit pwm is only used on targets with built-in dead time insertion
    rl   A
    rl   A
    rl   A
    mov  Temp2, A
    anl  A, #07h
    mov  Srot_pwm_braking_h, A
    mov  A, Temp2
    anl  A, #0F8h
    mov  Srot_pwm_braking_l, A
ELSEIF PWM_BITS_H == PWM_10_BIT
    rl   A
    rl   A
    mov  Temp2, A
    anl  A, #03h
    mov  Srot_pwm_braking_h, A
    mov  A, Temp2
    anl  A, #0FCh
    mov  Srot_pwm_braking_l, A
ELSEIF PWM_BITS_H == PWM_9_BIT
    rl   A
    mov  Temp2, A
    anl  A, #01h
    mov  Srot_pwm_braking_h, A
    mov  A, Temp2
    anl  A, #0FEh
    mov  Srot_pwm_braking_l, A
ELSEIF PWM_BITS_H == PWM_8_BIT
    mov  Srot_pwm_braking_h, #0
    mov  Srot_pwm_braking_l, A
ENDIF
    cjne @Temp1, #0FFh, Srot_decode_end
    mov  Srot_pwm_braking_l, #0FFh           ; Apply full braking if setting is max

Srot_decode_end:
    ; Return
    ret
