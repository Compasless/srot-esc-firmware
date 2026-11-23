; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft  2022-2023 Daniel Mosquera
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-24; module architecture and AUV defaults.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; Misc utility functions


;
; Misc utility functions
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Wait a number of milliseconds (Multiple entry points)
;
; Requirements:
; - System clock should be set to 24MHz
; - Interrupts should be disabled for precision
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_wait1ms:
    mov  Temp3, #0                      ; Milliseconds (hi byte)
    mov  Temp2, #1                      ; Milliseconds (lo byte)
    sjmp Srot_wait_ms

Srot_wait5ms:
    mov  Temp3, #0
    mov  Temp2, #5
    sjmp Srot_wait_ms

Srot_wait10ms:
    mov  Temp3, #0
    mov  Temp2, #10
    sjmp Srot_wait_ms

Srot_wait100ms:
    mov  Temp3, #0
    mov  Temp2, #100
    sjmp Srot_wait_ms

Srot_wait200ms:
    mov  Temp3, #0
    mov  Temp2, #200
    sjmp Srot_wait_ms

Srot_wait250ms:
    mov  Temp3, #0
    mov  Temp2, #250
    sjmp Srot_wait_ms

Srot_wait_ms:
    inc  Temp2                          ; Increment for use with djnz
    inc  Temp3
    sjmp Srot_wait_ms_start

Srot_wait_ms_o:                              ; Outer loop
    mov  Temp1, #24

Srot_wait_ms_m:                              ; Middle loop
    mov  A, #255
    djnz ACC, $                         ; Inner loop (41.6us - 1020 cycles)
    djnz Temp1, Srot_wait_ms_m

Srot_wait_ms_start:
    djnz Temp2, Srot_wait_ms_o
    djnz Temp3, Srot_wait_ms_o
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Beeper routines (Multiple entry points)
;
; Requirements:
; - Interrupts must be disabled and FETs turned off
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_beep_f1:
    mov  Temp3, #66                     ; Off wait loop length (Tone)
    mov  Temp4, #(3500 / 66)            ; Number of beep pulses (Duration)
    sjmp Srot_beep

Srot_beep_f2:
    mov  Temp3, #45
    mov  Temp4, #(3500 / 45)
    sjmp Srot_beep

Srot_beep_f3:
    mov  Temp3, #38
    mov  Temp4, #(3500 / 38)
    sjmp Srot_beep

Srot_beep_f4:
    mov  Temp3, #25
    mov  Temp4, #(3500 / 25)
    sjmp Srot_beep

Srot_beep_f5:
    mov  Temp3, #20
    mov  Temp4, #(3500 / 20)
    sjmp Srot_beep

Srot_beep_f1_short:
    mov  Temp3, #66
    mov  Temp4, #(2000 / 66)
    sjmp Srot_beep

Srot_beep_f2_short:
    mov  Temp3, #45
    mov  Temp4, #(2000 / 45)
    sjmp Srot_beep

Srot_beep:
    mov  A, Srot_beep_strength
    jnz  Srot_beep_start                     ; Start if beep strength is not 0
    ret

Srot_beep_start:
    mov  Temp2, #2

Srot_beep_on_off:
    clr  A
    B_Com_Fet_Off                       ; B com FET off
    djnz ACC, $                         ; Allow some time after com FET is turned off
    B_Pwm_Fet_On                        ; B pwm FET on (in order to charge the driver of the B com FET)
    djnz ACC, $                         ; Let the pwm FET be turned on a while
    B_Pwm_Fet_Off                       ; B pwm FET off again
    djnz ACC, $                         ; Allow some time after pwm FET is turned off
    B_Com_Fet_On                        ; B com FET on
    djnz ACC, $                         ; Allow some time after com FET is turned on

    mov  A, Temp2                       ; Turn on pwm FET
    jb   ACC.0, Srot_beep_a_pwm_on
    A_Pwm_Fet_On
Srot_beep_a_pwm_on:
    jnb  ACC.0, Srot_beep_c_pwm_on
    C_Pwm_Fet_On
Srot_beep_c_pwm_on:

    mov  A, Srot_beep_strength               ; On time according to beep strength
    djnz ACC, $

    mov  A, Temp2                       ; Turn off pwm FET
    jb   ACC.0, Srot_beep_a_pwm_off
    A_Pwm_Fet_Off
Srot_beep_a_pwm_off:
    jnb  ACC.0, Srot_beep_c_pwm_off
    C_Pwm_Fet_Off
Srot_beep_c_pwm_off:

    mov  A, #150                        ; Off for 25 us
    djnz ACC, $

    djnz Temp2, Srot_beep_on_off             ; Toggle next pwm FET

    mov  A, Temp3
