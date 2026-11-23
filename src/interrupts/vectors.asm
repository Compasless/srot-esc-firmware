; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft  2022-2023 Daniel Mosquera
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; Interrupt handlers
;

;
; Interrupt handlers
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Timer0 interrupt routine (High priority)
;
; Generate DShot telemetry signal
;
; ASSERT:
; - Must NOT be called while Flag_Telemetry_Pending is cleared
; - Must NOT write to Temp7, Temp8
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_t0_int:
    push PSW
    mov  PSW, #10h                      ; Select register bank 2 for this interrupt

    dec  Temp1
    cjne Temp1, #(Srot_temp_storage - 1), Srot_t0_int_dshot_tlm_transition

    inc  Temp1                          ; Set pointer to uncritical position

    ; If last pulse is high, telemetry is finished,
    ; otherwise wait for it to return to high
    jb   RTX_BIT, Srot_t0_int_dshot_tlm_finish

Srot_t0_int_dshot_tlm_transition:
    cpl  RTX_BIT                        ; Invert signal level

    mov  TL0, @Temp1                    ; Schedule next update

    pop  PSW
    reti

Srot_t0_int_dshot_tlm_finish:
    ; Configure RTX_PIN for digital input
    anl  RTX_MDOUT, #(NOT (1 SHL RTX_PIN)) ; Set RTX_PIN output mode to open-drain
    setb RTX_BIT                        ; Float high

    clr  IE_ET0                         ; Disable Timer0 interrupts

    mov  CKCON0, Temp8                  ; Restore regular DShot Timer0/1 clock settings
    mov  TMOD, #0AAh                    ; Timer0/1 gated by Int0/1

    clr  TCON_IE0                       ; Clear Int0 pending flag
    clr  TCON_IE1                       ; Clear Int1 pending flag

    mov  TL0, #0                        ; Reset Timer0 count
    setb IE_EX0                         ; Enable Int0 interrupts
    setb IE_EX1                         ; Enable Int1 interrupts

    clr  Flag_Telemetry_Pending         ; Mark that new telemetry packet may be created

    pop  PSW
    reti

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Timer1 interrupt routine
;
; Tasks:
; - Decode DShot frame
; - Process new throttle value and update PWM registers
; - Schedule DShot telemetry
;
; NOTE: The ISR should be left as soon as possible. Instead of using loops,
;       often times more codespace is used since it saves valuable time.
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_t1_int:
    clr  IE_EX0                         ; Disable Int0 interrupts
    clr  TCON_TR1                       ; Stop Timer1
    mov  TL1, Srot_dshot_timer_preset        ; Reset sync timer

    push PSW
    mov  PSW, #8h                       ; Select register bank 1 for this interrupt
    push ACC
    push B

    ; NOTE: Interrupts are not explicitly disabled. Assume higher priority
    ;       interrupts (Int0, Timer0) to be disabled at this point.
    clr  TMR2CN0_TR2                    ; Timer2 disabled
    mov  Temp2, TMR2L                   ; Read timer value
    mov  Temp3, TMR2H
    setb TMR2CN0_TR2                    ; Timer2 enabled

    ; Check frame time length
    clr  C
    mov  A, Temp2
    subb A, Srot_dshot_frame_start_l
    mov  Temp2, A
    mov  A, Temp3
    subb A, Srot_dshot_frame_start_h
    jnz  Srot_t1_int_frame_fail              ; Frame too long

    clr  C
    mov  A, Temp2
    subb A, Srot_dshot_frame_length_thr
    jc   Srot_t1_int_frame_fail              ; Frame too short
    subb A, Srot_dshot_frame_length_thr
    jnc  Srot_t1_int_frame_fail              ; Frame too long

    ; Check that correct number (16) of pulses is received
    cjne Temp1, #16, Srot_t1_int_frame_fail  ; Read current pointer

    ; Decode transmitted data
    mov  Temp1, #0                      ; Set pointer
    mov  Temp2, Srot_dshot_pwm_thr           ; DShot pulse width criteria
    mov  Temp6, #0                      ; Reset timestamp

    ; Decode DShot data MSB nibble (4bit).
    ; Use more code space to save time (by not using loop)
    Decode_DShot_2Bit Temp5, Srot_t1_int_frame_fail
    Decode_DShot_2Bit Temp5, Srot_t1_int_frame_fail
    sjmp Srot_t1_int_decode_lsb              ; Continue with decoding LSB

Srot_t1_int_frame_fail:
    sjmp Srot_t1_int_outside_range

