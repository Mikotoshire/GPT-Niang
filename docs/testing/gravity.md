# Gravity mode verification — 2026-10-19

> **AI 生成与验证声明：** 本维护分支相对上游的修改，以及新增或改写的文档，均由 AI 生成，且未经充分验证或独立人工审查。现有自动化测试与 AI 自查仅覆盖有限场景，不能保证正确性、稳定性、安全性或完整合规性，可能存在未发现的问题。仅供试用，请自行评估并备份重要数据。此声明不将上游原作或第三方依赖归为 AI 生成，也不改变原许可和权利归属。

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

## Floor contact and managed frame path

The old model reproduced a first-step snap to zero when released from 2–16 design DIP. The contact guard now requires IsTouching, and the floor edge has no extra skin radius. The new near-floor test requires nonzero height and increasing downward speed before actual landing, including 0.5-DIP releases.

Managed model/transform/native updates replace the per-frame PowerShell callback. A visible two-second HWND run at a 90-Hz scheduling target produced 151 updates, 74.4 effective updates/s, 131 changing native positions, 2.260-ms mean work, and seven script notifications. The actual installed follower run produced 201 updates at 73.6 updates/s and settled on the floor. Its maximum step was 48.28 ms; these are application measurements, not physical scan-out guarantees. A prior 60-Hz scheduling target measured only 55.1 updates/s in the real widget, so the target was raised with a bounded phase schedule.

Node runtime: 84 passed, one platform fixture skipped. Model, motion tuning, floor contact, 17 WPF controller cases, menu, desktop, drag sizing and 240 display sizing checks passed. Existing private settings were restored after live trajectory measurement.

## Horizontal collision retention

`horizontal-impact.test.ps1` verifies both directions over repeated collisions, 0.82 horizontal retention once per landing, vertical stop with continuing slide, no repeated penalty during persistent contact, and eventual settling through Aether ground friction. Starting a ground slide does not count as a new falling impact. Original gravity and near-floor tests remain required.
