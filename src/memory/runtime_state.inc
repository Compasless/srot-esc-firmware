; Compasless SROT ESC firmware
; Register aliases, fixed RAM state and stack layout.
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

; Temporary register definitions
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Temp1 EQU R0
Temp2 EQU R1
Temp3 EQU R2
Temp4 EQU R3
Temp5 EQU R4
Temp6 EQU R5
Temp7 EQU R6
Temp8 EQU R7

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; RAM definitions
; Bit-addressable data segment
;**** **** **** **** **** **** **** **** **** **** **** **** ****
DSEG AT 20h
Srot_bit_access: DS 1                        ; MUST BE AT THIS ADDRESS. Variable at bit accessible address (for non interrupt routines)
Srot_bit_access_int: DS 1                    ; Variable at bit accessible address (for interrupts)

Srot_flags0: DS 1                            ; State flags. Reset upon motor_start
    Flag_Startup_Phase BIT Srot_flags0.0     ; Set when in startup phase
    Flag_Initial_Run_Phase BIT Srot_flags0.1 ; Set when in initial run phase (or startup phase),before synchronized run is achieved.
    Flag_Motor_Dir_Rev BIT Srot_flags0.2     ; Set if the current spinning direction is reversed
    Flag_Demag_Notify BIT Srot_flags0.3      ; Set when motor demag has been detected but still not notified
    Flag_Desync_Notify BIT Srot_flags0.4     ; Set when motor desync has been detected but still not notified
    Flag_Stall_Notify BIT Srot_flags0.5      ; Set when motor stall detected but still not notified

Srot_flags1: DS 1                            ; State flags. Reset upon motor_start
    Flag_Timer3_Pending BIT Srot_flags1.0    ; Timer3 pending flag
    Flag_Demag_Detected BIT Srot_flags1.1    ; Set when excessive demag time is detected
    Flag_Comp_Timed_Out BIT Srot_flags1.2    ; Set when comparator reading timed out
    Flag_Motor_Running BIT Srot_flags1.3
    Flag_Motor_Started BIT Srot_flags1.4     ; Set when motor is started
    Flag_Dir_Change_Brake BIT Srot_flags1.5  ; Set when braking before direction change in case of bidirectional operation
    Flag_High_Rpm BIT Srot_flags1.6          ; Set when motor rpm is high (Comm_Period4x_H less than 2)

Srot_flags2: DS 1                            ; State flags. NOT reset upon motor_start
    ; BIT    Flags2.0
    Flag_Pgm_Dir_Rev BIT Srot_flags2.1       ; Set if the programmed direction is reversed
    Flag_Pgm_Bidir BIT Srot_flags2.2         ; Set if the programmed control mode is bidirectional operation
    Flag_16ms_Elapsed BIT Srot_flags2.3      ; Set when timer2 interrupt is triggered
    Flag_Ext_Tele BIT Srot_flags2.4          ; Set if Extended DHOT telemetry is enabled
    Flag_Rcp_Stop BIT Srot_flags2.5          ; Set if the RC pulse value is zero or if timeout occurs
    Flag_Rcp_Dir_Rev BIT Srot_flags2.6       ; RC pulse direction in bidirectional mode
    Flag_Rcp_DShot_Inverted BIT Srot_flags2.7 ; DShot RC pulse input is inverted (and supports telemetry)

Srot_flags3: DS 1                            ; State flags. NOT reset upon motor_start
    Flag_Telemetry_Pending BIT Srot_flags3.0 ; DShot telemetry data packet is ready to be sent
    Flag_Had_Signal BIT Srot_flags3.1        ; Used to detect reset after having had a valid signal
    Flag_User_Reverse_Requested BIT Srot_flags3.2 ; It is set when user request to reverse motors in turtle mode


Srot_tlm_data_l: DS 1                        ; DShot telemetry data (lo byte)
Srot_tlm_data_h: DS 1                        ; DShot telemetry data (hi byte)
;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Direct addressing data segment
;**** **** **** **** **** **** **** **** **** **** **** **** ****
DSEG AT 30h
Srot_rcp_outside_range_cnt: DS 1             ; RC pulse outside range counter (incrementing)
Srot_rcp_timeout_cntd: DS 1                  ; RC pulse timeout counter (decrementing)
Srot_rcp_stop_cnt: DS 1                      ; Counter for RC pulses below stop value

