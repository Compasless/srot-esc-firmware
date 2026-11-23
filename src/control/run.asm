; Compasless SROT ESC firmware
; Six-step running loop, startup transition and reversal.
; Source architecture/refactor Copyright (C) 2026 Compasless contributors.
; Derived from Bluejay v0.21.0; original notices are preserved below.
; SPDX-License-Identifier: GPL-3.0-or-later
; Original source: Bluejay.asm
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Bluejay digital ESC firmware for controlling brushless motors in multirotors
;
; Copyleft  2022-2023 Daniel Mosquera
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
;
; This file is part of Bluejay.
;
; Bluejay is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; Bluejay is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with Bluejay.  If not, see <http://www.gnu.org/licenses/>.
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Bluejay is a fork of BLHeli_S <https://github.com/bitdump/BLHeli> by Steffen Skaug.
;

Srot_run1:
    call Srot_wait_for_comp_out_high         ; Wait for high
    ; setup_comm_wait                    ; Setup wait time from zero cross to commutation
    ; evaluate_comparator_integrity      ; Check whether comparator reading has been normal
    call Srot_wait_for_comm                  ; Wait from zero cross to commutation
    call Srot_comm1_comm2                    ; Commutate
    call Srot_calc_next_comm_period          ; Calculate next timing and wait advance timing wait
    ; wait_advance_timing                ; Wait advance timing and start zero cross wait
    ; calc_new_wait_times
    ; wait_before_zc_scan                ; Wait zero cross wait and start zero cross timeout

; Run 2 = A(p-on) + C(n-pwm) - comparator B evaluated
; Out_cB changes from high to low
Srot_run2:
    call Srot_wait_for_comp_out_low
    ; setup_comm_wait
    ; evaluate_comparator_integrity
    call Srot_set_pwm_limit                  ; Set pwm power limit for low or high rpm
    call Srot_wait_for_comm
    call Srot_comm2_comm3
    call Srot_calc_next_comm_period
    ; wait_advance_timing
    ; calc_new_wait_times
    ; wait_before_zc_scan

; Run 3 = A(p-on) + B(n-pwm) - comparator C evaluated
; Out_cC changes from low to high
Srot_run3:
    call Srot_wait_for_comp_out_high
    ; setup_comm_wait
    ; evaluate_comparator_integrity
    call Srot_wait_for_comm
    call Srot_comm3_comm4
    call Srot_calc_next_comm_period
    ; wait_advance_timing
    ; calc_new_wait_times
    ; wait_before_zc_scan

; Run 4 = C(p-on) + B(n-pwm) - comparator A evaluated
; Out_cA changes from high to low
Srot_run4:
    call Srot_wait_for_comp_out_low
    ; setup_comm_wait
    ; evaluate_comparator_integrity
    call Srot_wait_for_comm
    call Srot_comm4_comm5
    call Srot_calc_next_comm_period
    ; wait_advance_timing
    ; calc_new_wait_times
    ; wait_before_zc_scan

; Run 5 = C(p-on) + A(n-pwm) - comparator B evaluated
; Out_cB changes from low to high
Srot_run5:
    call Srot_wait_for_comp_out_high
    ; setup_comm_wait
    ; evaluate_comparator_integrity
    call Srot_wait_for_comm
    call Srot_comm5_comm6
    call Srot_calc_next_comm_period
    ; wait_advance_timing
    ; calc_new_wait_times
    ; wait_before_zc_scan

; Run 6 = B(p-on) + A(n-pwm) - comparator C evaluated
; Out_cC changes from high to low
Srot_run6:
    call Srot_wait_for_comp_out_low
    ; setup_comm_wait
    ; evaluate_comparator_integrity
    call Srot_wait_for_comm
    call Srot_comm6_comm1
    call Srot_calc_next_comm_period
    call Srot_scheduler_run
    ; wait_advance_timing
    ; calc_new_wait_times
    ; wait_before_zc_scan

    ; Check if it is startup phases
    jnb  Flag_Initial_Run_Phase, Srot_normal_run_checks
    jnb  Flag_Startup_Phase, Srot_initial_run_phase

    ; Startup phase
    mov  Srot_pwm_limit, Srot_pwm_limit_beg       ; Set initial max power
    mov  Srot_pwm_limit_by_rpm, Srot_pwm_limit_beg; Set initial max power
    clr  C
    mov  A, Srot_startup_cnt                 ; Load startup counter
    subb A, #24                         ; Is counter above requirement?
    jnc  Srot_startup_phase_done

    jnb  Flag_Rcp_Stop, Srot_run1            ; If pulse is above stop value - Continue to run
    sjmp Srot_exit_run_mode

Srot_startup_phase_done:
    ; Clear startup phase flag & remove pwm limits
    clr  Flag_Startup_Phase

