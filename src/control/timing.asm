; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft  2022-2023 Daniel Mosquera
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; Timing
;

;
; Timing
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Initialize timing
;
; Part of initialization before motor start
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_initialize_timing:
    ; Initialize commutation period to 7.5ms (~1330 erpm)
    mov  Srot_comm_period4x_l, #00h
    mov  Srot_comm_period4x_h, #0F0h
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Calculate next commutation period
;
; Measure the duration of current commutation period,
; and update Comm_Period4x by averaging a fraction of it.
;
; Called immediately after each commutation
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_calc_next_comm_period:
    ; Read commutation time
    clr  IE_EA                          ; Disable all interrupts
    clr  TMR2CN0_TR2                    ; Disable Timer2
    mov  Temp1, TMR2L                   ; Load Timer2 value
    mov  Temp2, TMR2H
    mov  Temp3, Srot_timer2_x
    jnb  TMR2CN0_TF2H,Srot_calc_next_comm_period_enable_timer2 ; Check if interrupt is pending
    inc  Temp3                          ; If it is pending,then timer has already wrapped

Srot_calc_next_comm_period_enable_timer2:
    setb TMR2CN0_TR2                    ; Timer2 enabled
    setb IE_EA

; Divide time by 2 on 48MHz
IF MCU_TYPE == MCU_BB2 or MCU_TYPE == MCU_BB51
    clr  C
    rrca Temp3
    rrca Temp2
    rrca Temp1
ENDIF

    jb   Flag_Startup_Phase, Srot_calc_next_comm_startup

    ; Calculate this commutation time
    clr  C
    mov  A, Temp1
    subb A, Srot_prev_comm_l                 ; Calculate the new commutation time
    mov  Srot_prev_comm_l, Temp1             ; Save timestamp as previous commutation
    mov  Temp1, A                       ; Store commutation period in Temp1 (lo byte)
    mov  A, Temp2
    subb A, Srot_prev_comm_h
    mov  Srot_prev_comm_h, Temp2             ; Save timestamp as previous commutation
IF MCU_TYPE == MCU_BB2 or MCU_TYPE == MCU_BB51
    anl  A, #7Fh
ENDIF
    mov  Temp2, A                       ; Store commutation period in Temp2 (hi byte)

    jnb  Flag_High_Rpm, Srot_calc_next_comm_normal ; Branch normal RPM
    ajmp Srot_calc_next_comm_period_fast     ; Branch high RPM

Srot_calc_next_comm_startup:
    ; Calculate this commutation time
    mov  Temp4, Srot_prev_comm_l
    mov  Temp5, Srot_prev_comm_h
    mov  Temp6, Srot_prev_comm_x
    mov  Srot_prev_comm_l, Temp1             ; Store timestamp as previous commutation
    mov  Srot_prev_comm_h, Temp2
    mov  Srot_prev_comm_x, Temp3             ; Store extended timestamp as previous commutation

    clr  C
    mov  A, Temp1
    subb A, Temp4                       ; Calculate the new commutation time
    mov  A, Temp2
    subb A, Temp5
    mov  A, Temp3
    subb A, Temp6                       ; Calculate the new extended commutation time
IF MCU_TYPE == MCU_BB2 or MCU_TYPE == MCU_BB51
    anl  A, #7Fh
ENDIF
    jz   Srot_calc_next_comm_startup_no_x

    ; Extended byte is not zero, so commutation time is above 0xFFFF
    mov  Srot_comm_period4x_l, #0FFh
    mov  Srot_comm_period4x_h, #0FFh
    ajmp Srot_calc_next_comm_done

Srot_calc_next_comm_startup_no_x:
    ; Extended byte = 0, so commutation time fits within two bytes
    mov  Temp7, Srot_prev_prev_comm_l
    mov  Temp8, Srot_prev_prev_comm_h
    mov  Srot_prev_prev_comm_l, Temp4
    mov  Srot_prev_prev_comm_h, Temp5

    ; Calculate the new commutation time based upon the two last commutations (to reduce sensitivity to offset)
    clr  C
    mov  A, Temp1
    subb A, Temp7
    mov  Temp1, A
    mov  A, Temp2
    subb A, Temp8
    mov  Temp2, A

    mov  Temp3, Srot_comm_period4x_l         ; Comm_Period4x holds the time of 4 commutations
    mov  Temp4, Srot_comm_period4x_h

    sjmp Srot_calc_next_comm_div_4_1

