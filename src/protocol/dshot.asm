; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft  2022-2023 Daniel Mosquera
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; DShot
;

;
; DShot
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Detect DShot RC pulse level
;
; Determine if RC pulse signal level is normal or inverted DShot. If inverted
; DShot - we are using
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_detect_rcp_level:
    mov  A, #50                         ; Must detect the same level 50 times (25 us)
    mov  C, RTX_BIT

Srot_detect_rcp_level_read:
    jc   Srot_detect_rcp_level_read_check_high_to_low
    jb   RTX_BIT, Srot_detect_rcp_level      ; Level changed from low to high - start over

Srot_detect_rcp_level_read_check_high_to_low:
    jnc  Srot_detect_rcp_level_check_loop
    jnb  RTX_BIT, Srot_detect_rcp_level      ; Level changed from high to low - start over

Srot_detect_rcp_level_check_loop:
    djnz ACC, Srot_detect_rcp_level_read

    mov  Flag_Rcp_DShot_Inverted, C
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Check DShot command
;
; Determine received DShot command and perform action if DShot command is not
; zero:
;
; 1-5: Beacon beep
;
; All following commands need to be received 6 times in a row before action is
; taken:
;
;  7: Set motor direction to normal
;  8: Set motor direction to reverse
;  9: Disable 3D mode
; 10: Enable 3D mode
; 12: Save settings
; 13: Enable EDT (Extended DShot Telemetry)
; 14: Disable EDT (Extended DShot Telemetry)
; 20: Set motor direction to user programmed direction
; 21: Set motor direction to reversed user programmed direction
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_dshot_cmd_check:
    mov  A, Srot_dshot_cmd
    jnz  Srot_dshot_cmd_beeps_check
    ret

Srot_dshot_cmd_beeps_check:
    mov  Temp1, A
    clr  C
    subb A, #6                          ; Beacon beeps for command 1-5
    jnc  Srot_dshot_cmd_check_count

    clr  IE_EA                          ; Disable all interrupts
    call Srot_switch_power_off               ; Switch power off in case braking is set
    call Srot_beacon_beep
    call Srot_wait200ms                      ; Wait a bit for next beep
    setb IE_EA                          ; Enable all interrupts

    sjmp Srot_dshot_cmd_exit

Srot_dshot_cmd_check_count:
    ; Remaining commands must be received 6 times in a row
    clr  C
    mov  A, Srot_dshot_cmd_cnt
    subb A, #6
    jc   Srot_dshot_cmd_exit_no_clear

Srot_dshot_cmd_direction_normal:
    ; Set motor spinning direction to normal
    cjne Temp1, #CMD_DIRECTION_NORMAL, Srot_dshot_cmd_direction_reverse

    clr  Flag_Pgm_Dir_Rev

    sjmp Srot_dshot_cmd_exit

Srot_dshot_cmd_direction_reverse:
    ; Set motor spinning direction to reversed
    cjne Temp1, #CMD_DIRECTION_REVERSE, Srot_dshot_cmd_direction_bidir_off

    setb Flag_Pgm_Dir_Rev

    sjmp Srot_dshot_cmd_exit

Srot_dshot_cmd_direction_bidir_off:
    ; Set motor control mode to normal (not bidirectional)
    cjne Temp1, #CMD_BIDIR_OFF, Srot_dshot_cmd_direction_bidir_on

    ; 9: Set motor control mode to normal (not bidirectional)
    clr  Flag_Pgm_Bidir

    sjmp Srot_dshot_cmd_exit

Srot_dshot_cmd_direction_bidir_on:
    ; Set motor control mode to bidirectional
    cjne Temp1, #CMD_BIDIR_ON, Srot_dshot_cmd_extended_telemetry_enable

    setb Flag_Pgm_Bidir

    sjmp Srot_dshot_cmd_exit

Srot_dshot_cmd_extended_telemetry_enable:
    ; Enable extended telemetry
    cjne Temp1, #CMD_EXTENDED_TELEMETRY_ENABLE, Srot_dshot_cmd_extended_telemetry_disable

    mov  Srot_ext_telemetry_l, #00h
    mov  Srot_ext_telemetry_h, #0Eh          ; Send state/event 0 frame to signal telemetry enable

    setb Flag_Ext_Tele

    sjmp Srot_dshot_cmd_exit

Srot_dshot_cmd_extended_telemetry_disable:
    ; Disable extended telemetry
    cjne Temp1, #CMD_EXTENDED_TELEMETRY_DISABLE, Srot_dshot_cmd_direction_user_normal

    mov  Srot_ext_telemetry_l, #0FFh
    mov  Srot_ext_telemetry_h, #0Eh          ; Send state/event 0xff frame to signal telemetry disable

    clr  Flag_Ext_Tele

    sjmp Srot_dshot_cmd_exit

