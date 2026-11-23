# Thruster qualification record

Status: no hardware or water qualification performed for this reference package.
No increase in torque, thrust, efficiency, startup reliability or reversal
performance is claimed.

Before calling a future release a thruster improvement, record:

| Evidence | Required details |
|---|---|
| Hardware identity | ESC model, MCU, layout, gate deadtime and firmware file |
| Operating point | Thruster, propeller, battery voltage, temperature and water conditions |
| Baseline comparison | The installed firmware and settings, compared under the same conditions |
| Startup / low speed | Minimum repeatable motion, failed starts and startup current |
| Reversal | Stop/reverse delay, current transient, stalls and desynchronization |
| Steady operation | RPM, thrust, current, temperature and repeatability |
| Fault response | Signal loss, stalled motor and reset behavior |
| Integration | Correct configured direction, neutral behavior and RPM interpretation |

Use a documented test plan on appropriate test hardware. A source rebuild that
matches upstream is an integrity result, not a performance experiment.
Resolve or explicitly bound the inherited 3D-mode issue before recommending the
baseline for SROT's forward/reverse thrusters.