Srot_initial_run_phase:
    ; If it is a direction change - branch
    jb   Flag_Dir_Change_Brake, Srot_normal_run_checks

    ; Decrement startup rotation count
    mov  A, Srot_initial_run_rot_cntd
    dec  A
    ; Check number of initial rotations
    jz   Srot_initial_run_phase_done         ; Branch if counter is zero

    mov  Srot_initial_run_rot_cntd, A        ; Not zero - store counter

    jnb  Flag_Rcp_Stop, Srot_run1            ; Check if pulse is below stop value
    jb   Flag_Pgm_Bidir, Srot_run1           ; Check if bidirectional operation

    sjmp Srot_exit_run_mode

Srot_initial_run_phase_done:
    clr  Flag_Initial_Run_Phase         ; Clear initial run phase flag

    ; Lift startup power restrictions
    ; Temperature protection acts until this point
    ; as a max startup power limiter.
    ; This plus the power limits applied in set_pwm_limit function
    ; act as a startup power limiter to protect the esc and the motor
    ; during startup, jams produced after crashes and desyncs recovery
    mov  Srot_pwm_limit, #255                ; Reset temperature level pwm limit
    mov  Srot_temp_pwm_level_setpoint, #255  ; Reset temperature level setpoint

    setb Flag_Motor_Started             ; Set motor started
    jmp  Srot_run1                           ; Continue with normal run

Srot_normal_run_checks:
    ; Reset stall count
    mov  Srot_startup_stall_cnt, #0
    setb Flag_Motor_Running

    jnb  Flag_Rcp_Stop, Srot_run6_check_bidir ; Check if stop
    jb   Flag_Pgm_Bidir, Srot_run6_check_timeout ; Check if bidirectional operation

    mov  Temp2, #Srot_pgm_brake_on_stop      ; Check if using brake on stop
    mov  A, @Temp2
    jz   Srot_run6_check_timeout

    ; Exit run mode after 100ms when using brake on stop
    clr  C
    mov  A, Srot_rcp_stop_cnt                ; Load stop RC pulse counter value
    subb A, #3                          ; Is number of stop RC pulses above limit?
    jnc  Srot_exit_run_mode                  ; Yes - exit run mode

Srot_run6_check_timeout:
    ; Exit run mode immediately if timeout
    mov  A, Srot_rcp_timeout_cntd            ; Load RC pulse timeout counter value
    jz   Srot_exit_run_mode                  ; If it is zero - go back to wait for power on

Srot_run6_check_bidir:
    jb   Flag_Pgm_Bidir, Srot_run6_bidir     ; Check if bidirectional operation

Srot_run6_check_speed:
    clr  C
    mov  A, Srot_comm_period4x_h             ; Is Comm_Period4x below minimum speed?
    subb A, #0F0h                       ; Default minimum speed (~1330 erpm)
    jnc  Srot_exit_run_mode                  ; Yes - exit run mode
    jmp  Srot_run1                           ; No - go back to run 1

Srot_run6_bidir:
    ; Check if direction change braking is in progress
    jb   Flag_Dir_Change_Brake, Srot_run6_bidir_braking

    ; Check if actual rotation direction matches force direction
    jb   Flag_Motor_Dir_Rev, Srot_run6_bidir_check_reversal
    jb   Flag_Rcp_Dir_Rev, Srot_run6_bidir_reversal
    sjmp Srot_run6_check_speed

Srot_run6_bidir_check_reversal:
    jb   Flag_Rcp_Dir_Rev, Srot_run6_check_speed

Srot_run6_bidir_reversal:
    ; Initiate direction and start braking
    setb Flag_Dir_Change_Brake          ; Set brake flag
    mov  Srot_pwm_limit_by_rpm, Srot_pwm_limit_beg; Set max power while braking to initial power limit
    jmp  Srot_run4                           ; Go back to run 4,thereby changing force direction

Srot_run6_bidir_braking:
    mov  Srot_pwm_limit_by_rpm, Srot_pwm_limit_beg; Set max power while braking to initial power limit

    clr  C
    mov  A, Srot_comm_period4x_h             ; Is Comm_Period4x below minimum speed?
    subb A, #40h                        ; Bidirectional braking termination speed (~5000 erpm)
    jc   Srot_run6_bidir_continue            ; No - continue braking

    ; Braking done, set new spinning direction
    clr  Flag_Dir_Change_Brake          ; Clear braking flag
    mov  C, Flag_Rcp_Dir_Rev            ; Read force direction
    mov  Flag_Motor_Dir_Rev, C          ; Set spinning direction
    setb Flag_Initial_Run_Phase
    mov  Srot_initial_run_rot_cntd, #18

Srot_run6_bidir_continue:
    jmp  Srot_run1                           ; Go back to run 1

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Exit run mode and power off
;
; Happens on normal stop (RC pulse == 0) or comparator timeout
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
