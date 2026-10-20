# Adjustable vertical compression curve

AI-generated maintenance and documentation; insufficiently validated. No independent human review or whole-project coverage measurement.

User journey: control how quickly vertical squash starts and how gradually it brakes near maximum compression, using an adjustable curve when inexpensive. Preserve stored energy, recovery-before-takeoff and all existing physics controls.

Design: `C(t)=s*t+(3-2s)*t^2+(s-2)*t^3`, with s in [1.5,3], default 1.6. This normalized cubic has fixed endpoints, nonnegative decreasing first derivative and zero terminal derivative. Horner evaluation uses a few multiplications/additions. Incoming stretch fades with the same curve, so the combined vertical pose also decelerates, not just an isolated squash contribution. The recovery half cosine and existing phase durations remain unchanged. Snapshot the selected curve on actual contact; preview the next curve immediately without changing an animation in progress.

RED/GREEN evidence:

- RED: `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/compression-curve.test.ps1` failed because `SetCompressionCurve` was missing. Local checkpoint `0cae832`; synchronized metadata may produce different SHAs while preserving messages and trees.
- GREEN: the same target passes curve endpoints, monotonically decreasing compression speed, terminal braking, actual combined vertical displacement (including incoming stretch), visible adjustable response, identical height/velocity/energy/rebound timing across curve extremes, reset retention, invalid/default/bounded settings, no mid-contact pose jump, actual production bridge/save/load and old/invalid preference fallback.
- Actual settings-menu test passes slider bounds and labels, 25 preview points sampled from the real model, responsive graph changes and independence from conversion efficiency. The panel was also rendered locally for visual inspection using fictional test state.
- Energy-controls, collision-energy, elastic-impact, tap-compression, animation-speed, landing-easing/cycle, impact-squish, horizontal-impact, floor-contact, motion-tuning, gravity (722 assertions) and gravity-wpf (17 cases) pass in Windows PowerShell 5.1.
- Strict managed-frames test passes: input 97.29 Hz, processing 78.13 Hz, mean CPU 0.801 ms on this device. These local measurements do not guarantee frame rate elsewhere.
- Shared Node suite ultimately passes: 94 pass, 1 existing platform skip. An initial independent run of `refresh-recovery.test.mjs` reproduced a pre-existing 300 ms fixture deadline failure (~320 ms). Its silent-pipe phase used 90% of that deadline, leaving only 30 ms for real Windows file writes. The test deadline is now 3000 ms, retaining the same silent pipe, single writer, successful fallback, correlated response and cleanup assertions. The isolated test passes (~2728 ms) and the full suite passes. Production deadlines and refresh behavior were not changed.

Review: preview code runs only when settings open or change, never in the C# rendering hot path. It samples the same model function used for the animation; no separate approximation solver or new timer is introduced. The model snapshots the shape parameter at contact, preserving current motion when edited. Curve tuning does not change the reservoir or output kinetic energy. All user preferences and diagnostics remain local; tests use temporary fictional data.

Limits: a one-parameter curve family, not an arbitrary control-point editor. The range deliberately preserves continuous monotonic deceleration. This remains artistic deformation, not soft-body simulation. Visual and automated checks cover selected scenarios, not every device or intermediate state. No new-device install or Release publication is part of this task.