Srot_beacon_delay_cnt: DS 1                  ; Counter to trigger beacon during wait for start
Srot_startup_cnt: DS 1                       ; Startup phase commutations counter (incrementing)
Srot_startup_zc_timeout_cntd: DS 1           ; Startup zero cross timeout counter (decrementing)
Srot_initial_run_rot_cntd: DS 1              ; Initial run rotations counter (decrementing)
Srot_startup_stall_cnt: DS 1                 ; Counts start/run attempts that resulted in stall. Reset upon a proper stop
Srot_demag_detected_metric: DS 1             ; Metric used to gauge demag event frequency
Srot_demag_detected_metric_max: DS 1         ; Metric used to gauge demag event frequency
Srot_demag_pwr_off_thresh: DS 1              ; Metric threshold above which power is cut
Srot_low_rpm_pwr_slope: DS 1                 ; Sets the slope of power increase for low rpm
Srot_timer2_x: DS 1                          ; Timer2 extended byte
Srot_prev_comm_l: DS 1                       ; Previous commutation Timer2 timestamp (lo byte)
Srot_prev_comm_h: DS 1                       ; Previous commutation Timer2 timestamp (hi byte)
Srot_prev_comm_x: DS 1                       ; Previous commutation Timer2 timestamp (ext byte)
Srot_prev_prev_comm_l: DS 1                  ; Pre-previous commutation Timer2 timestamp (lo byte)
Srot_prev_prev_comm_h: DS 1                  ; Pre-previous commutation Timer2 timestamp (hi byte)
Srot_comm_period4x_l: DS 1                   ; Timer2 ticks between the last 4 commutations (lo byte)
Srot_comm_period4x_h: DS 1                   ; Timer2 ticks between the last 4 commutations (hi byte)
Srot_comparator_read_cnt: DS 1               ; Number of comparator reads done
Srot_wt_adv_start_l: DS 1                    ; Timer3 start point for commutation advance timing (lo byte)
Srot_wt_adv_start_h: DS 1                    ; Timer3 start point for commutation advance timing (hi byte)
Srot_wt_zc_scan_start_l: DS 1                ; Timer3 start point from commutation to zero cross scan (lo byte)
Srot_wt_zc_scan_start_h: DS 1                ; Timer3 start point from commutation to zero cross scan (hi byte)
Srot_wt_zc_tout_start_l: DS 1                ; Timer3 start point for zero cross scan timeout (lo byte)
Srot_wt_zc_tout_start_h: DS 1                ; Timer3 start point for zero cross scan timeout (hi byte)
Srot_wt_comm_start_l: DS 1                   ; Timer3 start point from zero cross to commutation (lo byte)
Srot_wt_comm_start_h: DS 1                   ; Timer3 start point from zero cross to commutation (hi byte)
Srot_pwm_limit: DS 1                         ; Maximum allowed pwm (8-bit)
Srot_pwm_limit_by_rpm: DS 1                  ; Maximum allowed pwm for low or high rpm (8-bit)
Srot_pwm_limit_beg: DS 1                     ; Initial pwm limit (8-bit)
Srot_pwm_braking_l: DS 1                     ; Max Braking pwm (lo byte)
Srot_pwm_braking_h: DS 1                     ; Max Braking pwm (hi byte)
Srot_temp_prot_limit: DS 1                   ; Temperature protection limit
Srot_temp_pwm_level_setpoint: DS 1           ; PWM level setpoint
Srot_beep_strength: DS 1                     ; Strength of beeps
Srot_flash_key_1: DS 1                       ; Flash key one
Srot_flash_key_2: DS 1                       ; Flash key two
Srot_dshot_pwm_thr: DS 1                     ; DShot pulse width threshold value (Timer0 ticks)
Srot_dshot_timer_preset: DS 1                ; DShot timer preset for frame sync detection (Timer1 lo byte)
Srot_dshot_frame_start_l: DS 1               ; DShot frame start timestamp (Timer2 lo byte)
Srot_dshot_frame_start_h: DS 1               ; DShot frame start timestamp (Timer2 hi byte)
Srot_dshot_frame_length_thr: DS 1            ; DShot frame length criteria (Timer2 ticks)
Srot_dshot_cmd: DS 1                         ; DShot command
Srot_dshot_cmd_cnt: DS 1                     ; DShot command count
; Pulse durations for GCR encoding DShot telemetry data
Srot_dshot_gcr_pulse_time_1: DS 1            ; Encodes binary: 1
Srot_dshot_gcr_pulse_time_2: DS 1            ; Encodes binary: 01
Srot_dshot_gcr_pulse_time_3: DS 1            ; Encodes binary: 001

