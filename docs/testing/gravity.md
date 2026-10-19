# Gravity mode verification — 2026-10-19

User journeys and implementation details are recorded in `codex.md` and the root update log. Scope is the Windows personal fork.

## RED / GREEN evidence

- `tests/gravity.test.ps1` was added before `runtime/gravity-model.cs`. The first run failed because the new physics implementation did not exist. After implementation the same target passed tap, charge, energy-dependent apex, repeated decay, drag/drop, cancellation, ceiling and frame-rate guarantees.
- A later release-shape continuity assertion failed on instantaneous squash reset. After adding 100 ms smooth recovery, the same target passed. Physics trajectories remain independent of the shape interpolation.
- `tests/gravity-wpf.test.ps1` initially exposed a fractional-DPI floor offset. Using actual HWND/Viewbox geometry fixed the visible-foot alignment; the test covers three scales and three DPI factors, both facing directions, native follower offset, unavailable-host pause, preference serialization and mode-disable cleanup.

## Regression results

| Target | Result |
| --- | --- |
| Node runtime suite (`node --test tests/*.test.mjs`) | 84 passed, 0 failed, 1 macOS-only fixture skipped |
| Pure gravity model | PASS |
| WPF gravity controller | PASS |
| Existing settings menu, plus top-level gravity toggle | PASS |
| Existing widget/reset-time/layout suite | PASS |
| Physical sizing | 288 cases passed |
| Desktop mode and preference preservation | PASS |
| Drag sizing | 6 DPI/mode cases, 20 drags and 20 placement updates per case passed |
| Display/off-screen recovery | 240 WPF/native size checks passed |
| Personal fork release-update guard | PASS |

The render preview uses the real XAML, original bitmap and production model at compressed, airborne, rebounding and settled poses. No image or license asset was changed. Frame-rate, floor and shape bounds are tested separately from visual inspection.

These checks are targeted evidence, not a claim of whole-project coverage or macOS gravity support. Task Scheduler startup on this particular computer remains the previously documented separate limitation.

Aether migration adds explicit tests for two-axis fling, wall restitution, friction to rest and reset. DLL is pinned with source/license/SHA256 in runtime/vendor/aether/NOTICE.md. Physics runs at 240 Hz independent of renderer rate. UI tests exercise the production controller with the actual dependency.

Production HWND tests also verify drag sampling, upward/rightward inertia, actual horizontal movement and rejection of stale drag history. Archive tests accept only the pinned dependency hash and reject substitutions; release updating remains disabled by the personal-fork policy.

Stable-launch regression: hash verification uses .NET SHA256 directly because the supervisor environment may lack PowerShell module autoload paths. WPF tests deliberately make Get-FileHash unavailable while loading the production controller.

## Motion tuning regression

`motion-tuning.test.ps1` first failed with a missing GptDragVelocity type, then passed after independent sampling and tuning were added. Stop/release cases cover 0.1, 0.5 and 1 second pauses; fast immediate release preserves both velocity components. More gravity produces a faster fall, while identical compression with different elasticity yields different jump heights.

A one-second invisible-HWND rendering harness on the same machine observed 36 callbacks with the previous dispatcher timer (median 29.3 ms, P95 46.2 ms) and 115 callbacks with the rendering event (median 6.2 ms, P95 28.1 ms). This is a local scheduling measurement, not a guarantee of on-screen FPS. Real display smoothness still depends on compositor/device load.

Window tests exercise actual horizontal movement, cancellation, mirrored full compression bounds, mode cleanup and persistence. Settings tests exercise separate mirror/gravity/elasticity controls. Original sizing, desktop mode and layout regressions remain required.
