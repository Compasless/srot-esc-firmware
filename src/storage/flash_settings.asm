; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft  2022-2023 Daniel Mosquera
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-25; fixed 3D thruster operation.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
; ESC programming (EEPROM emulation)
;

;
; ESC programming (EEPROM emulation)
;
; The BB EFM8 technically does not have a dedicated EEPROM but in upstream a
; part of the flash space is dedicated to emulate an EEPROM. This is the space
; that holds all the settings and is what the configurator reads/writes ( via
; the bootloader).
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

ESC_LAYOUT_SIZE         EQU 48
MELODY_SIZE             EQU 140


;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Read all "EEPROM" parameters
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_read_all_eeprom_parameters:
    ; Check initialized signature
    mov  DPTR, #Srot_eep_initialized_l
    mov  Temp1, #Srot_bit_access
    call Srot_read_eeprom_byte
    mov  A, Srot_bit_access
    cjne A, #055h, Srot_read_eeprom_store_defaults
    inc  DPTR                           ; Now Eep_Initialized_H
    call Srot_read_eeprom_byte
    mov  A, Srot_bit_access
    cjne A, #0AAh, Srot_read_eeprom_store_defaults
    sjmp Srot_read_eeprom_read

Srot_read_eeprom_store_defaults:
    Unlock_Flash
    call Srot_set_default_parameters
    call Srot_erase_and_store_all_in_eeprom
    Lock_Flash
    sjmp Srot_read_eeprom_exit

Srot_read_eeprom_read:
    ; Read "EEPROM"
    mov  DPTR, #Srot__eep_pgm_gov_p_gain
    mov  Temp1, #Srot__pgm_gov_p_gain
    mov  Temp4, #10                     ; 10 parameters

Srot_read_eeprom_block1:
    call Srot_read_eeprom_byte
    inc  DPTR
    inc  Temp1
    djnz Temp4, Srot_read_eeprom_block1

    ; Read "EEPROM" after Eep_Initialized_x flags
    ; Temp4 = EEPROM_B2_PARAMETERS_COUNT parameters: [_Eep_Enable_TX_Program - Eep_Pgm_Power_Rating]
    mov  DPTR, #Srot__eep_enable_tx_program
    mov  Temp1, #Srot__pgm_enable_tx_program
    mov  Temp4, #EEPROM_B2_PARAMETERS_COUNT

Srot_read_eeprom_block2:
    call Srot_read_eeprom_byte
    inc  DPTR
    inc  Temp1
    djnz Temp4, Srot_read_eeprom_block2

    ; Set pointer to uncritical area
    mov  DPTR, #Srot_eep_dummy

Srot_read_eeprom_exit:
    ; Preserve the EEPROM wire layout while ignoring all legacy mode selections.
    mov  Temp1, #Srot_pgm_direction
    mov  @Temp1, #SROT_3D_DIRECTION
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Erase flash and store all parameter values in "EEPROM"
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_erase_and_store_all_in_eeprom:
    clr  IE_EA                          ; Disable interrupts
    ; Every settings-write entry point persists the sole supported operating mode.
    mov  Temp1, #Srot_pgm_direction
    mov  @Temp1, #SROT_3D_DIRECTION
    call Srot_read_esc_layout
    call Srot_read_melody
    call Srot_erase_flash

    ; Store firmware main revision
    mov  DPTR, #Srot_eep_fw_main_revision
    mov  A, #EEPROM_FW_MAIN_REVISION
    call Srot_write_eeprom_byte_from_acc

    ; Store firmware sub revision
    inc  DPTR
    mov  A, #EEPROM_FW_SUB_REVISION
    call Srot_write_eeprom_byte_from_acc

    ; Store layout revision
    inc  DPTR
    mov  A, #EEPROM_LAYOUT_REVISION
    call Srot_write_eeprom_byte_from_acc

    ; Write eeprom before Eep_Initialized_x flags
    ; Temp4 = 10 parameters [_Eep_Pgm_Gov_P_Gain - Eep_Initialized_x]
    mov  DPTR, #Srot__eep_pgm_gov_p_gain
    mov  Temp1, #Srot__pgm_gov_p_gain
    mov  Temp4, #10

Srot_write_eeprom_block1:
    call Srot_write_eeprom_byte
    inc  DPTR
    inc  Temp1
    djnz Temp4, Srot_write_eeprom_block1

    ; Write eeprom after Eep_Initialized_x flags
    ; Temp4 = EEPROM_B2_PARAMETERS_COUNT parameters: [_Eep_Enable_TX_Program - Eep_Pgm_Power_Rating]
    mov  DPTR, #Srot__eep_enable_tx_program
    mov  Temp1, #Srot__pgm_enable_tx_program
    mov  Temp4, #EEPROM_B2_PARAMETERS_COUNT