Srot_calc_next_comm_normal:
    ; Prepare averaging by dividing Comm_Period4x and current commutation period (Temp2/1) according to speed.
    mov  Temp3, Srot_comm_period4x_l         ; Comm_Period4x holds the time of 4 commutations
    mov  Temp4, Srot_comm_period4x_h

    clr  C
    mov  A, Temp4

    subb A, #4                          ; Is Comm_Period4x_H below 4? (above ~80k erpm)
    jc   Srot_calc_next_comm_div_16_4        ; Yes - Use averaging for high speeds

    subb A, #4                          ; Is Comm_Period4x_H below 8? (above ~40k erpm)
    jc   Srot_calc_next_comm_div_8_2         ; Yes - Use averaging for low speeds

    ; No - Use averaging for even lower speeds

    ; Do not average very fast during initial run
    jb   Flag_Initial_Run_Phase, Srot_calc_next_comm_div_8_2_slow

; Update Comm_Period4x from 1 new commutation period
Srot_calc_next_comm_div_4_1:
    ; Divide Temp4/3 by 4 and store in Temp6/5
    Divide_By_4 Temp4, Temp3, Temp6, Temp5

    sjmp Srot_calc_next_comm_average_and_update

; Update Comm_Period4x from 1/2 new commutation period
Srot_calc_next_comm_div_8_2:
    ; Divide Temp4/3 by 8 and store in Temp5
    Divide_11Bit_By_8 Temp4, Temp3, Temp5
    mov  Temp6, #0

    Divide_16Bit_By_2 Temp2, Temp1

    sjmp Srot_calc_next_comm_average_and_update

; Update Comm_Period4x from 1/2 new commutation period
Srot_calc_next_comm_div_8_2_slow:
    ; Divide Temp4/3 by 8 and store in Temp6/5
    Divide_By_8 Temp4, Temp3, Temp6, Temp5

    Divide_16Bit_By_2 Temp2, Temp1

    sjmp Srot_calc_next_comm_average_and_update

; Update Comm_Period4x from 1/4 new commutation period
Srot_calc_next_comm_div_16_4:
    ; Divide Temp4/3 by 16 and store in Temp5
    Divide_12Bit_By_16 Temp4, Temp3, Temp5
    mov  Temp6, #0

    ; Divide Temp2/1 by 4 and store in Temp2/1
    Divide_By_4 Temp2, Temp1, Temp2, Temp1

Srot_calc_next_comm_average_and_update:
    ; Comm_Period4x = Comm_Period4x - (Comm_Period4x / (16, 8 or 4)) + (Comm_Period / (4, 2 or 1))

    ; Temp6/5: Comm_Period4x divided by (16, 8 or 4)
    clr  C                              ; Subtract a fraction
    mov  A, Temp3                       ; Comm_Period4x_L
    subb A, Temp5
    mov  Temp3, A
    mov  A, Temp4                       ; Comm_Period4x_H
    subb A, Temp6
    mov  Temp4, A

    ; Temp2/1: This commutation period divided by (4, 2 or 1)
    mov  A, Temp3                       ; Add the divided new time
    add  A, Temp1
    mov  Srot_comm_period4x_l, A
    mov  A, Temp4
    addc A, Temp2
    mov  Srot_comm_period4x_h, A

    jnc  Srot_calc_next_comm_done            ; Is period larger than 0xffff?
    mov  Srot_comm_period4x_l, #0FFh         ; Yes - Set commutation period registers to very slow timing (0xffff)
    mov  Srot_comm_period4x_h, #0FFh

Srot_calc_next_comm_done:
    clr  C
    mov  A, Srot_comm_period4x_h
    subb A, #2                          ; Is Comm_Period4x_H below 2? (above ~160k erpm)
    jnc  Srot_calc_next_comm_15deg
    setb Flag_High_Rpm                  ; Yes - Set high rpm flag