Srot_dshot_cmd_direction_user_normal:
    ; Set motor spinning direction to user programmed direction
    cjne Temp1, #CMD_DIRECTION_USER_NORMAL, Srot_dshot_cmd_direction_user_reverse

    mov  Temp2, #Srot_pgm_direction          ; Read programmed direction
    mov  A, @Temp2
    dec  A
    mov  C, ACC.0                       ; Set direction
    mov  Flag_Pgm_Dir_Rev, C

    ; User reverse operation is off (used in turtle mode)
    clr  Flag_User_Reverse_Requested

    sjmp Srot_dshot_cmd_exit

Srot_dshot_cmd_direction_user_reverse:       ; Temporary reverse
    ; Set motor spinning direction to reverse of user programmed direction
    cjne Temp1, #CMD_DIRECTION_USER_REVERSE, Srot_dshot_cmd_save_settings

    mov  Temp2, #Srot_pgm_direction          ; Read programmed direction
    mov  A, @Temp2
    dec  A
    mov  C, ACC.0
    cpl  C                              ; Set reverse direction
    mov  Flag_Pgm_Dir_Rev, C

    ; User reverse operation is on (used in turtle mode)
    setb Flag_User_Reverse_Requested

    sjmp Srot_dshot_cmd_exit

Srot_dshot_cmd_save_settings:
    cjne Temp1, #CMD_SAVE_SETTINGS, Srot_dshot_cmd_exit

    clr  A                              ; Set programmed direction from flags
    mov  C, Flag_Pgm_Dir_Rev
    mov  ACC.0, C
    mov  C, Flag_Pgm_Bidir
    mov  ACC.1, C
    inc  A
    mov  Temp2, #Srot_pgm_direction          ; Store programmed direction
    mov  @Temp2, A

    Unlock_Flash

    call Srot_erase_and_store_all_in_eeprom

    Lock_Flash

    setb IE_EA

Srot_dshot_cmd_exit:
    mov  Srot_dshot_cmd, #0                  ; Clear DShot command
    mov  Srot_dshot_cmd_cnt, #0              ; Clear Dshot command counter

Srot_dshot_cmd_exit_no_clear:
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; DShot telemetry create packet
;
; Create DShot telemetry packet and prepare it for being sent
; The routine is divided into 6 sections that can return early
; in order to reduce commutation interference
;
; Requirements:
; - Must NOT be called while Flag_Telemetry_Pending is set
; - Must NOT write to Temp7, Temp8
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_dshot_tlm_create_packet:
    push PSW
    mov  PSW, #10h                      ; Select register bank 2

    Early_Return_Packet_Stage 0

    ; If coded telemetry ready jump to telemetry ready
    mov  A, Srot_ext_telemetry_h
    jnz  Srot_dshot_tlm_ready

    clr  IE_EA
    mov  A, Srot_comm_period4x_l             ; Read commutation period
    mov  Srot_tlm_data_h, Srot_comm_period4x_h
    setb IE_EA

    ; Calculate e-period (6 commutations) in microseconds
    ; Comm_Period * 6 * 0.5 = Comm_Period4x * 3/4 (1/2 + 1/4)
    mov  C, Srot_tlm_data_h.0
    rrc  A
    mov  Temp2, A
    mov  C, Srot_tlm_data_h.1
    rrc  A
    add  A, Temp2
    mov  Temp3, A                       ; Comm_Period3x_L

    mov  A, Srot_tlm_data_h
    rr   A
    clr  ACC.7
    mov  Temp2, A
    rr   A
    clr  ACC.7
    addc A, Temp2
    mov  Temp4, A                       ; Comm_Period3x_H

    ; Timer2 ticks are ~489ns (not 500ns) - use approximation for better
    ; accuracy:
    ;
    ; E-period = Comm_Period3x - 4 * Comm_Period4x_H

    ; NOTE: For better performance assume Comm_Period4x_H < 64
    ;       (6-bit, above ~5k erpm). At lower speed result will be less precise.
    mov  A, Srot_tlm_data_h                  ; Comm_Period4x_H
    rl   A                              ; Multiply by 4
    rl   A
    anl  A, #0FCh
    mov  Temp5, A

    clr  C
    mov  A, Temp3                       ; Comm_Period3x_L
    subb A, Temp5
    mov  Srot_tlm_data_l, A
    mov  A, Temp4                       ; Comm_Period3x_H
    subb A, #0
    mov  Srot_tlm_data_h, A