Srot_dshot_gcr_pulse_time_1_tmp: DS 1
Srot_dshot_gcr_pulse_time_2_tmp: DS 1
Srot_dshot_gcr_pulse_time_3_tmp: DS 1
Srot_dshot_gcr_start_delay: DS 1
Srot_ext_telemetry_l: DS 1                   ; Extended telemetry data to be sent
Srot_ext_telemetry_h: DS 1
Srot_scheduler_counter: DS 1                 ; Scheduler Heartbeat
;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Indirect addressing data segments
;**** **** **** **** **** **** **** **** **** **** **** **** ****
ISEG AT 080h                            ; The variables below must be in this sequence
Srot__pgm_gov_p_gain: DS 1                   ;
Srot_pgm_startup_power_min: DS 1             ; Minimum power during startup phase
Srot_pgm_startup_beep: DS 1                  ; Startup beep melody on/off
Srot__pgm_dithering: DS 1                    ; Enable PWM dithering
Srot_pgm_startup_power_max: DS 1             ; Maximum power (limit) during startup (and starting initial run phase)
Srot__pgm_rampup_slope: DS 1                 ;
Srot_pgm_rpm_power_slope: DS 1               ; Low RPM power protection slope (factor)
Srot_pgm_pwm_freq: DS 1                      ; PWM frequency (temporary method for display)
Srot_pgm_direction: DS 1                     ; Rotation direction
Srot__pgm_input_pol: DS 1                    ; Input PWM polarity
Srot_initialized_l_dummy: DS 1               ; Place holder
Srot_initialized_h_dummy: DS 1               ; Place holder
Srot__pgm_enable_tx_program: DS 1            ; Enable/disable value for TX programming
Srot_pgm_braking_strength: DS 1              ; Set maximum braking strength (complementary pwm)
Srot__pgm_gov_setup_target: DS 1             ; Main governor setup target
Srot__pgm_startup_rpm: DS 1                  ; Startup RPM
Srot__pgm_startup_accel: DS 1                ; Startup acceleration
Srot__pgm_volt_comp: DS 1                    ; Voltage comp
Srot_pgm_comm_timing: DS 1                   ; Commutation timing
Srot__pgm_damping_force: DS 1                ; Damping force
Srot__pgm_gov_range: DS 1                    ; Governor range
Srot__pgm_startup_method: DS 1               ; Startup method
Srot__pgm_min_throttle: DS 1                 ; Minimum throttle
Srot__pgm_max_throttle: DS 1                 ; Maximum throttle
Srot_pgm_beep_strength: DS 1                 ; Beep strength
Srot_pgm_beacon_strength: DS 1               ; Beacon strength
Srot_pgm_beacon_delay: DS 1                  ; Beacon delay
Srot__pgm_throttle_rate: DS 1                ; Throttle rate
Srot_pgm_demag_comp: DS 1                    ; Demag compensation
Srot__pgm_bec_voltage_high: DS 1             ; BEC voltage
Srot__pgm_center_throttle: DS 1              ; Center throttle (in bidirectional mode)
Srot__pgm_main_spoolup_time: DS 1            ; Main spoolup time
Srot_pgm_enable_temp_prot: DS 1              ; Temperature protection enable
Srot__pgm_enable_power_prot: DS 1            ; Low RPM power protection enable
Srot__pgm_enable_pwm_input: DS 1             ; Enable PWM input signal
Srot__pgm_pwm_dither: DS 1                   ; Output PWM dither
Srot_pgm_brake_on_stop: DS 1                 ; Braking when throttle is zero
Srot_pgm_led_control: DS 1                   ; LED control
Srot_pgm_power_rating: DS 1                  ; Power rating
Srot_pgm_safety_arm: DS  1                   ; Various flag settings: bit 0 is require edt enable to arm

ISEG AT 0B0h
Srot_stack: DS 16                            ; Reserved stack space

ISEG AT 0D0h
Srot_temp_storage: DS 48                     ; Temporary storage (internal memory)