Srot_calc_next_comm_15deg:
    ; Commutation period: 360 deg / 6 runs = 60 deg
    ; 60 deg / 4 = 15 deg

    ; Load current commutation timing and compute 15 deg timing
    ; Divide Comm_Period4x by 16 (Comm_Period1x divided by 4) and store in Temp4/3
    Divide_By_16 Srot_comm_period4x_h, Srot_comm_period4x_l, Temp4, Temp3

    ; Subtract timing reduction
    clr  C
    mov  A, Temp3
    subb A, #2                          ; Set timing reduction
    mov  Temp3, A
    mov  A, Temp4
    subb A, #0
    mov  Temp4, A

    jc   Srot_calc_next_comm_15deg_set_min   ; Check that result is still positive
    jnz  Srot_calc_next_comm_period_exit     ; Check that result is still above minimum
    mov  A, Temp3
    jnz  Srot_calc_next_comm_period_exit

Srot_calc_next_comm_15deg_set_min:
    mov  Temp3, #1                      ; Set minimum waiting time (Timers cannot wait for a delay of 0)
    mov  Temp4, #0

    sjmp Srot_calc_next_comm_period_exit

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Calculate next commutation period (fast)
; Fast calculation (Comm_Period4x_H less than 2)
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_calc_next_comm_period_fast:
    ; Calculate new commutation time
    mov  Temp3, Srot_comm_period4x_l         ; Comm_Period4x holds the time of 4 commutations
    mov  Temp4, Srot_comm_period4x_h

    ; Divide by 16 and store in Temp5
    Divide_12Bit_By_16 Temp4, Temp3, Temp5

    clr  C
    mov  A, Temp3                       ; Subtract a fraction
    subb A, Temp5
    mov  Temp3, A
    mov  A, Temp4
    subb A, #0
    mov  Temp4, A

    ; NOTE: Temp2 is assumed to be zero (approx. Comm_Period4x_H / 4)
    mov  A, Temp1                       ; Divide by 4
    rr   A
    rr   A
    anl  A, #03Fh

    add  A, Temp3                       ; Add the divided new time
    mov  Temp3, A
    mov  A, Temp4
    addc A, #0
    mov  Temp4, A

    mov  Srot_comm_period4x_l, Temp3         ; Store Comm_Period4x
    mov  Srot_comm_period4x_h, Temp4

    clr  C
    subb A, #2                          ; Is Comm_Period4x_H 2 or more? (below ~160k erpm)
    jc   Srot_calc_next_comm_period_fast_div_comm_perio4x_by_16
    clr  Flag_High_Rpm                  ; Yes - Clear high rpm bit

Srot_calc_next_comm_period_fast_div_comm_perio4x_by_16:
    mov  A, Temp4                       ; Divide Comm_Period4x by 16 and store in Temp4/3
    swap A
    mov  Temp7, A
    mov  Temp4, #0                      ; Clear waiting time high byte
    mov  A, Temp3
    swap A
    anl  A, #0Fh
    orl  A, Temp7
    clr  C
    subb A, #2                          ; Timing reduction
    mov  Temp3, A
    jc   Srot_calc_next_comm_fast_set_min    ; Check that result is still positive
    jnz  Srot_calc_next_comm_period_exit     ; Check that result is still above minimum

Srot_calc_next_comm_fast_set_min:
    mov  Temp3, #1                      ; Set minimum waiting time (Timers cannot wait for a delay of 0)

Srot_calc_next_comm_period_exit:

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait advance timing
;
; Waits for the advance timing to elapse
;
; NOTE: Be VERY careful if using temp registers. They are passed over this routine
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_wait_advance_timing:
    ; If it has not already, we wait here for the Wt_Adv_Start_ delay to elapse.
    Wait_For_Timer3

    ; At this point Timer3 has (already) wrapped and been reloaded with the Wt_Zc_Scan_Start_ delay.
    ; In case this delay has also elapsed, Timer3 has been reloaded with a short delay any number of times.
    ; - The interrupt flag is set and the pending flag will clear immediately after enabling the interrupt.
    mov  TMR3RLL, Srot_wt_zc_tout_start_l    ; Setup next wait time
    mov  TMR3RLH, Srot_wt_zc_tout_start_h
    setb Flag_Timer3_Pending
    orl  EIE1, #80h                     ; Enable Timer3 interrupts

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Calculate new wait times
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_calc_new_wait_times:
    mov  Temp1, #Srot_pgm_comm_timing        ; Load commutation timing setting
    mov  A, @Temp1
    mov  Temp8, A                       ; Store in Temp8

    clr  C
    clr  A
    subb A, Temp3                       ; Negate
    mov  Temp1, A
    clr  A
    subb A, Temp4
    mov  Temp2, A
