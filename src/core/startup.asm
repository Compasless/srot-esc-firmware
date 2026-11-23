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

Srot_pgm_start:
    Lock_Flash
    mov  WDTCN, #0DEh                   ; Disable watchdog (WDT)
    mov  WDTCN, #0ADh
    mov  SP, #Srot_stack                     ; Initialize stack (16 bytes of indirect RAM)
IF MCU_TYPE == MCU_BB1 or MCU_TYPE == MCU_BB2
    orl  VDM0CN, #080h                  ; Enable the VDD monitor
ENDIF
    mov  RSTSRC, #06h                   ; Set missing clock and VDD monitor as a reset source if not 1S capable
    mov  CLKSEL, #00h                   ; Set clock divider to 1 (Oscillator 0 at 24MHz)
    call Srot_switch_power_off
    ; Ports initialization
    mov  P0, #P0_INIT
    mov  P0MDIN, #P0_DIGITAL
    mov  P0MDOUT, #P0_PUSHPULL
    mov  P0, #P0_INIT
    mov  P0SKIP, #P0_SKIP
    mov  P1, #P1_INIT
    mov  P1MDIN, #P1_DIGITAL
    mov  P1MDOUT, #P1_PUSHPULL
    mov  P1, #P1_INIT
    mov  P1SKIP, #P1_SKIP
    mov  P2MDOUT, #P2_PUSHPULL
IF MCU_TYPE == MCU_BB2 or MCU_TYPE == MCU_BB51
    ; Not available on BB1
    mov  SFRPAGE, #20h
    mov  P2MDIN, #P2_DIGITAL
IF MCU_TYPE == MCU_BB2
    ; Not available on BB51
    mov  P2SKIP, #P2_SKIP
ENDIF
    mov  SFRPAGE, #00h
ENDIF
    Initialize_Crossbar                 ; Initialize the crossbar and related functionality
    call Srot_switch_power_off               ; Switch power off again,after initializing ports

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Internal RAM
;
; EFM8 consists of 256 bytes of internal RAM of which the lower 128 bytes can be
; directly adressed and the upper portion (starting at 0x80) can only be
; indirectly accessed.
;
; NOTE: Upper portion of RAM and SFR use the same address space. RAM is accessed
;       indirectly. If you are directly accessing the upper space, you are - in
;       fact - addressing the SFR.
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Clear internal RAM
;
; First the accumlator is cleared, then address is overflowed to 255 and content
; of addresses 255 - 0 is set to 0.
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
    clr  A                              ; Clear accumulator
    mov  Temp1, A                       ; Clear Temp1
Srot_clear_ram:
    mov  @Temp1, A                      ; Clear RAM address
    djnz Temp1, Srot_clear_ram               ; Decrement address and repeat

    call Srot_set_default_parameters         ; Set default programmed parameters
    call Srot_read_all_eeprom_parameters     ; Read all programmed parameters
    call Srot_decode_settings                ; Decode programmed settings

    ; Initializing beeps
    clr  IE_EA                          ; Disable interrupts explicitly
    call Srot_wait100ms                      ; Wait a bit to avoid audible resets if not properly powered
    call Srot_play_beep_melody               ; Play startup beep melody
    call Srot_led_control                    ; Set LEDs to programmed values

    call Srot_wait100ms                      ; Wait for flight controller to get ready

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; No signal entry point
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_init_no_signal:
    clr  IE_EA                          ; Disable interrupts explicitly
    Lock_Flash
    call Srot_switch_power_off

IF MCU_TYPE == MCU_BB2 or MCU_TYPE == MCU_BB51
    ; While not armed, all MCUs run at 24MHz clock frequency. After arming those
    ; MCUs that support it (BB2 & BB51) are switched to 48MHz clock frequency.
    Set_MCU_Clk_24MHz
ENDIF

    ; If input signal is high for about ~150ms, enter bootloader mode
    mov  Temp1, #9
    mov  Temp2, #0
    mov  Temp3, #0
Srot_input_high_check:
    jnb  RTX_BIT, Srot_bootloader_done       ; If low is detected, skip bootloader check
    djnz Temp3, Srot_input_high_check
    djnz Temp2, Srot_input_high_check
    djnz Temp1, Srot_input_high_check

    call Srot_beep_enter_bootloader

    ljmp CSEG_BOOT_START                ; Jump to bootloader

Srot_bootloader_done:
    ; If we had a signal before, reset the flag, beep, wait a bit and contiune
    ; with DSHOT setup. If we did not have a signal yet, continue with DSHOT
    ; setup straight away.
    jnb  Flag_Had_Signal, Srot_setup_dshot
    call Srot_beep_signal_lost

    ; Wait for flight controller to get ready
    call Srot_wait250ms
    call Srot_wait250ms
    call Srot_wait250ms
    clr  Flag_Had_Signal
