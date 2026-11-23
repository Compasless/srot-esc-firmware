; Compasless SROT ESC firmware
; Signal polarity and DShot rate acquisition.
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

Srot_setup_dshot:
    ; Setup timers for DShot
    mov  TCON, #51h                     ; Timer0/1 run and Int0 edge triggered
    mov  CKCON0, #01h                   ; Timer0/1 clock is system clock divided by 4 (for DShot150)
    mov  TMOD, #0AAh                    ; Timer0/1 set to 8-bits auto reload and gated by Int0/1
    mov  TH0, #0                        ; Auto reload value zero
    mov  TH1, #0

    mov  TMR2CN0, #04h                  ; Timer2 enabled (system clock divided by 12)
    mov  TMR3CN0, #04h                  ; Timer3 enabled (system clock divided by 12)

    Initialize_PCA                      ; Initialize PCA
    Set_Pwm_Polarity                    ; Set pwm polarity
    Enable_Power_Pwm_Module             ; Enable power pwm module
    Enable_Damp_Pwm_Module              ; Enable damping pwm module
    Initialize_Comparator               ; Initialize comparator
    Initialize_Adc                      ; Initialize ADC operation
    call Srot_wait1ms

    call Srot_detect_rcp_level               ; Detect RCP level (normal or inverted DShot)

    ; Route RCP according to detected DShot signal (normal or inverted)
    mov  IT01CF, #(80h + (RTX_PIN SHL 4) + RTX_PIN) ; Route RCP input to Int0/1,with Int1 inverted
    jnb  Flag_Rcp_DShot_Inverted, Srot_setup_dshot_clear_flags
    mov  IT01CF, #(08h + (RTX_PIN SHL 4) + RTX_PIN) ; Route RCP input to Int0/1,with Int0 inverted

Srot_setup_dshot_clear_flags:
    clr  Flag_Demag_Notify              ; Clear motor events
    clr  Flag_Desync_Notify
    clr  Flag_Stall_Notify
    clr  Flag_Telemetry_Pending         ; Clear DShot telemetry flag
    clr  Flag_Ext_Tele                  ; Clear extended telemetry enabled flag

    ; Setup interrupts
    mov  IE, #2Dh                       ; Enable Timer1/2 interrupts and Int0/1 interrupts
    mov  EIE1, #80h                     ; Enable Timer3 interrupts
    mov  IP, #03h                       ; High priority to Timer0 and Int0 interrupts

    setb IE_EA                          ; Enable all interrupts

; Setup variables for DShot150 (Only on 24MHz because frame length threshold cannot be scaled up)
IF MCU_TYPE == MCU_BB1
    mov  Srot_dshot_timer_preset, #-64       ; Load DShot sync timer preset (for DShot150)
    mov  Srot_dshot_pwm_thr, #8              ; Load DShot qualification pwm threshold (for DShot150)
    mov  Srot_dshot_frame_length_thr, #160   ; Load DShot frame length criteria

    Set_DShot_Tlm_Bitrate 187500        ; = 5/4 * 150000

    ; Test whether signal is DShot150
    mov  Srot_rcp_outside_range_cnt, #10     ; Set out of range counter
    call Srot_wait100ms                      ; Wait for new RC pulse
    mov  A, Srot_rcp_outside_range_cnt       ; Check if pulses were accepted
    jz   Srot_arming_begin
ENDIF

    mov  CKCON0, #0Ch                   ; Timer0/1 clock is system clock (for DShot300/600)

    ; Setup variables for DShot300
    mov  Srot_dshot_timer_preset, #-128      ; Load DShot sync timer preset (for DShot300)
    mov  Srot_dshot_pwm_thr, #16             ; Load DShot pwm threshold (for DShot300)
    mov  Srot_dshot_frame_length_thr, #80    ; Load DShot frame length criteria

    Set_DShot_Tlm_Bitrate 375000        ; = 5/4 * 300000

    ; Test whether signal is DShot300, if so begin arming
    mov  Srot_rcp_outside_range_cnt, #10     ; Set out of range counter
    call Srot_wait100ms                      ; Wait for new RC pulse
    mov  A, Srot_rcp_outside_range_cnt       ; Check if pulses were accepted
    jz   Srot_arming_begin

; Setup variables for DShot600 (Only on 48MHz for performance reasons)
IF MCU_TYPE == MCU_BB2 or MCU_TYPE == MCU_BB51
    mov  Srot_dshot_timer_preset, #-64       ; Load DShot sync timer preset (for DShot600)
    mov  Srot_dshot_pwm_thr, #8              ; Load DShot pwm threshold (for DShot600)
    mov  Srot_dshot_frame_length_thr, #40    ; Load DShot frame length criteria

    Set_DShot_Tlm_Bitrate 750000        ; = 5/4 * 600000

    ; Test whether signal is DShot600, if so begin arming
    mov  Srot_rcp_outside_range_cnt, #10     ; Set out of range counter
    call Srot_wait100ms                      ; Wait for new RC pulse
    mov  A, Srot_rcp_outside_range_cnt       ; Check if pulses were accepted
    jz   Srot_arming_begin
ENDIF

    ; No valid signal detected, try again
    ljmp Srot_init_no_signal
