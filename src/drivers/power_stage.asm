; Compasless SROT ESC firmware
; FET power-stage switching and shutdown.
; Source architecture/refactor Copyright (C) 2026 Compasless contributors.
; Derived from Bluejay v0.21.0; original notices are preserved below.
; SPDX-License-Identifier: GPL-3.0-or-later
; Original source: Modules/Power.asm
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
; Power control
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
; Power control
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Switch power off
;
; Switches all FETs off
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_switch_power_off:
    All_Pwm_Fets_Off                    ; Turn off all pwm FETs
    All_Com_Fets_Off                    ; Turn off all commutation FETs
    Set_All_Pwm_Phases_Off
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Set PWM limit low RPM
;
; Sets power limit for low RPM
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_set_pwm_limit:
    jb   Flag_High_Rpm, Srot_set_pwm_limit_high_rpm ; If high rpm,limit pwm by rpm instead

Srot_set_pwm_limit_low_rpm:
    ; Set pwm limit for startup phase to avoid burning the esc/motor during startup
    ; (Startup can happen after a desync caused by a crash, if that is the case it
    ; will be better to avoid burning esc/motor)
    mov  Temp1, Srot_pwm_limit_beg

    ; Exit if startup phase is set
    jb   Flag_Startup_Phase, Srot_set_pwm_limit_low_rpm_exit

    ; Set default pwm limit for other phases
    mov  Temp1, #0FFh                   ; Default full power

    mov  A, Srot_low_rpm_pwr_slope           ; Check if low RPM power protection is enabled
    jz   Srot_set_pwm_limit_low_rpm_exit     ; Exit if disabled (zero)

    mov  A, Srot_comm_period4x_h
    jz   Srot_set_pwm_limit_low_rpm_exit     ; Avoid divide by zero

    mov  A, #255                        ; Divide 255 by Comm_Period4x_H
    jnb  Flag_Initial_Run_Phase, Srot_set_pwm_limit_calculate ; More protection for initial run phase
    mov  A, #127

Srot_set_pwm_limit_calculate:
    mov  B, Srot_comm_period4x_h
    div  AB
    mov  B, Srot_low_rpm_pwr_slope           ; Multiply by slope
    mul  AB
    mov  Temp1, A                       ; Set new limit
    xch  A, B

    ; If RPM_PWM_LIMIT < 255 goto set_pwm_limit_check_limit_to_min
    jz   Srot_set_pwm_limit_check_limit_to_min ; Limit to max

    ; Limit is bigger than 0xFF -> set max pwm and exit
    mov  Srot_pwm_limit_by_rpm, #0FFh
    ret

Srot_set_pwm_limit_check_limit_to_min:
    clr  C
    mov  A, Temp1                       ; Limit to min
    subb A, Srot_pwm_limit_beg
    jnc  Srot_set_pwm_limit_low_rpm_exit

    mov  Temp1, Srot_pwm_limit_beg

Srot_set_pwm_limit_low_rpm_exit:
    mov  Srot_pwm_limit_by_rpm, Temp1
    ret

;**** **** **** **** **** **** **** **** **** **** **** **** ****
;
; Set PWM limit high RPM
;
; Sets power limit for high RPM
;
;**** **** **** **** **** **** **** **** **** **** **** **** ****
Srot_set_pwm_limit_high_rpm:
    clr  C
    mov  A, Srot_comm_period4x_l
IF MCU_TYPE == MCU_BB2 or MCU_TYPE == MCU_BB51
    subb A, #0A0h                       ; Limit Comm_Period4x to 160,which is ~510k erpm
ELSE
    subb A, #0E4h                       ; Limit Comm_Period4x to 228,which is ~358k erpm
ENDIF
    mov  A, Srot_comm_period4x_h
    subb A, #00h

    mov  A, Srot_pwm_limit_by_rpm
    jnc  Srot_set_pwm_limit_high_rpm_inc_limit

    dec  A
    sjmp Srot_set_pwm_limit_high_rpm_store

Srot_set_pwm_limit_high_rpm_inc_limit:
    inc  A

Srot_set_pwm_limit_high_rpm_store:
    jz   Srot_set_pwm_limit_high_rpm_end
    mov  Srot_pwm_limit_by_rpm, A

Srot_set_pwm_limit_high_rpm_end:
    ret
