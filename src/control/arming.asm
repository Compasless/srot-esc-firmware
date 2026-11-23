; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft  2022-2023 Daniel Mosquera
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
;

Srot_arming_begin:
    push PSW
    mov  PSW, #10h                      ; Temp8 in register bank 2 holds value
    mov  Temp8, CKCON0                  ; Save DShot clock settings for telemetry
    pop  PSW

    setb Flag_Had_Signal                ; Mark that a signal has been detected
    mov  Srot_startup_stall_cnt, #0          ; Reset stall count

    clr  IE_EA
    call Srot_beep_f1_short                  ; Confirm RC pulse detection by beeping
    setb IE_EA

; Make sure RC pulse has been zero for ~300ms
Srot_arming_wait:
    clr  C
    mov  A, Srot_rcp_stop_cnt
    subb A, #10
    jc   Srot_arming_wait

    clr  IE_EA
    call Srot_beep_f2_short                  ; Confirm arm state by beeping
    setb IE_EA

; Armed and waiting for power on (RC pulse > 0)
Srot_wait_for_start:
    clr  A
    mov  Srot_comm_period4x_l, A             ; Reset commutation period for telemetry
    mov  Srot_comm_period4x_h, A
    mov  Srot_dshot_cmd, A                   ; Reset DShot command (only considered in this loop)
    mov  Srot_dshot_cmd_cnt, A
    mov  Srot_beacon_delay_cnt, A            ; Clear beacon wait counter
    mov  Srot_timer2_x, A                    ; Clear Timer2 extended byte

Srot_wait_for_start_loop:
    clr  C
    mov  A, Srot_timer2_x
    subb A, #94
    jc   Srot_wait_for_start_no_beep         ; Counter wrapping (about 3 sec)

    mov  Srot_timer2_x, #0
    inc  Srot_beacon_delay_cnt               ; Increment beacon wait counter

    mov  Temp1, #Srot_pgm_beacon_delay
    mov  A, @Temp1
    mov  Temp1, #20                     ; 1 min
    dec  A
    jz   Srot_beep_delay_set

    mov  Temp1, #40                     ; 2 min
    dec  A
    jz   Srot_beep_delay_set

    mov  Temp1, #100                    ; 5 min
    dec  A
    jz   Srot_beep_delay_set

    mov  Temp1, #200                    ; 10 min
    dec  A
    jz   Srot_beep_delay_set

    mov  Srot_beacon_delay_cnt, #0           ; Reset beacon counter for infinite delay

Srot_beep_delay_set:
    clr  C
    mov  A, Srot_beacon_delay_cnt
    subb A, Temp1                       ; Check against chosen delay
    jc   Srot_wait_for_start_no_beep         ; Has delay elapsed?

    dec  Srot_beacon_delay_cnt               ; Decrement counter for continued beeping

    mov  Temp1, #4                      ; Beep tone 4
    clr  IE_EA                          ; Disable all interrupts
    call Srot_switch_power_off               ; Switch power off in case braking is set
    call Srot_beacon_beep
    setb IE_EA                          ; Enable all interrupts

Srot_wait_for_start_no_beep:
    jb   Flag_Telemetry_Pending, Srot_wait_for_start_check_rcp
    call Srot_dshot_tlm_create_packet        ; Create telemetry packet (0 rpm)
    call Srot_scheduler_run

Srot_wait_for_start_check_rcp:
    ; If RC pulse is higher than stop (>0) then proceed to start the motor
    jnb  Flag_Rcp_Stop, Srot_wait_for_start_nonzero

    mov  A, Srot_rcp_timeout_cntd            ; Load RC pulse timeout counter value
    ljz  Srot_init_no_signal                 ; If pulses are missing - go back to detect input signal

    call Srot_dshot_cmd_check                ; Check and process DShot command

    sjmp Srot_wait_for_start_loop            ; Go back to beginning of wait loop

Srot_wait_for_start_nonzero:
    call Srot_wait100ms                      ; Wait to see if start pulse was glitch

    ; If RC pulse returned to stop (0) - start over
    jb   Flag_Rcp_Stop, Srot_wait_for_start_loop

    ; If no safety arm jump to motor start
    mov  Temp1, #Srot_pgm_safety_arm
    cjne @Temp1, #001h, Srot_motor_start

    ; If EDT flag is set start motor
    jb  Flag_Ext_Tele, Srot_motor_start

    ; Safety is enabled. Check Flag_Ext_Tele is set
    ; If not set beep and wait again
    call Srot_beep_safety_no_arm
    jmp  Srot_wait_for_start_loop



;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Motor start entry point
;**** **** **** **** **** **** **** **** **** **** **** **** ****