IF MCU_TYPE == MCU_BB2 or MCU_TYPE == MCU_BB51
    clr  C
    rlca Temp1                          ; Multiply by 2
    rlca Temp2
ENDIF

    ; Temp2/1 = 15deg Timer2 period
    jb   Flag_High_Rpm, Srot_calc_new_wait_times_fast ; Branch if high rpm

    ; Load programmed commutation timing
    jnb  Flag_Startup_Phase, Srot_adjust_comm_timing

    mov  Temp8, #3                      ; Set dedicated timing during startup
    sjmp Srot_load_comm_timing_done

Srot_adjust_comm_timing:
    ; Adjust commutation timing according to demag metric
    clr  C
    mov  A, Srot_demag_detected_metric       ; Check demag metric
    subb A, #130
    jc   Srot_load_comm_timing_done

    inc  Temp8                          ; Increase timing (if metric 130 or above)

    subb A, #30
    jc   Srot_adjust_comm_timing_limit_to_max

    inc  Temp8                          ; Increase timing again (if metric 160 or above)

Srot_adjust_comm_timing_limit_to_max:
    clr  C
    mov  A, Temp8                       ; Limit timing to max
    subb A, #6
    jc   Srot_load_comm_timing_done

    mov  Temp8, #5                      ; Set timing to max (if timing 6 or above)

Srot_load_comm_timing_done:
    mov  A, Temp1                       ; Copy values
    mov  Temp3, A
    mov  A, Temp2
    mov  Temp4, A

    setb C                              ; Negative numbers - set carry
    mov  A, Temp2                       ; Store 7.5deg in Temp5/6 (15deg / 2)
    rrc  A
    mov  Temp6, A
    mov  A, Temp1
    rrc  A
    mov  Temp5, A

    mov  Srot_wt_zc_scan_start_l, Temp5      ; Set 7.5deg time for zero cross scan delay
    mov  Srot_wt_zc_scan_start_h, Temp6
    mov  Srot_wt_zc_tout_start_l, Temp1      ; Set 15deg time for zero cross scan timeout
    mov  Srot_wt_zc_tout_start_h, Temp2

    clr  C
    mov  A, Temp8                       ; (Temp8 has Pgm_Comm_Timing)
    subb A, #3                          ; Is timing normal?
    jz   Srot_store_times_decrease           ; Yes - branch

    mov  A, Temp8
    jb   ACC.0, Srot_adjust_timing_two_steps ; If an odd number - branch

    ; Commutation timing setting is 2 or 4
    mov  A, Temp1                       ; Store 22.5deg in Temp1/2 (15deg + 7.5deg)
    add  A, Temp5
    mov  Temp1, A
    mov  A, Temp2
    addc A, Temp6
    mov  Temp2, A

    mov  A, Temp5                       ; Store 7.5deg in Temp3/4
    mov  Temp3, A
    mov  A, Temp6
    mov  Temp4, A

    sjmp Srot_store_times_up_or_down

Srot_adjust_timing_two_steps:
    ; Commutation timing setting is 1 or 5
    mov  A, Temp1                       ; Store 30deg in Temp1/2 (15deg + 15deg)
    setb C                              ; Add 1 to final result (Temp1/2 * 2 + 1)
    addc A, Temp1
    mov  Temp1, A
    mov  A, Temp2
    addc A, Temp2
    mov  Temp2, A

    mov  Temp3, #-1                     ; Store minimum time (0deg) in Temp3/4
    mov  Temp4, #-1

Srot_store_times_up_or_down:
    clr  C
    mov  A, Temp8
    subb A, #3                          ; Is timing higher than normal?
    jc   Srot_store_times_decrease           ; No - branch

Srot_store_times_increase:
    mov  Srot_wt_comm_start_l, Temp3         ; Now commutation time (~60deg) divided by 4 (~15deg nominal)
    mov  Srot_wt_comm_start_h, Temp4
    mov  Srot_wt_adv_start_l, Temp1          ; New commutation advance time (~15deg nominal)
    mov  Srot_wt_adv_start_h, Temp2
    sjmp Srot_calc_new_wait_times_exit

