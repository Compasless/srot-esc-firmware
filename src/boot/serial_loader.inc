; Compasless SROT ESC firmware
; Preserved BLHeli serial bootloader and flash protocol.
; Source architecture/refactor Copyright (C) 2026 Compasless contributors.
; Derived from Bluejay v0.21.0; original notices are preserved below.
; SPDX-License-Identifier: GPL-3.0-or-later
; Original source: BLHeliBootLoad.inc
;


;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; BLHeli bootloader for SiLabs MCUs. Based upon AVRootloader (copyright HR)
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

XTAL EQU 25000000

BOOT_DELAY EQU XTAL/4                   ; About 250ms (don't set to fast to avoid connection problems)
BOOT_BAUDRATE EQU 19200                 ; Only used if no baudrate detection activated,XTAL is than important
BOOT_VERSION EQU 6                      ; Version 6 (must be not changed)
BOOT_PAGES EQU 1                        ; Number of flash segments for bootloader

UART_LOOP EQU 26                        ; Depends upon timing of putc,getc
BAUDTIME EQU ((XTAL/BOOT_BAUDRATE)/3)-UART_LOOP

SUCCESS EQU 030h
ERRORVERIFY EQU 0C0h
ERRORCOMMAND EQU 0C1h
ERRORCRC EQU 0C2h
ERRORPROG EQU 0C5h

POLYNOM EQU 0A001h                      ; CRC Polynom

Xl EQU R0                               ; Temporary X
Xh EQU R1
Paral EQU R2                            ; Params for UART
Parah EQU R3
Cmdl EQU R4                             ; Commands
Cmdh EQU R5
Cntl EQU R6                             ; Baudtime
Cnth EQU R7

DSEG AT 20h
Srot_bit_reg: DS 1                           ; Bit storage register
Srot_byte_reg: DS 1                          ; Byte storage register
Srot_crcl: DS 1                              ; CRC 16Bit
Srot_crch: DS 1
Srot_baudl: DS 1                             ; Baudtime
Srot_baudh: DS 1
Srot_bit_cnt: DS 1                           ; Counter in UART loops
Srot_byte_cntl: DS 1                         ; Generic counter
Srot_byte_cnth: DS 1
Srot_bl_flash_key_1: DS 1                    ; Flash keys
Srot_bl_flash_key_2: DS 1

CSEG AT CSEG_BOOT_START                 ; Bootloader start
Srot_init:
    clr  IE_EA

    ; Select register bank 0 for main program routines
    clr  PSW.3                          ; Select register bank 0 for main program routines

    ; Disable the WDT.
    mov  WDTCN, #0DEh                   ; Disable watchdog
    mov  WDTCN, #0ADh

    ; Initialize stack
    mov  SP, #0c0h                      ; Stack = 64 upper bytes of RAM
    ; Initialize clock
    mov  CLKSEL, #00h                   ; Set clock divider to 1
IF MCU_TYPE == MCU_BB1 or MCU_TYPE == MCU_BB2
    ; Initialize VDD monitor
    orl  VDM0CN, #080h                  ; Enable the VDD monitor
ENDIF
    mov  Srot_baudl, #38h                    ; Wait 100us
    mov  Srot_baudh, #03h
    acall Srot_waitf

    ; Initialize flash keys
    mov  Srot_bl_flash_key_1, #0A5h
    mov  Srot_bl_flash_key_2, #0F1h

    ; Initialize ports
    orl  RTX_MDIN, #(1 SHL RTX_PIN)     ; Set digital
    anl  RTX_MDOUT, #NOT(1 SHL RTX_PIN) ; Disable pushpull
    setb RTX_PORT.RTX_PIN               ; Set data high
    mov  RTX_SKIP, #0FFh
    mov  XBR2, #40h                     ; ; Enable crossbar

    ; Set number of connect attempts before exiting bootloader
    mov  Cmdh, #250

Srot_abd:
    ; Identifier scanning
    mov  Xl, #(low(BOOT_DELAY / 6)+1)
    mov  Xh, #(high(BOOT_DELAY / 6)+1)
    mov  Cmdl, #(high((BOOT_DELAY / 6) SHR 8)+1)
    mov  Srot_crcl, #0
    mov  Srot_crch, #0
    mov  DPTR, #Srot_boot_sign
    mov  Parah, #(Srot_boot_msg - Srot_boot_sign)
    mov  Srot_baudl, #low(BAUDTIME)
    mov  Srot_baudh, #high(BAUDTIME)

Srot_wait_for_low:
    jnb  RTX_PORT.RTX_PIN, ($+5)
    ajmp Srot_wait_for_low

; Identifier (BOOT_SIGN) scanning with timeout and checksum
Srot_id1:
    jb   RTX_PORT.RTX_PIN, Srot_id3          ; Look for high
    djnz Xl, Srot_id1                        ; Subtract 1 from X (BOOT_DELAY)
    djnz Xh, Srot_id1
    djnz Cmdl, Srot_id1

    ajmp Srot_exit

Srot_id3:
    jnb  RTX_PORT.RTX_PIN, Srot_id4          ; Look for low
    djnz Xl, Srot_id3                        ; Subtract 1 from X (BOOT_DELAY)
    djnz Xh, Srot_id3
    djnz Cmdl, Srot_id3

    ajmp Srot_exit

Srot_id4:
    acall Srot_getx                          ; Read character
    clr  A
    movc A, @A+DPTR                     ; Load BOOT_SIGN character
    inc  DPTR
    clr  C
    subb A, Paral                       ; Compare with read character
    jz   Srot_id5
    djnz Cmdh, Srot_abd                      ; Retry if not last connect attempt
    ajmp Srot_exit

Srot_id5:
    djnz Parah, Srot_id1

    acall Srot_getw                          ; Read CRC
    jz   ($+4)                          ; Check CRC
    ajmp Srot_abd

    ; Send info about chip/bootloader (BOOT_MSG + BOOT_INFO)
    mov  Parah, #((Srot_boot_info - Srot_boot_msg) + 4)
Srot_in1:
    clr  A
    movc A, @A+DPTR                     ; Load character
    mov  Paral, A
    inc  DPTR
    acall Srot_putc
    djnz Parah, Srot_in1

; Main commandloop
; 0=Run/restart
; 1=Program flash, 2=Erase flash, 3=Read flash
; 0xFF=Set address, 0xFE=Set buffer, 0xFD=Keep alive
Srot_main:
    mov  Paral, #SUCCESS
Srot_mai1:
    acall Srot_putc
    mov  Srot_crcl, #0                       ; Reset CRC
    mov  Srot_crch, #0
    acall Srot_getw                          ; Get command
    mov  A, Paral
    mov  Cmdl, A
    mov  A, Parah
    mov  Cmdh, A
    clr  C
    mov  A, Cmdh
    subb A, #0FEh
    jc   Srot_mai2                           ; Jump if not set address or set buffer

    acall Srot_getw                          ; Address or number of bytes
    mov  Srot_byte_cntl, Paral               ; Store number of bytes for set buffer
    mov  Srot_byte_cnth, Parah
    mov  A, Cmdh
    jnb  ACC.0, Srot_mai2                    ; Jump if set buffer

    mov  DPL, Paral                     ; Store flash address (for set address)
    mov  DPH, Parah

Srot_mai2:
    acall Srot_getw                          ; Get CRC
    mov  Paral, #ERRORCRC
    jnz  Srot_mai1
    clr  C
    mov  A, Cmdh
    subb A, #0FEh
    jz   Srot_setbuf                         ; If command is set buffer,receive data
    jnc  Srot_main

    cjne Cmdh, #0, Srot_mai4                 ; Jump if command != 0 (and not set buffer)

    ; Run application/restart bootloader
    mov  A, Cmdl
    jz   Srot_rst
Srot_exit:
    mov  Srot_bit_access, #0                 ; Clear variable used by flash lock detect
    mov  Srot_bit_access_int, #0FFh          ; Set variable to indicate that program execution came from bootloader

    ; Lock flash by setting invalid values
    mov  Srot_bl_flash_key_1, #0
    mov  Srot_bl_flash_key_2, #0

    ljmp 0000h
Srot_rst:
    ajmp Srot_init

; Set buffer
Srot_setbuf:
    mov  Xl, Srot_byte_cntl                  ; Set number of bytes
    mov  Xh, Srot_byte_cnth
    inc  Xl
    inc  Xh
Srot_set4:
    djnz Xl, Srot_set5
    djnz Xh, Srot_set5
    ajmp Srot_set6

Srot_set5:
    acall Srot_getc                          ; Receive data
    mov  A, Paral
    movx @Xl, A                         ; Store data in XRAM
    ajmp Srot_set4

Srot_set6:
    inc  Cmdh
    ajmp Srot_mai2

Srot_mai4:
    clr  C
    mov  A, Cmdh
    subb A, #3
    jnc  Srot_mai5                           ; Jump if command >= 3

    ; Program/erase
    mov  A, Cmdh
    mov  C, ACC.0
    mov  Srot_bit_reg.0, C
    mov  Paral, #ERRORPROG
    clr  C
    mov  A, DPL
    subb A, #low(CSEG_BOOT_START)
    mov  A, DPH
    subb A, #high(CSEG_BOOT_START)
    jnc  Srot_mai1                           ; Jump if in bootloader segment
    jb   Srot_bit_reg.0, Srot_pro3                ; Jump if program command

    ; Erase flash
    orl  PSCTL, #02h                    ; Set the PSEE bit
    orl  PSCTL, #01h                    ; Set the PSWE bit
    mov  FLKEY, Srot_bl_flash_key_1          ; First key code
    mov  FLKEY, Srot_bl_flash_key_2          ; Second key code
    movx @DPTR, A
    jnb  Srot_bit_reg.0, Srot_pro6                ; Jump if erase command

; Program flash
Srot_pro3:
    mov  Xl, Srot_byte_cntl                  ; Set number of bytes
    mov  Xh, Srot_byte_cnth
    inc  Xl
    inc  Xh
    orl  PSCTL, #01h                    ; Set the PSWE bit
    anl  PSCTL, #0FDh                   ; Clear the PSEE bit
Srot_pro4:
    djnz Xl, Srot_pro5
    djnz Xh, Srot_pro5
    ajmp Srot_pro6

Srot_pro5:
    clr  C
    mov  A, DPH                         ; Check that address is not in bootloader area
    subb A, #BOOTLOADER_OFFSET
    jc   ($+5)

    inc  DPTR                           ; Increment flash address
    ajmp Srot_pro4

    movx A, @Xl                         ; Read from XRAM
    mov  FLKEY, Srot_bl_flash_key_1          ; First key code
    mov  FLKEY, Srot_bl_flash_key_2          ; Second key code
    movx @DPTR, A                       ; Write to flash
    inc  DPTR                           ; Increment flash address
    ajmp Srot_pro4

Srot_pro6:
    anl  PSCTL, #0FCh                   ; Clear the PSEE and PSWE bits
    ajmp Srot_main                           ; Successfully done erase or program

; Read flash
Srot_mai5:
    mov  Paral, #ERRORCOMMAND           ; Illegal command
    cjne Cmdh, #3, Srot_mai6                 ; Jump if not read flash command

Srot_rd1:
    clr  A
    movc A, @A+DPTR                     ; Read from flash
    inc  DPTR                           ; Increment flash address
    mov  Paral, A
    acall Srot_putp
    djnz Cmdl, Srot_rd1                      ; Decrement bytes to read

    acall Srot_putw                          ; CRC
    ajmp Srot_main

Srot_mai6:
    ajmp Srot_mai1

; Send char with crc
Srot_putw:
    mov  Paral, Srot_crcl
    mov  Parah, Srot_crch
    acall Srot_putc
    mov  A, Parah
    mov  Paral, A
Srot_putp:
    mov  A, Paral
    xrl  Srot_crcl, A
    mov  Srot_bit_cnt, #8
Srot_put1:
    clr  C
    mov  A, Srot_crch
    rrc  A
    mov  Srot_crch, A
    mov  A, Srot_crcl
    rrc  A
    mov  Srot_crcl, A
    jnc  Srot_put2

    xrl  Srot_crch, #high(POLYNOM)
    xrl  Srot_crcl, #low(POLYNOM)

Srot_put2:
    djnz Srot_bit_cnt, Srot_put1

; Send char
Srot_putc:
    acall Srot_waitf
    acall Srot_waitf
    mov  Srot_bit_cnt, #10
    mov  A, Paral
    cpl  A
Srot_put3:
    jb   Srot_bit_reg.1, ($+5)
    setb RTX_PORT.RTX_PIN               ; Set pin high
    jnb  Srot_bit_reg.1, ($+5)
    clr  RTX_PORT.RTX_PIN               ; Set pin low
    acall Srot_waitf
    clr  C
    rrc  A
    jc   Srot_put4

    clr  Srot_bit_reg.1

Srot_put4:
    djnz Srot_bit_cnt, Srot_put3
    ret

; Receive char/word
Srot_getw:
    acall Srot_getc
    mov  A, Paral
    mov  Parah, A
Srot_getc:
    jb   RTX_PORT.RTX_PIN, ($+5)        ; Wait for high
    ajmp Srot_getc

Srot_get1:
    jnb  RTX_PORT.RTX_PIN, ($+5)        ; Wait for low
    ajmp Srot_get1

Srot_getx:
    mov  Srot_bit_cnt, #8
    mov  Cntl, Srot_baudl
    mov  Cnth, Srot_baudh
    clr  C
    mov  A, Cnth                        ; Wait half a baud
    rrc  A
    mov  Cnth, A
    mov  A, Cntl
    rrc  A
    mov  Cntl, A
    acall Srot_waith

Srot_get2:
    acall Srot_waitf                         ; Wait one baud
    clr  C
    mov  A, Paral
    rrc  A
    jnb  RTX_PORT.RTX_PIN, ($+5)
    orl  A, #080h

    mov  Paral, A
    jnb  ACC.7, ($+6)
    xrl  Srot_crcl, #low(POLYNOM)

    clr  C
    mov  A, Srot_crch
    rrc  A
    mov  Srot_crch, A
    mov  A, Srot_crcl
    rrc  A
    mov  Srot_crcl, A
    jnc  Srot_get3

    xrl  Srot_crch, #high(POLYNOM)
    xrl  Srot_crcl, #low(POLYNOM)

Srot_get3:
    djnz Srot_bit_cnt, Srot_get2
    mov  A, Srot_crcl
    xrl  A, Srot_crch
    xrl  A, Srot_crch
    mov  Srot_crcl, A
    ret

; UART delays
Srot_waitf:
    mov  Cntl, Srot_baudl
    mov  Cnth, Srot_baudh

Srot_waith:
    inc  Cntl
    inc  Cnth

Srot_wait1:
    djnz Cntl, Srot_wait1
    djnz Cnth, Srot_wait1

    setb Srot_bit_reg.1
    ret

Srot_boot_sign: DB "BLHeli"
Srot_boot_msg: DB "471d"                     ; Interface-MCU_BootlaoderRevision
Srot_boot_info: DB SIGNATURE_001,SIGNATURE_002,BOOT_VERSION,BOOT_PAGES
