; Compasless SROT ESC firmware
; SPDX-License-Identifier: GPL-3.0-or-later
; Copyright (C) 2026 Compasless contributors
; Copyleft  2022-2023 Daniel Mosquera
; Copyright 2020-2022 Mathias Rasmussen
; Copyright 2011-2017 Steffen Skaug
; Modified by Compasless on 2026-11-25; fixed 3D thruster operation.
; GPL version 3 or later; distributed WITHOUT ANY WARRANTY. See COPYING.

;
;

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; Programming defaults
;**** **** **** **** **** **** **** **** **** **** **** **** ****
DEFAULT_PGM_RPM_POWER_SLOPE EQU 9       ; 0=Off,1..13 (Power limit factor in relation to rpm)
DEFAULT_PGM_COMM_TIMING EQU 4           ; 1=Low 2=MediumLow 3=Medium 4=MediumHigh 5=High
DEFAULT_PGM_DEMAG_COMP EQU 2            ; 1=Disabled 2=Low 3=High
SROT_3D_DIRECTION EQU 3                 ; Fixed 3D thrust mapping; no selectable direction modes
DEFAULT_PGM_BEEP_STRENGTH EQU 40        ; 0..255 (BLHeli_S is 1..255)
DEFAULT_PGM_BEACON_STRENGTH EQU 80      ; 0..255
DEFAULT_PGM_BEACON_DELAY EQU 4          ; 1=1m 2=2m 3=5m 4=10m 5=Infinite
DEFAULT_PGM_ENABLE_TEMP_PROT EQU 0      ; 0=Disabled 1=80C 2=90C 3=100C 4=110C 5=120C 6=130C 7=140C

DEFAULT_PGM_POWER_RATING EQU 2          ; 1=1S,2=2S+

DEFAULT_PGM_BRAKE_ON_STOP EQU 0         ; 1=Enabled 0=Disabled
DEFAULT_PGM_LED_CONTROL EQU 0           ; Byte for LED control. 2 bits per LED,0=Off,1=On

DEFAULT_PGM_STARTUP_POWER_MIN EQU 21    ; 0..255 => (1000..1125 Throttle): value * (1000 / 2047) + 1000
DEFAULT_PGM_STARTUP_BEEP EQU 1          ; 0=Short beep,1=Melody

DEFAULT_PGM_STARTUP_POWER_MAX EQU 5     ; 0..255 => (1000..2000 Throttle): Maximum startup power
DEFAULT_PGM_BRAKING_STRENGTH EQU 255    ; 0..255 => 0..100 % Braking

DEFAULT_PGM_SAFETY_ARM EQU 0            ; EDT safety arm is disabled by default

;**** **** **** **** **** **** **** **** **** **** **** **** ****