Srot_store_times_decrease:
    mov  Srot_wt_comm_start_l, Temp1         ; Now commutation time (~60deg) divided by 4 (~15deg nominal)
    mov  Srot_wt_comm_start_h, Temp2
    mov  Srot_wt_adv_start_l, Temp3          ; New commutation advance time (~15deg nominal)
    mov  Srot_wt_adv_start_h, Temp4

    ; Set very short delays for all but advance time during startup, in order to widen zero cross capture range
    jnb  Flag_Startup_Phase, Srot_calc_new_wait_times_exit
    mov  Srot_wt_comm_start_l, #-16
    mov  Srot_wt_comm_start_h, #-1
    mov  Srot_wt_zc_scan_start_l, #-16
    mov  Srot_wt_zc_scan_start_h, #-1
    mov  Srot_wt_zc_tout_start_l, #-16
    mov  Srot_wt_zc_tout_start_h, #-1

    sjmp Srot_calc_new_wait_times_exit

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Calculate new wait times fast routine
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_calc_new_wait_times_fast:
    mov  A, Temp1                       ; Copy values
    mov  Temp3, A
    setb C                              ; Negative numbers - set carry
    rrc  A                              ; Divide by 2
    mov  Temp5, A

    mov  Srot_wt_zc_scan_start_l, Temp5      ; Use this value for zero cross scan delay (7.5deg)
    mov  Srot_wt_zc_tout_start_l, Temp1      ; Set 15deg time for zero cross scan timeout

    clr  C
    mov  A, Temp8                       ; (Temp8 has Pgm_Comm_Timing)
    subb A, #3                          ; Is timing normal?
    jz   Srot_store_times_decrease_fast      ; Yes - branch

    mov  A, Temp8
    jb   ACC.0, Srot_adjust_timing_two_steps_fast ; If an odd number - branch

    mov  A, Temp1                       ; Add 7.5deg and store in Temp1
    add  A, Temp5
    mov  Temp1, A
    mov  A, Temp5                       ; Store 7.5deg in Temp3
    mov  Temp3, A
    sjmp Srot_store_times_up_or_down_fast

Srot_adjust_timing_two_steps_fast:
    mov  A, Temp1                       ; Add 15deg and store in Temp1
    add  A, Temp1
    add  A, #1
    mov  Temp1, A
    mov  Temp3, #-1                     ; Store minimum time in Temp3

Srot_store_times_up_or_down_fast:
    clr  C
    mov  A, Temp8
    subb A, #3                          ; Is timing higher than normal?
    jc   Srot_store_times_decrease_fast      ; No - branch

Srot_store_times_increase_fast:
    mov  Srot_wt_comm_start_l, Temp3         ; Now commutation time (~60deg) divided by 4 (~15deg nominal)
    mov  Srot_wt_adv_start_l, Temp1          ; New commutation advance time (~15deg nominal)
    sjmp Srot_calc_new_wait_times_exit

Srot_store_times_decrease_fast:
    mov  Srot_wt_comm_start_l, Temp1         ; Now commutation time (~60deg) divided by 4 (~15deg nominal)
    mov  Srot_wt_adv_start_l, Temp3          ; New commutation advance time (~15deg nominal)

Srot_calc_new_wait_times_exit:

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait before zero cross scan
;
; Waits for the zero cross scan wait time to elapse
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_wait_before_zc_scan:
    ; If it has not already, we wait here for the Wt_Zc_Scan_Start_ delay to elapse.
    Wait_For_Timer3

    ; At this point Timer3 has (already) wrapped and been reloaded with the Wt_ZC_Tout_Start_ delay.
    ; In case this delay has also elapsed, Timer3 has been reloaded with a short delay any number of times.
    ; - The interrupt flag is set and the pending flag will clear immediately after enabling the interrupt.
    mov  Srot_startup_zc_timeout_cntd, #2

Srot_setup_zc_scan_timeout:
    setb Flag_Timer3_Pending
    orl  EIE1, #80h                     ; Enable Timer3 interrupts

    jnb  Flag_Initial_Run_Phase, Srot_wait_before_zc_scan_exit

    mov  Temp1, Srot_comm_period4x_l         ; Set long timeout when starting
    mov  Temp2, Srot_comm_period4x_h
    Divide_16Bit_By_2 Temp2, Temp1
