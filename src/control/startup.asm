; Compasless SROT ESC firmware
; Rotor startup setup and reversible-direction capture.
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

Srot_motor_start:
    clr  IE_EA                          ; Disable interrupts

    call Srot_switch_power_off

    clr  A
    mov  Srot_flags0, #0                     ; Clear run time flags
    mov  Srot_flags1, #0
    mov  Srot_demag_detected_metric, #0      ; Clear demag metric
    mov  Srot_demag_detected_metric_max, #0  ; Clear demag metric max
    mov  Srot_ext_telemetry_h, #0            ; Clear extended telemetry data

    ; Set up start operating conditions
    mov  Temp2, #Srot_pgm_startup_power_max
    mov  Srot_pwm_limit_beg, @Temp2          ; Set initial pwm limit
    mov  Srot_pwm_limit_by_rpm, Srot_pwm_limit_beg

    ; Set temperature PWM limit and setpoint to the maximum value
    mov  Srot_pwm_limit, Srot_pwm_limit_beg
    mov  Srot_temp_pwm_level_setpoint, Srot_pwm_limit_beg

; Begin startup sequence
IF MCU_TYPE == MCU_BB2 or MCU_TYPE == MCU_BB51
    Set_MCU_Clk_48MHz                   ; Enable 48MHz clock frequency

    ; Scale DShot criteria for 48MHz
    clr  C
    rlca Srot_dshot_timer_preset             ; Scale sync timer preset

    clr  C
    rlca Srot_dshot_frame_length_thr         ; Scale frame length criteria

    clr  C
    rlca Srot_dshot_pwm_thr                  ; Scale pulse width criteria

    ; Scale DShot telemetry for 48MHz
    xcha Srot_dshot_gcr_pulse_time_1, Srot_dshot_gcr_pulse_time_1_tmp
    xcha Srot_dshot_gcr_pulse_time_2, Srot_dshot_gcr_pulse_time_2_tmp
    xcha Srot_dshot_gcr_pulse_time_3, Srot_dshot_gcr_pulse_time_3_tmp

    mov  Srot_dshot_gcr_start_delay, #DSHOT_TLM_START_DELAY_48
ENDIF

    mov  C, Flag_Pgm_Dir_Rev            ; Read spin direction setting
    mov  Flag_Motor_Dir_Rev, C

    jnb  Flag_Pgm_Bidir, Srot_motor_start_bidir_done ; Check if bidirectional operation

    mov  C, Flag_Rcp_Dir_Rev            ; Read force direction
    mov  Flag_Motor_Dir_Rev, C          ; Set spinning direction

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Motor start beginning
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_motor_start_bidir_done:
    ; Set initial motor state
    setb Flag_Startup_Phase             ; Set startup phase flags
    setb Flag_Initial_Run_Phase
    mov  Srot_startup_cnt, #0                ; Reset startup phase run counter
    mov  Srot_initial_run_rot_cntd, #12      ; Set initial run rotation countdown

    ; Initialize commutation
    call Srot_comm5_comm6                    ; Initialize commutation
    call Srot_comm6_comm1
    call Srot_initialize_timing              ; Initialize timing
    call Srot_calc_next_comm_period          ; Set virtual commutation point
    call Srot_initialize_timing              ; Initialize timing
    call Srot_calc_next_comm_period
    call Srot_initialize_timing              ; Initialize timing

    setb IE_EA                          ; Enable interrupts

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Run entry point
;
; Run 1 = B(p-on) + C(n-pwm) - comparator A evaluated
; Out_cA changes from low to high
;**** **** **** **** **** **** **** **** **** **** **** **** ****