Srot_t1_int_decode_lsb:
    ; Decode DShot data LSB (8bit)
    Decode_DShot_2Bit Temp4, Srot_t1_int_outside_range
    Decode_DShot_2Bit Temp4, Srot_t1_int_outside_range
    Decode_DShot_2Bit Temp4, Srot_t1_int_outside_range
    Decode_DShot_2Bit Temp4, Srot_t1_int_outside_range
    sjmp Srot_t1_int_decode_checksum

Srot_t1_int_outside_range:
    inc  Srot_rcp_outside_range_cnt
    mov  A, Srot_rcp_outside_range_cnt
    jnz  Srot_t1_int_outside_range_check_limit
    dec  Srot_rcp_outside_range_cnt

Srot_t1_int_outside_range_check_limit:
    clr  C
    mov  A, Srot_rcp_outside_range_cnt
    subb A, #50                         ; Allow a given number of outside pulses
    jc   Srot_t1_int_exit_timeout            ; If outside limits - ignore first pulses

    ; RC pulse signal has not timed out, but pulses are not recognized as DShot
    setb Flag_Rcp_Stop                  ; Set pulse length to zero
    mov  Srot_dshot_cmd, #0                  ; Reset DShot command
    mov  Srot_dshot_cmd_cnt, #0              ; Reset Dshot command counter

    ajmp Srot_t1_int_exit_no_tlm             ; Exit without resetting timeout

Srot_t1_int_exit_timeout:
    mov  Srot_rcp_timeout_cntd, #10          ; Set timeout count
    ajmp Srot_t1_int_exit_no_tlm

Srot_t1_int_decode_checksum:
    ; Decode DShot data checksum
    Decode_DShot_2Bit Temp3, Srot_t1_int_outside_range
    Decode_DShot_2Bit Temp3, Srot_t1_int_outside_range

    ; XOR check (in inverted data, which is ok), only low nibble is considered
    mov  A, Temp4
    swap A
    xrl  A, Temp4
    xrl  A, Temp5
    xrl  A, Temp3
    jnb  Flag_Rcp_DShot_Inverted, Srot_t1_int_decode_checksum_xor_check
    cpl  A                              ; Invert checksum if using inverted DShot

Srot_t1_int_decode_checksum_xor_check:
    anl  A, #0Fh
    jnz  Srot_t1_int_outside_range           ; XOR check

    ; Invert DShot data and subtract 96 (still 12 bits)
    clr  C
    mov  A, Temp4
    cpl  A
    mov  Temp3, A                       ; Store in case it is a DShot command
    subb A, #96
    mov  Temp4, A
    mov  A, Temp5
    cpl  A
    anl  A, #0Fh
    subb A, #0
    mov  Temp5, A
    jnc  Srot_t1_int_normal_range

    mov  A, Temp3                       ; Check for 0 or DShot command
    mov  Temp5, #0
    mov  Temp4, #0
    jz   Srot_t1_int_dshot_set_cmd           ; Clear DShot command when RC pulse is zero

    clr  C                              ; We are in the special DShot range
    rrc  A                              ; Shift tlm bit into carry
    jnc  Srot_t1_int_dshot_clear_cmd         ; Check for tlm bit set (if not telemetry,invalid command)

    cjne A, Srot_dshot_cmd, Srot_t1_int_dshot_set_cmd

    inc  Srot_dshot_cmd_cnt
    sjmp Srot_t1_int_normal_range

Srot_t1_int_dshot_clear_cmd:
    clr  A

Srot_t1_int_dshot_set_cmd:
    mov  Srot_dshot_cmd, A
    mov  Srot_dshot_cmd_cnt, #0

Srot_t1_int_normal_range:
    ; Check for bidirectional operation (0=stop, 96-2095->fwd, 2096-4095->rev)
    jnb  Flag_Pgm_Bidir, Srot_t1_int_not_bidir ; If not bidirectional operation - branch

    ; Subtract 2000 (still 12 bits)
    clr  C
    mov  A, Temp4
    subb A, #0D0h
    mov  B, A
    mov  A, Temp5
    subb A, #07h
    jc   Srot_t1_int_bidir_set               ; Is result is positive?
    mov  Temp4, B                       ; Yes - Use the subtracted value
    mov  Temp5, A

Srot_t1_int_bidir_set:
    jnb  Flag_Pgm_Dir_Rev, Srot_t1_int_bidir_set_dir ; Check programmed direction
    cpl  C                              ; Reverse direction

