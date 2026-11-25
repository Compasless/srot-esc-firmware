# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Execute compiled 3D policy paths using a fail-closed MCS-51 instruction subset."""
from mcs51_check import Machine

def require(condition, message):
    if not condition:
        raise ValueError("3D policy: " + message)

def check_policy(memory, symbols, exhaustive=False):
    require(not any(name in symbols for name in
                    ("flag_pgm_bidir", "flag_pgm_dir_rev", "flag_user_reverse_requested")),
            "legacy mode selector remains")
    modes = range(256) if exhaustive else (0, 1, 2, 3, 4, 255)
    for value in modes:
        for entry, stops in (
            ("Srot_read_eeprom_exit", ()),
            ("Srot_decode_settings", ("Srot_decode_protection",)),
            ("Srot_erase_and_store_all_in_eeprom", ("Srot_read_esc_layout",)),
        ):
            machine = Machine(memory, symbols)
            field = machine.address("Srot_pgm_direction")
            machine.ram[field] = value
            machine.carry = 1
            machine.run(entry, stops)
            require(machine.ram[field] == 3, f"{entry} retained legacy setting {value}")
    machine = Machine(memory, symbols)
    machine.run("Srot_set_default_parameters")
    require(machine.ram[machine.address("Srot_pgm_direction")] == 3, "default is not 3D")

    for command in range(1, 6):
        machine = Machine(memory, symbols)
        machine.named("Srot_dshot_cmd", command)
        expected_calls = [machine.address(name) for name in
                          ("Srot_switch_power_off", "Srot_beacon_beep", "Srot_wait200ms")]
        machine.hooks = {address: (lambda state: None) for address in expected_calls}
        machine.run("Srot_dshot_cmd_check")
        require(machine.calls == expected_calls, "beacon command changed")
        require(machine.named("Srot_dshot_cmd") == 0, "beacon command was not cleared")
        require(machine.bit(0xAF) == 1, "beacon command left interrupts disabled")

    commands = range(6, 48) if exhaustive else (7, 8, 9, 10, 12, 13, 14, 20, 21, 47)
    counts = range(8) if exhaustive else (5, 6)
    for command in commands:
        for count in counts:
            machine = Machine(memory, symbols)
            field = machine.address("Srot_pgm_direction")
            machine.ram[field] = 1 if command == 12 and count >= 6 else 3
            machine.named("Srot_dshot_cmd", command)
            machine.named("Srot_dshot_cmd_cnt", count)
            machine.flag("Flag_Ext_Tele", 1)
            machine.run("Srot_dshot_cmd_check", ("Srot_read_esc_layout",))
            require(machine.ram[field] == 3, f"command {command} selected a different mode")
            if command not in (12, 13, 14) or count < 6:
                require(not machine.calls, f"unsupported command {command} triggered an action")
                require(machine.flag("Flag_Ext_Tele") == 1, "ignored command changed EDT")
            if count < 6:
                require(machine.named("Srot_dshot_cmd") == command, "repeat requirement changed")
            elif command != 12:
                require(machine.named("Srot_dshot_cmd") == 0, "completed command was not cleared")
                if command in (13, 14):
                    require(machine.flag("Flag_Ext_Tele") == (command == 13), "EDT command changed")
                    require(machine.named("Srot_ext_telemetry_h") == 14, "EDT event missing")
            elif count >= 6:
                require(machine.calls[-1] == machine.address("Srot_read_esc_layout"),
                        "save settings did not reach fixed-mode persistence")

    values = range(4000) if exhaustive else (0, 1, 39, 40, 41, 1998, 1999, 2000, 2001, 2039, 2040, 3998, 3999)
    for value in values:
        machine = Machine(memory, symbols)
        machine.direct(0xD0, 8)  # Timer ISR uses register bank 1.
        machine.named("Srot_flags2", 6)  # Legacy mode bits cannot alter mapping.
        machine.register(3, value & 255)
        machine.register(4, value >> 8)
        machine.run("Srot_t1_int_normal_range", ("Srot_t1_int_scale_thrust_done",))
        magnitude = machine.register(3) | (machine.register(4) << 8)
        half_value = value % 2000
        expected = min(2047, half_value + half_value // 40)
        require(magnitude == expected, f"throttle {value} produced {magnitude}, expected {expected}")
        require(machine.flag("Flag_Rcp_Dir_Rev") == (value < 2000),
                f"throttle {value} selected the wrong rotation half")

    for current, requested, braking, period, stop, timeout in (
        (0, 0, 0, 0x20, 0, 10), (1, 1, 0, 0x20, 0, 10),
        (0, 1, 0, 0x20, 0, 10), (1, 0, 0, 0x20, 0, 10),
        (0, 1, 1, 0x3F, 0, 10), (0, 1, 1, 0x40, 0, 10),
        (0, 0, 0, 0xF0, 0, 10), (0, 0, 0, 0x20, 1, 0),
    ):
        machine = Machine(memory, symbols)
        machine.flag("Flag_Motor_Dir_Rev", current)
        machine.flag("Flag_Rcp_Dir_Rev", requested)
        machine.flag("Flag_Dir_Change_Brake", braking)
        machine.flag("Flag_Rcp_Stop", stop)
        machine.named("Srot_comm_period4x_h", period)
        machine.named("Srot_rcp_timeout_cntd", timeout)
        machine.named("Srot_pwm_limit_beg", 5)
        endpoint = machine.run("Srot_normal_run_checks", ("Srot_run1", "Srot_run4", "Srot_exit_run_mode"))
        if stop and not timeout or period >= 0xF0 and not braking and current == requested:
            require(endpoint == machine.address("Srot_exit_run_mode"), "stop/timeout exit changed")
        elif current != requested and not braking:
            require(endpoint == machine.address("Srot_run4"), "reversal did not start braking")
            require(machine.flag("Flag_Dir_Change_Brake") == 1, "braking flag not set")
            require(machine.named("Srot_pwm_limit_by_rpm") == 5, "reversal bypassed startup power limit")
        else:
            require(endpoint == machine.address("Srot_run1"), "3D run did not continue")
            if braking and period >= 0x40:
                require(machine.flag("Flag_Dir_Change_Brake") == 0, "braking did not finish")
                require(machine.flag("Flag_Motor_Dir_Rev") == requested, "reversal direction not applied")
                require(machine.named("Srot_initial_run_rot_cntd") == 18, "reversal restart guard changed")
    return {"fixed_mode": "3D", "legacy_commands_ignored": [7, 8, 9, 10, 20, 21],
            "saved_modes_normalized": True, "throttle_and_reversal_checked": True}