Srot_beep_off:                               ; Fets off loop
    mov  Temp1, #200
    djnz Temp1, $
    djnz ACC, Srot_beep_off                  ; Off time according to beep frequency

    djnz Temp4, Srot_beep_start              ; Number of beep pulses (duration)

    B_Com_Fet_Off
    ret

; Beep sequences
Srot_beep_signal_lost:
    call Srot_beep_f1
    call Srot_beep_f2
    call Srot_beep_f3
    ret

Srot_beep_enter_bootloader:
    call Srot_beep_f2_short
    call Srot_beep_f1
    ret

Srot_beep_motor_stalled:
    call Srot_beep_f3
    call Srot_beep_f2
    call Srot_beep_f1
    ret

Srot_beep_safety_no_arm:
    call    Srot_beep_f2_short
    call    Srot_beep_f1_short
    ret


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Beacon beep
;
; Beep with beacon strength.
;
; Requirements:
; - Interrupts must be disabled
; - FETs must be turned off
; - Beep tone 1-5 in Temp1
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_beacon_beep:
    mov  Temp2, #Srot_pgm_beacon_strength    ; Set beacon beep strength
    mov  Srot_beep_strength, @Temp2

    cjne Temp1, #CMD_BEEP_1, Srot_beacon_beep2
    call Srot_beep_f1
    sjmp Srot_beacon_beep_exit

Srot_beacon_beep2:
    cjne Temp1, #CMD_BEEP_2, Srot_beacon_beep3
    call Srot_beep_f2
    sjmp Srot_beacon_beep_exit

Srot_beacon_beep3:
    cjne Temp1, #CMD_BEEP_3, Srot_beacon_beep4
    call Srot_beep_f3
    sjmp Srot_beacon_beep_exit

Srot_beacon_beep4:
    cjne Temp1, #CMD_BEEP_4, Srot_beacon_beep5
    call Srot_beep_f4
    sjmp Srot_beacon_beep_exit

Srot_beacon_beep5:
    call Srot_beep_f5

Srot_beacon_beep_exit:
    mov  Temp2, #Srot_pgm_beep_strength      ; Set normal beep strength
    mov  Srot_beep_strength, @Temp2
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Play beep melody
;
; Plays a beep melody from eeprom storage
;
; A melody has 64 pairs of (item1, item2) - a total of 128 items.
; the first 4 values of the 128 items are metadata
; item2 - is the duration of each pulse of the musical note.
;         The lower the value, the higher the pitch.
; item1 - if item2 is zero, it is the number of milliseconds of wait time, else
;         it is the number of pulses of item2.
;
; Requirements:
; - Interrupts must be disabled
; - FETs must be turned off
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_play_beep_melody:
    mov  DPTR, #(Srot_eep_pgm_beep_melody)
    clr  A
    movc A, @A+DPTR
    cpl  A
    jz   Srot_play_beep_melody_exit          ; If first byte is 255,skip startup melody (settings may be invalid)

    mov  Temp5, #62
    mov  DPTR, #(Srot_eep_pgm_beep_melody + 04h)

Srot_play_beep_melody_loop:
    ; Read current location at Eep_Pgm_Beep_Melody to Temp4 and increment DPTR. If the value is 0, no point trying to play this note
    clr  A
    movc A, @A+DPTR
    inc  DPTR
    mov  Temp4, A
    jz   Srot_play_beep_melody_exit

    ; Read current location at Eep_Pgm_Beep_Melody to Temp3. If the value zero, that means this is a silent note
    clr  A
    movc A, @A+DPTR
    mov  Temp3, A
    jz   Srot_play_beep_melody_item_wait_ms
    call Srot_beep
    sjmp Srot_play_beep_melody_loop_next_item

Srot_play_beep_melody_item_wait_ms:
    mov  A, Temp4
    mov  Temp2, A
    mov  Temp3, #0
    call Srot_wait_ms

Srot_play_beep_melody_loop_next_item:
    inc  DPTR
    djnz Temp5, Srot_play_beep_melody_loop

Srot_play_beep_melody_exit:
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; LED control
;
; Controls LEDs
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_led_control:
    mov  Temp1, #Srot_pgm_led_control
    mov  A, @Temp1
    mov  Temp2, A
    anl  A, #03h
    Set_LED_0
    jnz  Srot_led_0_done
    Clear_LED_0

Srot_led_0_done:
    mov  A, Temp2
    anl  A, #0Ch
    Set_LED_1
    jnz  Srot_led_1_done
    Clear_LED_1

Srot_led_1_done:
    mov  A, Temp2
    anl  A, #030h
    Set_LED_2
    jnz  Srot_led_2_done
    Clear_LED_2

Srot_led_2_done:
    mov  A, Temp2
    anl  A, #0C0h
    Set_LED_3
    jnz  Srot_led_3_done
    Clear_LED_3

Srot_led_3_done:
    ret