Srot_t1_int_bidir_set_dir:
    mov  Flag_Rcp_Dir_Rev, C            ; Set rcp direction

    ; Multiply throttle value by 2
    clr  C
    rlca Temp4
    rlca Temp5

Srot_t1_int_not_bidir:
    ; From here Temp5/Temp4 should be at most 3999 (4095-96)
    mov  A, Temp4                       ; Divide by 16 (12 to 8-bit)
    anl  A, #0F0h
    orl  A, Temp5                       ; NOTE: Assumes Temp5 to be 4-bit
    swap A
    mov  B, #5                          ; Divide by 5 (80 in total)
    div  AB
    mov  Temp3, A

    ; Align to 11 bits
    ;clr    C                           ; NOTE: Cleared by div

    rrca Temp5
    mov  A, Temp4
    rrc  A

    ; From here Temp5/Temp4 should be at most 1999 (4095-96) / 2
    ; Scale from 2000 to 2048
    add  A, Temp3
    mov  Temp4, A
    mov  A, Temp5
    addc A, #0
    mov  Temp5, A
    jnb  ACC.3, Srot_t1_int_not_bidir_do_not_boost ; Limit to 11-bit maximum
    mov  Temp4, #0FFh
    mov  Temp5, #07h

Srot_t1_int_not_bidir_do_not_boost:
    ; Do not boost when changing direction in bidirectional mode
    jb   Flag_Motor_Started, Srot_t1_int_startup_boosted

    ; Boost pwm during direct start
    jnb  Flag_Initial_Run_Phase, Srot_t1_int_startup_boosted

    mov  A, Temp5
    jnz  Srot_t1_int_stall_boost             ; Already more power than minimum at startup

    mov  Temp2, #Srot_pgm_startup_power_min  ; Read minimum startup power setting
    mov  B, @Temp2

    clr  C                              ; Set power to at least be minimum startup power
    mov  A, Temp4
    subb A, B
    jnc  Srot_t1_int_stall_boost
    mov  Temp4, B

Srot_t1_int_stall_boost:
    mov  A, Srot_startup_stall_cnt           ; Check stall count
    jz   Srot_t1_int_startup_boosted
    mov  B, #40                         ; NOTE: Stall count should be less than 6
    mul  AB

    add  A, Temp4                       ; Increase power when motor fails to start (stalling)
    mov  Temp4, A
    mov  A, Temp5
    addc A, #0
    mov  Temp5, A
    jnb  ACC.3, Srot_t1_int_startup_boosted  ; Limit to 11-bit maximum
    mov  Temp4, #0FFh
    mov  Temp5, #07h

Srot_t1_int_startup_boosted:
    ; Set 8-bit value
    mov  A, Temp4
    anl  A, #0F8h
    orl  A, Temp5                       ; Assumes Temp5 to be 3-bit (11-bit RC pulse)
    swap A
    rl   A
    mov  Temp2, A

    jnz  Srot_t1_int_rcp_not_zero

    mov  A, Temp4                       ; Only set Rcp_Stop if all all 11 bits are zero
    jnz  Srot_t1_int_rcp_not_zero

    setb Flag_Rcp_Stop
    sjmp Srot_t1_int_zero_rcp_checked

Srot_t1_int_rcp_not_zero:
    mov  Srot_rcp_stop_cnt, #0               ; Reset RC pulse stop counter
    clr  Flag_Rcp_Stop                  ; Pulse ready

Srot_t1_int_zero_rcp_checked:
    ; Decrement outside range counter
    mov  A, Srot_rcp_outside_range_cnt
    jz   Srot_t1_int_zero_rcp_checked_set_limit
    dec  Srot_rcp_outside_range_cnt

Srot_t1_int_zero_rcp_checked_set_limit:
    ; Set pwm limit
    clr  C
    mov  A, Srot_pwm_limit                   ; Limit to the smallest
    mov  Temp6, A                       ; Store limit in Temp6
    subb A, Srot_pwm_limit_by_rpm
    jc   Srot_t1_int_zero_rcp_checked_check_limit
    mov  Temp6, Srot_pwm_limit_by_rpm

Srot_t1_int_zero_rcp_checked_check_limit:
    ; Check against limit
    clr  C
    mov  A, Temp6
    subb A, Temp2                       ; 8-bit rc pulse
    jnc  Srot_t1_int_scale_pwm_resolution

IF PWM_BITS_H == PWM_8_BIT              ; 8-bit pwm
    mov  A, Temp6
    mov  Temp2, A
