; Compasless SROT ESC firmware
; Target constants, clocks and hardware selection.
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

$include (config\target_constants.inc)

; List of enumerated supported ESCs
;                                         PORT 0                   |  PORT 1                   |  PWM    COM    PWM    LED
;                                         P0 P1 P2 P3 P4 P5 P6 P7  |  P0 P1 P2 P3 P4 P5 P6 P7  |  inv    inv    side    n
;                                         -----------------------  |  -----------------------  |  -------------------------
IF MCU_TYPE == MCU_BB1 or MCU_TYPE == MCU_BB2
    A_ EQU 1                            ; Vn Am Bm Cm __ RX __ __  |  Ap Ac Bp Bc Cp Cc __ __  |  no     no     high   _
    B_ EQU 2                            ; Vn Am Bm Cm __ RX __ __  |  Cc Cp Bc Bp Ac Ap __ __  |  no     no     high   _
    C_ EQU 3                            ; RX __ Vn Am Bm Cm Ap Ac  |  Bp Bc Cp Cc __ __ __ __  |  no     no     high   _
    D_ EQU 4                            ; Bm Cm Am Vn __ RX __ __  |  Ap Ac Bp Bc Cp Cc __ __  |  no     yes    high   _
    E_ EQU 5                            ; Vn Am Bm Cm __ RX L0 L1  |  Ap Ac Bp Bc Cp Cc L2 __  |  no     no     high   3 Pinout like A, with LEDs
    F_ EQU 6                            ; Vn Cm Bm Am __ RX __ __  |  Ap Ac Bp Bc Cp Cc __ __  |  no     no     high   _
    G_ EQU 7                            ; Bm Cm Am Vn __ RX __ __  |  Ap Ac Bp Bc Cp Cc __ __  |  no     no     high   _ Pinout like D, but non-inverted com FETs
    H_ EQU 8                            ; Cm Vn Bm Am __ __ __ RX  |  Cc Bc Ac __ Cp Bp Ap __  |  no     no     high   _
    I_ EQU 9                            ; Vn Am Bm Cm __ RX __ __  |  Cp Bp Ap Cc Bc Ac __ __  |  no     no     high   _
    J_ EQU 10                           ; Am Cm Bm Vn RX L0 L1 L2  |  Ap Bp Cp Ac Bc Cc __ __  |  no     no     high   3
    K_ EQU 11                           ; RX Am Vn Bm __ Cm __ __  |  Ac Bc Cc Cp Bp Ap __ __  |  no     yes    high   _
    L_ EQU 12                           ; Cm Bm Am Vn __ RX __ __  |  Cp Bp Ap Cc Bc Ac __ __  |  no     no     high   _
    M_ EQU 13                           ; __ __ L0 RX Bm Vn Cm Am  |  __ Ap Bp Cp Ac Bc Cc __  |  no     no     high   1
    N_ EQU 14                           ; Vn Am Bm Cm __ RX __ __  |  Ac Ap Bc Bp Cc Cp __ __  |  no     no     high   _
    O_ EQU 15                           ; Bm Cm Am Vn __ RX __ __  |  Ap Ac Bp Bc Cp Cc __ __  |  no     yes    low    _ Pinout Like D, but low side pwm
    P_ EQU 16                           ; __ Cm Bm Vn Am RX __ __  |  __ Ap Bp Cp Ac Bc Cc __  |  no     no     high   _
    Q_ EQU 17                           ; __ RX __ L0 L1 Ap Bp Cp  |  Ac Bc Cc Vn Cm Bm Am __  |  no     no     high   2
    R_ EQU 18                           ; Vn Am Bm Cm __ RX __ __  |  Cp Bp Ap Cc Bc Ac __ __  |  no     no     high   _ Same as I
    S_ EQU 19                           ; Bm Cm Am Vn __ RX __ __  |  Ac Ap Bc Bp Cc Cp __ __  |  no     no     high   _
    T_ EQU 20                           ; __ Cm Vn Bm __ Am __ RX  |  Cc Bc Ac Ap Bp Cp __ __  |  no     no     high   _
    U_ EQU 21                           ; L2 L1 L0 RX Bm Vn Cm Am  |  __ Ap Bp Cp Ac Bc Cc __  |  no     no     high   3 Pinout like M, with 3 LEDs
    V_ EQU 22                           ; Am Bm Vn Cm __ RX __ Cc  |  Cp Bc __ __ Bp Ac Ap __  |  no     no     high   _
    W_ EQU 23                           ; __ __ Am Vn __ Bm Cm RX  |  __ __ __ __ Cp Bp Ap __  |  n/a    n/a    high   _ Tristate gate driver
    X_ EQU 24
    Y_ EQU 25
    Z_ EQU 26                           ; Bm Cm Am Vn __ RX __ __  |  Ac Ap Bc Bp Cc Cp __ __  |  yes    no     high   _ Pinout like S, but inverted pwm FETs

    ; Two letter layouts start here. Preferably the first letter is the base
    ; layout and the second letter is the variation in alphabetical order.
    OA_ EQU 27                          ; Bm Cm Am Vn __ RX __ __  |  Ap Ac Bp Bc Cp Cc __ __  |  no     yes    low    _ Pinout Like O, but open drain instead of push-pull COM FETs
ENDIF

; BB51 - Required
IF MCU_TYPE == MCU_BB51
    A_ EQU 1                            ; __ Bm Cm Am Vn RX __ __  |  Ap Ac Bp Bc Cp Cc __ __  |  no     no     low    _
    B_ EQU 2                            ; __ Bm Cm Am Vn RX __ __  |  Ac Ap Bc Bp Cc Cp __ __  |  no     yes    high   _
    C_ EQU 3                            ; __ Bm Cm Am Vn RX __ __  |  Ac Ap Bc Bp Cc Cp __ __  |  yes    yes    high   _
ENDIF

; Select the port mapping to use (or unselect all for use with external batch compile file)
;ESCNO            EQU    A_

; Select the MCU type (or unselect for use with external batch compile file)
;MCU_TYPE        EQU    0    ; BB1
;MCU_TYPE        EQU    1    ; BB2
;MCU_TYPE        EQU    2    ; BB51

; Select the FET dead time (or unselect for use with external batch compile file)
;DEADTIME            EQU    15    ; 20.4ns per step

; Select the pwm frequency (or unselect for use with external batch compile file)
;PWM_FREQ            EQU    0    ; 0=24, 1=48, 2=96 kHz

PWM_CENTERED EQU DEADTIME > 0           ; Use center aligned pwm on ESCs with dead time

IF MCU_TYPE == MCU_BB1
    IS_MCU_48MHZ EQU 0
ELSE
    IS_MCU_48MHZ EQU 1
ENDIF

IF PWM_FREQ == PWM_24 or PWM_FREQ == PWM_48 or PWM_FREQ == PWM_96
    ; Number of bits in pwm high byte
    PWM_BITS_H EQU (2 + IS_MCU_48MHZ - PWM_CENTERED - PWM_FREQ)
ENDIF

$include (hal\register_offsets.inc)
$include (memory\flash_map.inc)
$include (hal\target_select.inc)
$include (core\instruction_macros.inc)