IF MCU_TYPE == MCU_BB1
    Divide_16Bit_By_2 Temp2, Temp1
ENDIF
    jnb  Flag_Startup_Phase, Srot_setup_zc_scan_timeout_startup_done

    mov  A, Temp2
    add  A, #40h                        ; Increase timeout somewhat to avoid false wind up
    mov  Temp2, A

Srot_setup_zc_scan_timeout_startup_done:
    clr  IE_EA
    anl  EIE1, #7Fh                     ; Disable Timer3 interrupts
    mov  TMR3CN0, #00h                  ; Timer3 disabled and interrupt flag cleared
    clr  C
    clr  A
    subb A, Temp1                       ; Set timeout
    mov  TMR3L, A
    clr  A
    subb A, Temp2
    mov  TMR3H, A
    mov  TMR3CN0, #04h                  ; Timer3 enabled and interrupt flag cleared
    setb Flag_Timer3_Pending
    orl  EIE1, #80h                     ; Enable Timer3 interrupts
    setb IE_EA

Srot_wait_before_zc_scan_exit:
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait for comparator to go low/high
;
; Scans for comparator going low/high
; Exit if zero cross timeout has elapsed
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_wait_for_comp_out_low:
    mov  B, #00h                        ; Desired comparator output
    jnb  Flag_Dir_Change_Brake, Srot_comp_init
    mov  B, #40h
    sjmp Srot_comp_init

Srot_wait_for_comp_out_high:
    mov  B, #40h                        ; Desired comparator output
    jnb  Flag_Dir_Change_Brake, Srot_comp_init
    mov  B, #00h

Srot_comp_init:
    setb Flag_Demag_Detected            ; Set demag detected flag as default
    mov  Srot_comparator_read_cnt, #0        ; Reset number of comparator reads

Srot_comp_start:
    ; Set number of comparator readings required
    mov  Temp3, #(1 SHL IS_MCU_48MHZ)   ; Number of OK readings required
    mov  Temp4, #(1 SHL IS_MCU_48MHZ)   ; Max number of readings required
    jb   Flag_High_Rpm, Srot_comp_check_timeout ; Branch if high rpm

    jnb  Flag_Initial_Run_Phase, Srot_comp_start_check_startup_phase
    clr  Flag_Demag_Detected            ; Clear demag detected flag if start phases

Srot_comp_start_check_startup_phase:
    jnb  Flag_Startup_Phase, Srot_comp_not_startup
    mov  Temp3, #(27 SHL IS_MCU_48MHZ)  ; Set many samples during startup,approximately one pwm period
    mov  Temp4, #(27 SHL IS_MCU_48MHZ)
    sjmp Srot_comp_check_timeout

Srot_comp_not_startup:
    ; Too low value (~<15) causes rough running at pwm harmonics.
    ; Too high a value (~>35) causes the RCT4215 630 to run rough on full throttle
    mov  Temp4, #(20 SHL IS_MCU_48MHZ)
    mov  A, Srot_comm_period4x_h             ; Set number of readings higher for lower speeds
IF MCU_TYPE == MCU_BB1
    clr  C
    rrc  A
ENDIF
    jnz  Srot_comp_not_startup_check_ok_readings
    inc  A                              ; Minimum 1

Srot_comp_not_startup_check_ok_readings:
    mov  Temp3, A
    clr  C
    subb A, #(20 SHL IS_MCU_48MHZ)
    jc   Srot_comp_check_timeout
    mov  Temp3, #(20 SHL IS_MCU_48MHZ)  ; Maximum 20

Srot_comp_check_timeout:
    jb   Flag_Timer3_Pending, Srot_comp_check_timeout_not_timed_out ; Has zero cross scan timeout elapsed?

    mov  A, Srot_comparator_read_cnt         ; Check that comparator has been read
    jz   Srot_comp_check_timeout_not_timed_out ; If not yet read - ignore zero cross timeout

    jnb  Flag_Startup_Phase, Srot_comp_check_timeout_timeout_extended

    ; Extend timeout during startup
    djnz Srot_startup_zc_timeout_cntd, Srot_comp_check_timeout_extend_timeout