ELSE
    mov  A, Temp6                       ; Multiply limit by 8 for 11-bit pwm
    mov  B, #8
    mul  AB
    mov  Temp4, A
    mov  Temp5, B
ENDIF

Srot_t1_int_scale_pwm_resolution:
; Scale pwm resolution and invert (duty cycle is defined inversely)
IF PWM_BITS_H == PWM_11_BIT
    mov  A, Temp5
    cpl  A
    anl  A, #7
    mov  Temp3, A
    mov  A, Temp4
    cpl  A
    mov  Temp2, A
ELSEIF PWM_BITS_H == PWM_10_BIT
    clr  C
    mov  A, Temp5
    rrc  A
    cpl  A
    anl  A, #3
    mov  Temp3, A
    mov  A, Temp4
    rrc  A
    cpl  A
    mov  Temp2, A
ELSEIF PWM_BITS_H == PWM_9_BIT
    mov  B, Temp5
    mov  A, Temp4
    mov  C, B.0
    rrc  A
    mov  C, B.1
    rrc  A
    cpl  A
    mov  Temp2, A
    mov  A, Temp5
    rr   A
    rr   A
    cpl  A
    anl  A, #1
    mov  Temp3, A
ELSEIF PWM_BITS_H == PWM_8_BIT
    mov  A, Temp2                       ; Temp2 already 8-bit
    cpl  A
    mov  Temp2, A
    mov  Temp3, #0
ENDIF

Srot_t1_int_set_pwm:
; Set PWM registers
IF DEADTIME != 0
    ; Subtract dead time from normal pwm and store as damping PWM
    ; Damping PWM duty cycle will be higher because numbers are inverted
    clr  C
    mov  A, Temp2                       ; Skew damping FET timing
IF MCU_TYPE == MCU_BB1
    subb A, #((DEADTIME + 1) SHR 1)
ELSE
    subb A, #(DEADTIME)
ENDIF
    mov  Temp4, A
    mov  A, Temp3
    subb A, #0
    mov  Temp5, A
    jnc  Srot_t1_int_max_braking_set

    clr  A                              ; Set to minimum value
    mov  Temp4, A
    mov  Temp5, A
    sjmp Srot_t1_int_pwm_braking_set         ; Max braking is already zero - branch

Srot_t1_int_max_braking_set:
    clr  C
    mov  A, Temp4
    subb A, Srot_pwm_braking_l
    mov  A, Temp5
    subb A, Srot_pwm_braking_h               ; Is braking pwm more than maximum allowed braking?
    jc   Srot_t1_int_pwm_braking_set         ; Yes - branch
    mov  Temp4, Srot_pwm_braking_l           ; No - set desired braking instead
    mov  Temp5, Srot_pwm_braking_h

Srot_t1_int_pwm_braking_set:
ENDIF

; NOTE: Interrupts are not explicitly disabled. Assume higher priority
;       interrupts (Int0, Timer0) to be disabled at this point.
IF PWM_BITS_H != PWM_8_BIT
    ; Set power pwm auto-reload registers
    Set_Power_Pwm_Reg_L Temp2
    Set_Power_Pwm_Reg_H Temp3
ELSE
    Set_Power_Pwm_Reg_H Temp2
ENDIF

IF DEADTIME != 0
    ; Set damp pwm auto-reload registers
IF PWM_BITS_H != PWM_8_BIT
    Set_Damp_Pwm_Reg_L Temp4
    Set_Damp_Pwm_Reg_H Temp5
ELSE
    Set_Damp_Pwm_Reg_H Temp4
ENDIF
ENDIF

    mov  Srot_rcp_timeout_cntd, #10          ; Set timeout count

    ; Prepare DShot telemetry
    jnb  Flag_Rcp_DShot_Inverted, Srot_t1_int_exit_no_tlm ; Only send telemetry for inverted DShot
    jnb  Flag_Telemetry_Pending, Srot_t1_int_exit_no_tlm ; Check if telemetry packet is ready

    ; Prepare Timer0 for sending telemetry data
    mov  CKCON0, #01h                   ; Timer0 is system clock divided by 4
    mov  TMOD, #0A2h                    ; Timer0 runs free not gated by Int0

    ; Configure RTX_PIN for digital output
    setb RTX_BIT                        ; Default to high level
    orl  RTX_MDOUT, #(1 SHL RTX_PIN)    ; Set output mode to push-pull

    mov  Temp1, #0                      ; Set pointer to start

    ; NOTE: Delay must be large enough to ensure port is ready for output
    mov  TL0, Srot_dshot_gcr_start_delay     ; Telemetry will begin after this delay
    clr  TCON_TF0                       ; Clear Timer0 overflow flag
    setb IE_ET0                         ; Enable Timer0 interrupts

    sjmp Srot_t1_int_exit_no_int