Srot_dshot_tlm_ready:
    Early_Return_Packet_Stage 1

    ; If extended telemetry ready jump to extended telemetry coded
    mov  A, Srot_ext_telemetry_h
    jnz  Srot_dshot_tlm_ext_coded

    ; 12-bit encode telemetry data
    mov  A, Srot_tlm_data_h
    jnz  Srot_dshot_12bit_encode
    mov  A, Srot_tlm_data_l                  ; Already 12-bit
    jnz  Srot_dshot_tlm_12bit_encoded

    ; If period is zero then reset to FFFFh (FFFh for 12-bit)
    mov  Srot_tlm_data_h, #0Fh
    mov  Srot_tlm_data_l, #0FFh
    sjmp Srot_dshot_tlm_12bit_encoded

Srot_dshot_tlm_ext_coded:
    ; Move extended telemetry data to telemetry data to send
    mov  Srot_tlm_data_l, Srot_ext_telemetry_l
    mov  Srot_tlm_data_h, Srot_ext_telemetry_h
    ; Clear extended telemetry data
    mov  Srot_ext_telemetry_h, #0

Srot_dshot_tlm_12bit_encoded:
    Early_Return_Packet_Stage 2
    mov  A, Srot_tlm_data_l

    ; Compute inverted xor checksum (4-bit)
    swap A
    xrl  A, Srot_tlm_data_l
    xrl  A, Srot_tlm_data_h
    cpl  A

    ; GCR encode the telemetry data (16-bit)
    mov  Temp1, #Srot_temp_storage           ; Store pulse timings in Temp_Storage
    mov  @Temp1, Srot_dshot_gcr_pulse_time_1 ; Final transition time

    call Srot_dshot_gcr_encode               ; GCR encode lowest 4-bit of A (store through Temp1)

    Early_Return_Packet_Stage 3

    mov  A, Srot_tlm_data_l
    call Srot_dshot_gcr_encode

    Early_Return_Packet_Stage 4

    mov  A, Srot_tlm_data_l
    swap A
    call Srot_dshot_gcr_encode

    Early_Return_Packet_Stage 5

    mov  A, Srot_tlm_data_h
    call Srot_dshot_gcr_encode

    inc  Temp1
    mov  Temp7, #0                      ; Reset current packet stage

    pop  PSW
    setb Flag_Telemetry_Pending         ; Mark that packet is ready to be sent
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; DShot 12-bit encode
;
; Encodes 16-bit e-period as a 12-bit value of the form:
; <e e e m m m m m m m m m> where M SHL E ~ e-period [us]
;
; NOTE: Not callable to improve performance
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_dshot_12bit_encode:
    ; Encode 16-bit e-period as a 12-bit value
    jb   ACC.7, Srot_dshot_12bit_7           ; ACC = Tlm_Data_H
    jb   ACC.6, Srot_dshot_12bit_6
    jb   ACC.5, Srot_dshot_12bit_5
    jb   ACC.4, Srot_dshot_12bit_4
    jb   ACC.3, Srot_dshot_12bit_3
    jb   ACC.2, Srot_dshot_12bit_2
    jb   ACC.1, Srot_dshot_12bit_1
    mov  A, Srot_tlm_data_l                  ; Already 12-bit (E=0)
    jmp  Srot_dshot_tlm_12bit_encoded

Srot_dshot_12bit_7:
    ;mov  A, Tlm_Data_H
    mov  C, Srot_tlm_data_l.7
    rlc  A
    mov  Srot_tlm_data_l, A
    mov  Srot_tlm_data_h, #0fh
    jmp  Srot_dshot_tlm_12bit_encoded

Srot_dshot_12bit_6:
    ;mov  A, Tlm_Data_H
    mov  C, Srot_tlm_data_l.7
    rlc  A
    mov  C, Srot_tlm_data_l.6
    rlc  A
    mov  Srot_tlm_data_l, A
    mov  Srot_tlm_data_h, #0dh
    jmp  Srot_dshot_tlm_12bit_encoded

Srot_dshot_12bit_5:
    ;mov  A, Tlm_Data_H
    mov  C, Srot_tlm_data_l.7
    rlc  A
    mov  C, Srot_tlm_data_l.6
    rlc  A
    mov  C, Srot_tlm_data_l.5
    rlc  A
    mov  Srot_tlm_data_l, A
    mov  Srot_tlm_data_h, #0bh
    jmp  Srot_dshot_tlm_12bit_encoded