Srot_write_eeprom_block2:
    call Srot_write_eeprom_byte
    inc  DPTR
    inc  Temp1
    djnz Temp4, Srot_write_eeprom_block2

    ; Now write tags, melogy and signature
    call Srot_write_esc_layout
    call Srot_write_melody
    call Srot_write_eeprom_signature

    ; Set pointer to uncritical area
    mov  DPTR, #Srot_eep_dummy

    ; Allow the flash controller to settle data down
    call Srot_wait200ms
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Read eeprom byte
;
; ASSERT:
; - Target address in DPTR
; - Destination address in Temp1
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_read_eeprom_byte:
    clr  A
    movc A, @A+DPTR                     ; Read from flash
    mov  @Temp1, A
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Write eeprom byte
;
; ASSERT:
; - Data in address given by Temp1
; - Destination address in DPTR
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_write_eeprom_byte:
    mov  A, @Temp1

; Shorthand if data is already in accumulator
Srot_write_eeprom_byte_from_acc:
    orl  PSCTL, #01h                    ; Set the PSWE bit
    anl  PSCTL, #0FDh                   ; Clear the PSEE bit
    mov  Temp8, A
    clr  C
    mov  A, DPH                         ; Check that address is not in bootloader area
    subb A, #BOOTLOADER_OFFSET
    jc   Srot_write_eeprom_byte_write
    ret

Srot_write_eeprom_byte_write:
    mov  A, Temp8

    ; Attempt to unlock flash
    mov  FLKEY, Srot_flash_key_1             ; First key code
    mov  FLKEY, Srot_flash_key_2             ; Second key code

    movx @DPTR, A                       ; Write to flash
    anl  PSCTL, #0FEh                   ; Clear the PSWE bit
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Erase flash (erases the flash segment used for "eeprom" variables)
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_erase_flash:
    orl  PSCTL, #02h                    ; Set the PSEE bit
    orl  PSCTL, #01h                    ; Set the PSWE bit

    ; Attempt to unlock flash
    mov  FLKEY, Srot_flash_key_1             ; First key code
    mov  FLKEY, Srot_flash_key_2             ; Second key code

    mov  DPTR, #Srot_eep_initialized_l
    movx @DPTR, A
    anl  PSCTL, #0FCh                   ; Clear the PSEE and PSWE bits
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Write eeprom signature
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_write_eeprom_signature:
    mov  DPTR, #Srot_eep_initialized_l
    mov  A, #055h
    call Srot_write_eeprom_byte_from_acc

    mov  DPTR, #Srot_eep_initialized_h
    mov  A, #0AAh
    call Srot_write_eeprom_byte_from_acc
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Read esc layout bytes from flash and store in temporary storage
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_read_esc_layout:
    mov  Temp3, #ESC_LAYOUT_SIZE        ; Number of esc layout bytes
    mov  Temp2, #Srot_temp_storage           ; Set RAM address
    mov  Temp1, #Srot_bit_access
    mov  DPTR, #Srot_eep_esc_layout          ; Set flash address
Srot_read_esc_layout_byte:
    call Srot_read_eeprom_byte
    mov  A, Srot_bit_access
    mov  @Temp2, A                      ; Write to RAM
    inc  Temp2
    inc  DPTR
    djnz Temp3, Srot_read_esc_layout_byte
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Write all esc layout bytes from temporary storage and
; store them in flash
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_write_esc_layout:
    mov  Temp3, #ESC_LAYOUT_SIZE        ; Number of esc layout bytes
    mov  Temp2, #Srot_temp_storage           ; Set RAM address
    mov  DPTR, #Srot_eep_esc_layout          ; Set flash address
Srot_write_esc_layout_byte:
    mov  A, @Temp2                      ; Read from RAM
    call Srot_write_eeprom_byte_from_acc
    inc  Temp2
    inc  DPTR
    djnz Temp3, Srot_write_esc_layout_byte
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Melody
;**** **** **** **** **** **** **** **** **** **** **** **** ****

; Read 140  bytes from "EEPROM" and store in external memory (XRAM)
Srot_read_melody:
    mov  Temp3, #MELODY_SIZE            ; Number of bytes
    mov  Temp2, #0                      ; Set XRAM address
    mov  Temp1, #Srot_bit_access
    mov  DPTR, #Srot_eep_pgm_beep_melody     ; Set flash address
Srot_read_melody_byte:
    call Srot_read_eeprom_byte
    mov  A, Srot_bit_access
    movx @Temp2, A                      ; Write to XRAM
    inc  Temp2
    inc  DPTR
    djnz Temp3, Srot_read_melody_byte
    ret

; Read 140 bytes from external memory (XRAM) and store them in "EEPROM"
Srot_write_melody:
    mov  Temp3, #MELODY_SIZE            ; Number of bytes
    mov  Temp2, #0                      ; Set XRAM address
    mov  DPTR, #Srot_eep_pgm_beep_melody     ; Set flash address
Srot_write_melody_byte:
    movx A, @Temp2                      ; Read from XRAM
    call Srot_write_eeprom_byte_from_acc
    inc  Temp2
    inc  DPTR
    djnz Temp3, Srot_write_melody_byte
    ret