Srot_comp_check_timeout_timeout_extended:
    setb Flag_Comp_Timed_Out
    sjmp Srot_comp_exit

Srot_comp_check_timeout_extend_timeout:
    call Srot_setup_zc_scan_timeout

Srot_comp_check_timeout_not_timed_out:
    inc  Srot_comparator_read_cnt            ; Increment comparator read count
    Read_Comparator_Output
    anl  A, #40h
    cjne A, B, Srot_comp_read_wrong

    ; Comp read ok
    mov  A, Srot_startup_cnt                 ; Force a timeout for the first commutation
    jz   Srot_comp_start

    jb   Flag_Demag_Detected, Srot_comp_start ; Do not accept correct comparator output if it is demag

    djnz Temp3, Srot_comp_check_timeout      ; Decrement readings counter - repeat comparator reading if not zero

    clr  Flag_Comp_Timed_Out
    sjmp Srot_comp_exit

Srot_comp_read_wrong:
    jb   Flag_Startup_Phase, Srot_comp_read_wrong_startup
    jb   Flag_Demag_Detected, Srot_comp_read_wrong_extend_timeout

    inc  Temp3                          ; Increment number of OK readings required
    clr  C
    mov  A, Temp3
    subb A, Temp4
    jc   Srot_comp_check_timeout             ; If below initial requirement - take another reading
    sjmp Srot_comp_start                     ; Otherwise - go back and restart

Srot_comp_read_wrong_startup:
    inc  Temp3                          ; Increment number of OK readings required
    clr  C
    mov  A, Temp3
    subb A, Temp4                       ; If above initial requirement - do not increment further
    jc   Srot_comp_read_wrong_startup_jump   ; TODO: Skip this jump to optimize
    dec  Temp3

Srot_comp_read_wrong_startup_jump:
    sjmp Srot_comp_check_timeout             ; Continue to look for good ones

Srot_comp_read_wrong_extend_timeout:
    clr  Flag_Demag_Detected            ; Clear demag detected flag
    anl  EIE1, #7Fh                     ; Disable Timer3 interrupts
    mov  TMR3CN0, #00h                  ; Timer3 disabled and interrupt flag cleared
    jnb  Flag_High_Rpm, Srot_comp_read_wrong_low_rpm ; Branch if not high rpm

    mov  TMR3L, #0                      ; Set timeout to ~1ms
    mov  TMR3H, #-(8 SHL IS_MCU_48MHZ)

Srot_comp_read_wrong_timeout_set:
    mov  TMR3CN0, #04h                  ; Timer3 enabled and interrupt flag cleared
    setb Flag_Timer3_Pending
    orl  EIE1, #80h                     ; Enable Timer3 interrupts
    ljmp Srot_comp_start                     ; If comparator output is not correct - go back and restart

Srot_comp_read_wrong_low_rpm:
    mov  A, Srot_comm_period4x_h             ; Set timeout to ~4x comm period 4x value
    mov  Temp7, #0FFh                   ; Default to long timeout

IF MCU_TYPE == MCU_BB2 or MCU_TYPE == MCU_BB51
    clr  C
    rlc  A
    jc   Srot_comp_read_wrong_load_timeout
ENDIF

    clr  C
    rlc  A
    jc   Srot_comp_read_wrong_load_timeout

    clr  C
    rlc  A
    jc   Srot_comp_read_wrong_load_timeout

    mov  Temp7, A

Srot_comp_read_wrong_load_timeout:
    clr  C
    clr  A
    subb A, Temp7
    mov  TMR3L, #0
    mov  TMR3H, A
    sjmp Srot_comp_read_wrong_timeout_set