Srot_dshot_12bit_4:
    mov  A, Srot_tlm_data_l
    anl  A, #0f0h
    clr  Srot_tlm_data_h.4
    orl  A, Srot_tlm_data_h
    swap A
    mov  Srot_tlm_data_l, A
    mov  Srot_tlm_data_h, #09h
    jmp  Srot_dshot_tlm_12bit_encoded

Srot_dshot_12bit_3:
    mov  A, Srot_tlm_data_l
    mov  C, Srot_tlm_data_h.0
    rrc  A
    mov  C, Srot_tlm_data_h.1
    rrc  A
    mov  C, Srot_tlm_data_h.2
    rrc  A
    mov  Srot_tlm_data_l, A
    mov  Srot_tlm_data_h, #07h
    jmp  Srot_dshot_tlm_12bit_encoded

Srot_dshot_12bit_2:
    mov  A, Srot_tlm_data_l
    mov  C, Srot_tlm_data_h.0
    rrc  A
    mov  C, Srot_tlm_data_h.1
    rrc  A
    mov  Srot_tlm_data_l, A
    mov  Srot_tlm_data_h, #05h
    jmp  Srot_dshot_tlm_12bit_encoded

Srot_dshot_12bit_1:
    mov  A, Srot_tlm_data_l
    mov  C, Srot_tlm_data_h.0
    rrc  A
    mov  Srot_tlm_data_l, A
    mov  Srot_tlm_data_h, #03h
    jmp  Srot_dshot_tlm_12bit_encoded

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; DShot GCR encode
;
; GCR encode e-period data for DShot telemetry
;
; Input
; - Temp1: Data pointer for storing pulse timings
; - A: 4-bit value to GCR encode
; - B: Time that must be added to transition
;
; Output
; - B: Time remaining to be added to next transition
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_dshot_gcr_encode:
    anl  A, #0Fh
    rl   A                              ; Multiply by 2 to match jump offsets
    mov  DPTR, #Srot_dshot_gcr_encode_jump_table
    jmp  @A+DPTR

Srot_dshot_gcr_encode_jump_table:
    ajmp Srot_dshot_gcr_encode_0_11001
    ajmp Srot_dshot_gcr_encode_1_11011
    ajmp Srot_dshot_gcr_encode_2_10010
    ajmp Srot_dshot_gcr_encode_3_10011
    ajmp Srot_dshot_gcr_encode_4_11101
    ajmp Srot_dshot_gcr_encode_5_10101
    ajmp Srot_dshot_gcr_encode_6_10110
    ajmp Srot_dshot_gcr_encode_7_10111
    ajmp Srot_dshot_gcr_encode_8_11010
    ajmp Srot_dshot_gcr_encode_9_01001
    ajmp Srot_dshot_gcr_encode_a_01010
    ajmp Srot_dshot_gcr_encode_b_01011
    ajmp Srot_dshot_gcr_encode_c_11110
    ajmp Srot_dshot_gcr_encode_d_01101
    ajmp Srot_dshot_gcr_encode_e_01110
    ajmp Srot_dshot_gcr_encode_f_01111

; GCR encoding is ordered by least significant bit first,
; and represented as pulse durations.
Srot_dshot_gcr_encode_0_11001:
    imov Temp1, Srot_dshot_gcr_pulse_time_3
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    ret

Srot_dshot_gcr_encode_1_11011:
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    ret

Srot_dshot_gcr_encode_2_10010:
    GCR_Add_Time Temp1
    imov Temp1, Srot_dshot_gcr_pulse_time_3
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    ret

Srot_dshot_gcr_encode_3_10011:
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_3
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    ret

Srot_dshot_gcr_encode_4_11101:
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    ret

Srot_dshot_gcr_encode_5_10101:
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    ret

Srot_dshot_gcr_encode_6_10110:
    GCR_Add_Time Temp1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    ret

Srot_dshot_gcr_encode_7_10111:
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    ret

Srot_dshot_gcr_encode_8_11010:
    GCR_Add_Time Temp1
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    ret

Srot_dshot_gcr_encode_9_01001:
    imov Temp1, Srot_dshot_gcr_pulse_time_3
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    ret

Srot_dshot_gcr_encode_a_01010:
    GCR_Add_Time Temp1
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    ret

Srot_dshot_gcr_encode_b_01011:
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    ret

Srot_dshot_gcr_encode_c_11110:
    GCR_Add_Time Temp1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    ret

Srot_dshot_gcr_encode_d_01101:
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    ret

Srot_dshot_gcr_encode_e_01110:
    GCR_Add_Time Temp1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    ret

Srot_dshot_gcr_encode_f_01111:
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_1
    imov Temp1, Srot_dshot_gcr_pulse_time_2
    ret