Srot_t1_int_exit_no_tlm:
    mov  Temp1, #0                      ; Set pointer to start
    mov  TL0, #0                        ; Reset Timer0
    setb IE_EX0                         ; Enable Int0 interrupts
    setb IE_EX1                         ; Enable Int1 interrupts

Srot_t1_int_exit_no_int:
    pop  B                              ; Restore preserved registers
    pop  ACC
    pop  PSW
    reti

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Timer2 interrupt routine
;
; Happens every 32ms before arming and every 16 ms after arming (on 48MHz MCUs)
;
; Tasks:
; - Update RC pulse timeout
; - Update stop counters
;
; ASSERT:
; - No PSW instructions
; - Mp usage of Temp registers
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_t2_int:
    push ACC                            ; Preserve registers
    clr  TMR2CN0_TF2H                   ; Clear interrupt flag
    inc  Srot_timer2_x                       ; Increment extended byte
    setb Flag_16ms_Elapsed              ; Set 16ms elapsed flag

    ; Check RC pulse timeout counter
    mov  A, Srot_rcp_timeout_cntd            ; RC pulse timeout count zero?
    jnz  Srot_t2_int_rcp_timeout_decrement
    setb Flag_Rcp_Stop                  ; If zero -> Set rcp stop in case of timeout
    sjmp Srot_t2_int_flag_rcp_stop_check

Srot_t2_int_rcp_timeout_decrement:
    dec  Srot_rcp_timeout_cntd               ; No - decrement

Srot_t2_int_flag_rcp_stop_check:
    ; If rc pulse is not zero
    jnb  Flag_Rcp_Stop, Srot_t2_int_exit     ; If rc pulse is not zero don't increment rcp stop counter

    ; Increment Rcp_Stop_Cnt clipping it to 255
    mov  A, Srot_rcp_stop_cnt
    inc  A
    jz   Srot_t2_int_exit
    inc  Srot_rcp_stop_cnt

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Return from timer2
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_t2_int_exit:
    pop  ACC                            ; Restore preserved registers
    reti

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Timer3 interrupt routine
;
; Tasks:
; - Commutation timing
;
; ASSERT:
; - No PSW instructions
; - No usage of Temp/Acc/B registers
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_t3_int:
    clr  IE_EA                          ; Disable all interrupts
    anl  EIE1, #7Fh                     ; Disable Timer3 interrupts
    anl  TMR3CN0, #07Fh                 ; Clear Timer3 interrupt flag
    mov  TMR3RLL, #0FAh                 ; Short delay to avoid re-loading regular delay
    mov  TMR3RLH, #0FFh
    clr  Flag_Timer3_Pending            ; Flag that timer has wrapped
    setb IE_EA                          ; Enable all interrupts
    reti

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Int0 interrupt routine (High priority)
;
; Tasks:
;  - Read and store DShot PWM signal for decoding
;
; ASSERT:
; - No PSW instructions
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_int0_int:
    push ACC
    mov  A, TL0                         ; Read PWM for DShot immediately
    mov  TL1, Srot_dshot_timer_preset        ; Reset sync timer

    ; Temp1 in register bank 1 points to PWM timings
    push PSW
    mov  PSW, #8h
    movx @Temp1, A                      ; Store PWM in external memory
    inc  Temp1
    pop  PSW

    pop  ACC
    reti

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Int1 interrupt routine
;
; Tasks:
; - RC pulse timing
;
; ASSERT:
; - No PSW instructions
; - No Temp/Acc registers
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_int1_int:
    clr  IE_EX1                         ; Disable Int1 interrupts
    setb TCON_TR1                       ; Start Timer1

    ; NOTE: Interrupts are not explicitly disabled, assuming higher priority
    ;       interrupts:
    ;       - Timer0 to be disabled at this point
    ;       - Int0 to not trigger for valid DShot signal
    clr  TMR2CN0_TR2                    ; Timer2 disabled
    mov  Srot_dshot_frame_start_l, TMR2L     ; Read timer value
    mov  Srot_dshot_frame_start_h, TMR2H
    setb TMR2CN0_TR2                    ; Timer2 enabled
    reti

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; PCA interrupt routine
;
; Update pwm registers according to PCA clock signal
;
; Requirements: No PSW instructions or Temp registers
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_pca_int:
    reti
