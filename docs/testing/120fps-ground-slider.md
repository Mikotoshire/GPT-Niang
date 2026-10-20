# 120-Hz scheduling and ground-friction control

AI-generated maintenance changes and documentation; insufficiently validated. No independent human review or whole-project coverage measurement.

User request: allow 120 FPS or improve consistency above 60, and add a bottom-friction slider. Source synchronization is authorized; installer/Release publication is not.

## Behavior and implementation

- Raise `GptGravityRenderLoop.TargetFps` from 90 to 120. Keep rendering-time token budgeting, reentrancy guard, real elapsed physics time and fixed 240-Hz model substeps. No polling timer, extra presentation frames or display refresh-rate change is introduced. This is a processing ceiling, not a promise of 120 displayed frames.
- `重力与弹性 → 底部摩擦力`: 0–3x in 0.1x steps, default 1x. The model exposes `GroundFrictionMultiplier` / `SetGroundFriction`. The existing supported-ground deceleration becomes `0.18 * multiplier * EffectiveGravity`; 0 disables continuous sliding drag. Values are bounded and nonfinite input falls back to 1. Reset retains the selected multiplier.
- Store only the numeric `groundFriction` preference locally. Startup preserves explicit zero and ignores invalid or absent values, retaining 1x. Both initialization and the tuning bridge apply it; saving and menu refresh keep it consistent. Natural elasticity preset preserves the user's independent friction setting. Airborne inertia and the separate per-impact horizontal retention remain unchanged.
- Zero-friction testing uncovered false floor impacts: solver contact state can briefly disappear while visual floor holds repeatedly pin Y. A subsequent tiny solver fall could be counted as a fresh impact, repeatedly retaining only 0.82 of horizontal speed. Explicit `grounded` support now keeps a slide supported until takeoff, press/drag or reset. It applies time-based friction during support without inventing impacts. Releasing a downward fling at floor level still counts a real impact; a supported body can be tapped and jump again. Zero-friction slides can intentionally continue indefinitely until a wall, interaction or other actual energy loss.

## Verification

- RED: ground-friction test failed because the model lacked the default multiplier; managed-frames failed `Animation scheduling must allow 120 FPS` with the previous 90-Hz ceiling.
- During GREEN implementation, the zero-drag test failed with speed about 271 after starting at 600 and four false impacts. Explicit support fixes that; the test now asserts zero false impacts over a one-second ground slide. The first-ground-step test now verifies the exact time-based drag rather than its old arbitrary near-300 threshold.
- Ground-friction tests cover scaled deceleration, zero, both clamps, invalid values, live changes without an instantaneous velocity jump, Reset retention, airborne independence, repeated taps after support and production save/startup loading. Actual WPF menu tests cover bounds, label/value changes and independence from the natural preset. Tests are integrated into the Windows runner.
- Synthetic presentation tests retain bursty/jittered 60-Hz coverage, verify a 240-Hz input is capped near 120 updates, and retain all 120 valid frames of a one-second 120-Hz fixture. These are scheduler checks, not physical display measurements. The actual minimum-rate, CPU-budget, changing-window-position and limited-script-callback checks remain required; only the expected ceiling changes from 95 to 125 for the new 120 target.
- Two strict local WPF runs: processing 93.51 and 94.62 Hz (input 107.08 and 97.12 Hz), versus the previous roughly 79-Hz results. Mean step 2.851/4.478 ms, mean CPU 0.836/1.234 ms, max step 23.718/10.788 ms. Native placement remains the dominant measured cost. This does not establish a stable minimum of 60 at every instant or achievement of 120 on this device; test input differs across runs.
- Existing curve, horizontal impact, energy/duration, launch, landing, floor-contact, motion, gravity (637 assertions), WPF (17 cases), desktop, drag and settings-menu checks pass. Node: 94 passed, 1 existing platform fixture skipped. No image-quality or anti-aliasing settings changed.

Git checkpoints and external bundles preserve rollback. Private configuration, account/quota data, paths and runtime diagnostics are excluded from the public source.
