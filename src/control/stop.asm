; Compasless SROT ESC firmware
; Signal-loss shutdown, stall handling and stop/brake behavior.
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

Srot_exit_run_mode_on_timeout:
    jb   Flag_Motor_Running, Srot_exit_run_mode
    inc  Srot_startup_stall_cnt              ; Increment stall count if motors did not properly start

Srot_exit_run_mode:
    ; Disable all interrupts (they will be disabled for a while, be aware)
    clr  IE_EA

    call Srot_switch_power_off
    mov  Srot_flags0, #0                     ; Clear run time flags (in case they are used in interrupts)
    mov  Srot_flags1, #0

IF MCU_TYPE == MCU_BB2 or MCU_TYPE == MCU_BB51
    Set_MCU_Clk_24MHz

    ; Scale DShot criteria for 24MHz
    setb C
    rrca Srot_dshot_timer_preset             ; Scale sync timer preset

    clr  C
    rrca Srot_dshot_frame_length_thr         ; Scale frame length criteria

    clr  C
    rrca Srot_dshot_pwm_thr                  ; Scale pulse width criteria

    ; Scale DShot telemetry for 24MHz
    xcha Srot_dshot_gcr_pulse_time_1, Srot_dshot_gcr_pulse_time_1_tmp
    xcha Srot_dshot_gcr_pulse_time_2, Srot_dshot_gcr_pulse_time_2_tmp
    xcha Srot_dshot_gcr_pulse_time_3, Srot_dshot_gcr_pulse_time_3_tmp

    mov  Srot_dshot_gcr_start_delay, #DSHOT_TLM_START_DELAY
ENDIF

    ; Check if RCP is zero, then it is a normal stop or signal timeout
    jb   Flag_Rcp_Stop, Srot_exit_run_mode_no_stall

    ; It is a stall!
    ; Signal stall
    setb Flag_Stall_Notify

    ; Check max consecutive stalls and exit if stall counter > 3
    clr  C
    mov  A, Srot_startup_stall_cnt
    subb A, #3
    jnc  Srot_exit_run_mode_is_stall

    ; At this point there was a desync event, and a new try is to be done.
    ; The program will jump to motor_start. Interrupts are disabled at this
    ; point so it is safe to jump to motor start, where a new initial state
    ; will be set

    call Srot_wait100ms                      ; Wait for a bit between stall restarts

    ljmp Srot_motor_start                    ; Go back and try starting motors again

Srot_exit_run_mode_is_stall:
    ; Enable all interrupts (disabled above, in exit_run_mode)
    setb IE_EA

    ; Clear extended DSHOT telemetry flag if turtle mode is not active
    ; This flag is also used for EDT safety arm flag
    ; We don't want to deactivate extended telemetry during turtle mode
    ; Extended telemetry flag is important because it is involved in
    ; EDT safety feature. We don't want to disable EDT arming during
    ; turtle mode.
    jb Flag_User_Reverse_Requested, Srot_exit_run_mode_is_stall_beep
    clr Flag_Ext_Tele

Srot_exit_run_mode_is_stall_beep:
    ; Stalled too many times
    clr  IE_EA
    call Srot_beep_motor_stalled
    setb IE_EA

    ljmp Srot_arming_begin                   ; Go back and wait for arming

Srot_exit_run_mode_no_stall:
    ; Enable all interrupts (disabled above, in exit_run_mode)
    setb IE_EA

    ; Clear extended DSHOT telemetry flag if turtle mode is not active
    ; This flag is also used for EDT safety arm flag
    ; We don't want to deactivate extended telemetry during turtle mode
    ; Extended telemetry flag is important because it is involved in
    ; EDT safety feature. We don't want to disable EDT arming during
    ; turtle mode.
    jb Flag_User_Reverse_Requested, Srot_exit_run_mode_no_stall_no_beep
    clr Flag_Ext_Tele

Srot_exit_run_mode_no_stall_no_beep:
    ; Clear stall counter
    mov  Srot_startup_stall_cnt, #0

    mov  Temp1, #Srot_pgm_brake_on_stop      ; Check if using brake on stop
    mov  A, @Temp1
    jz   Srot_exit_run_mode_brake_done

    A_Com_Fet_On                        ; Brake on stop
    B_Com_Fet_On
    C_Com_Fet_On

Srot_exit_run_mode_brake_done:
    ljmp Srot_wait_for_start                 ; Go back to wait for power on

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Reset
;
; Should execution ever reach this point the ESC will be reset,
; as code flash after offset 1A00 is used for EEPROM storage
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