Srot_comp_exit:

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Setup commutation timing
;
; Clear the zero cross timeout and sets up wait from zero cross to commutation
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_setup_comm_wait:
    clr  IE_EA
    anl  EIE1, #7Fh                     ; Disable Timer3 interrupts

    ; It is necessary to update the timer reload registers before the timer registers,
    ; to avoid a reload of the previous values in case of a short Wt_Comm_Start delay.

    ; Advance wait time will be loaded by Timer3 immediately after the commutation wait elapses
    mov  TMR3RLL, Srot_wt_adv_start_l        ; Setup next wait time
    mov  TMR3RLH, Srot_wt_adv_start_h
    mov  TMR3CN0, #00h                  ; Timer3 disabled and interrupt flag cleared
    mov  TMR3L, Srot_wt_comm_start_l
    mov  TMR3H, Srot_wt_comm_start_h
    mov  TMR3CN0, #04h                  ; Timer3 enabled and interrupt flag cleared

    setb Flag_Timer3_Pending
    orl  EIE1, #80h                     ; Enable Timer3 interrupts
    setb IE_EA                          ; Enable interrupts again

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Evaluate comparator integrity
;
; Checks comparator signal behavior versus expected behavior
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_evaluate_comparator_integrity:
    jb   Flag_Startup_Phase, Srot_eval_comp_startup ; Do not exit run mode during startup phases

    jnb  Flag_Comp_Timed_Out, Srot_eval_comp_exit ; Has timeout elapsed?
    jb   Flag_Initial_Run_Phase, Srot_eval_comp_exit ; Do not exit run mode if initial run phase
    jb   Flag_Dir_Change_Brake, Srot_eval_comp_exit ; Do not exit run mode if braking
    jb   Flag_Demag_Detected, Srot_eval_comp_exit ; Do not exit run mode if it is a demag situation

    ; Disable all interrupts and cut power ASAP. They will be enabled in exit_run_mode_on_timeout
    clr  IE_EA
    call Srot_switch_power_off

    ; Routine exit without "ret" command
    dec  SP
    dec  SP

    ; Go to exit run mode if timeout has elapsed
    ljmp Srot_exit_run_mode_on_timeout

Srot_eval_comp_startup:
    inc  Srot_startup_cnt                    ; Increment startup counter

Srot_eval_comp_exit:
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait for commutation
;
; Waits from zero cross to commutation
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_wait_for_comm:
    ; Update demag metric
    mov  A, Srot_demag_detected_metric       ; Sliding average of 8,256 when demag and 0 when not. Limited to minimum 120
    mov  B, #7
    mul  AB                             ; Multiply by 7

    jnb  Flag_Demag_Detected, Srot_wait_for_comm_demag_event_added
    ; Add new value for current demag status
    inc  B
    ; Signal demag
    setb Flag_Demag_Notify

Srot_wait_for_comm_demag_event_added:
    mov  C, B.0                         ; Divide by 8
    rrc  A
    mov  C, B.1
    rrc  A
    mov  C, B.2
    rrc  A
    mov  Srot_demag_detected_metric, A
    clr  C
    subb A, #120                        ; Limit to minimum 120
    jnc  Srot_wait_for_comm_update_demag_metric_max
    mov  Srot_demag_detected_metric, #120

Srot_wait_for_comm_update_demag_metric_max:
    ; Update demag metric max
    clr  C
    mov  A, Srot_demag_detected_metric
    subb A, Srot_demag_detected_metric_max
    jc   Srot_wait_for_comm_demag_metric_max_updated
    mov  Srot_demag_detected_metric_max, Srot_demag_detected_metric

Srot_wait_for_comm_demag_metric_max_updated:
    ; Check demag metric
    clr  C
    mov  A, Srot_demag_detected_metric
    subb A, Srot_demag_pwr_off_thresh
    jc   Srot_wait_for_comm_wait

    ; Signal desync
    setb Flag_Desync_Notify

    ; Cut power if many consecutive demags are detected.
    ; This will help retain sync during hard accelerations.
    All_Pwm_Fets_Off
    Set_All_Pwm_Phases_Off

Srot_wait_for_comm_wait:
    ; If it has not already, we wait for the Wt_Comm_Start_ delay to elapse.
    Wait_For_Timer3

    ; At this point Timer3 has (already) wrapped and been reloaded with
    ; the Wt_Adv_Start_ delay.
    ;
    ; In case this delay has also elapsed, Timer3 has been reloaded with a short
    ; delay any number of times.
    ; - The interrupt flag is set and the pending flag will clear immediately
    ;   after enabling the interrupt.
    mov  TMR3RLL, Srot_wt_zc_scan_start_l    ; Setup next wait time
    mov  TMR3RLH, Srot_wt_zc_scan_start_h
    setb Flag_Timer3_Pending
    orl  EIE1, #80h                     ; Enable Timer3 interrupts
    ret
