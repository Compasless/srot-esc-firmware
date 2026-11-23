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

;**** **** **** **** **** **** **** **** **** **** **** **** ****
; EEPROM code segments
; A segment of the flash is used as "EEPROM", which is not available in SiLabs MCUs
;**** **** **** **** **** **** **** **** **** **** **** **** ****
CSEG AT CSEG_EEPROM
EEPROM_FW_MAIN_REVISION EQU 0           ; Main revision of the firmware
EEPROM_FW_SUB_REVISION EQU 3            ; Sub revision of the firmware
EEPROM_LAYOUT_REVISION EQU 208          ; Revision of the EEPROM layout
EEPROM_B2_PARAMETERS_COUNT EQU 28       ; Number of parameters

Srot_eep_fw_main_revision: DB EEPROM_FW_MAIN_REVISION ; EEPROM firmware main revision number
Srot_eep_fw_sub_revision: DB EEPROM_FW_SUB_REVISION ; EEPROM firmware sub revision number
Srot_eep_layout_revision: DB EEPROM_LAYOUT_REVISION ; EEPROM layout revision number
Srot__eep_pgm_gov_p_gain: DB 0FFh
Srot_eep_pgm_startup_power_min: DB DEFAULT_PGM_STARTUP_POWER_MIN
Srot_eep_pgm_startup_beep: DB DEFAULT_PGM_STARTUP_BEEP
Srot__eep_pgm_dithering: DB 0FFh
Srot_eep_pgm_startup_power_max: DB DEFAULT_PGM_STARTUP_POWER_MAX
Srot__eep_pgm_rampup_slope: DB 0FFh
Srot_eep_pgm_rpm_power_slope: DB DEFAULT_PGM_RPM_POWER_SLOPE ; EEPROM copy of programmed rpm power slope (formerly startup power)
Srot_eep_pgm_pwm_freq: DB (24 SHL PWM_FREQ)  ; Temporary method for display
Srot_eep_pgm_direction: DB DEFAULT_PGM_DIRECTION ; EEPROM copy of programmed rotation direction
Srot__eep__pgm_input_pol: DB 0FFh
Srot_eep_initialized_l: DB 055h              ; EEPROM initialized signature (lo byte)
Srot_eep_initialized_h: DB 0AAh              ; EEPROM initialized signature (hi byte)
; EEPROM parameters block 2 (B2)
Srot__eep_enable_tx_program: DB 0FFh         ; EEPROM TX programming enable
Srot_eep_pgm_braking_strength: DB DEFAULT_PGM_BRAKING_STRENGTH
Srot__eep_pgm_gov_setup_target: DB 0FFh
Srot__eep_pgm_startup_rpm: DB 0FFh
Srot__eep_pgm_startup_accel: DB 0FFh
Srot__eep_pgm_volt_comp: DB 0FFh
Srot_eep_pgm_comm_timing: DB DEFAULT_PGM_COMM_TIMING ; EEPROM copy of programmed commutation timing
Srot__eep_pgm_damping_force: DB 0FFh
Srot__eep_pgm_gov_range: DB 0FFh
Srot__eep_pgm_startup_method: DB 0FFh
Srot__eep_pgm_min_throttle: DB 0FFh          ; EEPROM copy of programmed minimum throttle
Srot__eep_pgm_max_throttle: DB 0FFh          ; EEPROM copy of programmed minimum throttle
Srot_eep_pgm_beep_strength: DB DEFAULT_PGM_BEEP_STRENGTH ; EEPROM copy of programmed beep strength
Srot_eep_pgm_beacon_strength: DB DEFAULT_PGM_BEACON_STRENGTH ; EEPROM copy of programmed beacon strength
Srot_eep_pgm_beacon_delay: DB DEFAULT_PGM_BEACON_DELAY ; EEPROM copy of programmed beacon delay
Srot__eep_pgm_throttle_rate: DB 0FFh
Srot_eep_pgm_demag_comp: DB DEFAULT_PGM_DEMAG_COMP ; EEPROM copy of programmed demag compensation
Srot__eep_pgm_bec_voltage_high: DB 0FFh
Srot__eep_pgm_center_throttle: DB 0FFh       ; EEPROM copy of programmed center throttle
Srot__eep_pgm_main_spoolup_time: DB 0FFh
Srot_eep_pgm_temp_prot_enable: DB DEFAULT_PGM_ENABLE_TEMP_PROT ; EEPROM copy of programmed temperature protection enable
Srot__eep_pgm_enable_power_prot: DB 0FFh     ; EEPROM copy of programmed low rpm power protection enable
Srot__eep_pgm_enable_pwm_input: DB 0FFh
Srot__eep_pgm_pwm_dither: DB 0FFh
Srot_eep_pgm_brake_on_stop: DB DEFAULT_PGM_BRAKE_ON_STOP ; EEPROM copy of programmed braking when throttle is zero
Srot_eep_pgm_led_control: DB DEFAULT_PGM_LED_CONTROL ; EEPROM copy of programmed LED control
Srot_eep_pgm_power_rating: DB DEFAULT_PGM_POWER_RATING ; EEPROM copy of programmed power rating
Srot_eep_pgm_safety_arm: DB DEFAULT_PGM_SAFETY_ARM ; Various flag settings: bit 0 is require edt enable to arm

Srot_eep_dummy: DB 0FFh                      ; EEPROM address for safety reason
CSEG AT CSEG_NAME
Srot_eep_name: DB "Compasless (.0) "         ; Name tag (16 Bytes)

CSEG AT CSEG_MELODY
Srot_eep_pgm_beep_melody: DB 2,58,4,32,52,66,13,0,69,45,13,0,52,66,13,0,78,39,211,0,69,45,208,25,52,25,0

    Interrupt_Table_Definition          ; SiLabs interrupts
