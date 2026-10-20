# Elasticity-linked impact deformation

AI-generated maintenance and documentation; insufficiently validated. No independent human review or whole-project coverage measurement.

Journey: high drops must visibly squash more, and the existing elastic energy slider must increase landing deformation at the same impact speed. Retain the separate Q multiplier, smooth compression/recovery, neutral takeoff and bounded physical rebound.

- RED: `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/elastic-impact.test.ps1` executed and failed at `Same impact speed compresses more with higher elastic energy setting` (`43369f0`).
- GREEN: the same command passes. A 240-DIP drop at the default setting compresses at least 36%; a 900-DIP drop compresses at least 44%. At a fixed height, the 0.25/1/3 elasticity settings yield progressively larger compression. The maximum combination exceeds 65% compression but remains bounded at 72%; Q=0 still adds no landing squash. The later collision-energy implementation also makes the elastic energy setting increase rebound velocity; Q remains a visual multiplier without changing rebound energy. Repeated bounces recover and settle.
- Existing tap-compression, animation-speed, landing-easing, landing-cycle, impact-squish, horizontal-impact, floor-contact, motion-tuning, gravity (742 assertions), gravity-wpf (17 cases) and settings-menu regressions passed in Windows PowerShell 5.1. Menu test uses the runner's UTF-8 `-SettingsMenuOnly` path.
- `node --test tests/*.test.mjs`: 94 pass, 1 existing platform-specific skip, no failures.

Implementation review: the initial visual-only formula was superseded before synchronization by the shared collision energy reservoir described in `collision-energy.tdd.md`. Compression now derives from the retained energy, and releasing the same reservoir determines upward velocity. Saturation prevents zero/negative displayed height. Horizontal expansion retains the prior ratio and is bounded below 1.385; this is smaller than the already tested maximum charged width of 1.55. No new physics engine, timer, preference, file format, dependency or account access is introduced. Aether retains integration, contact detection and friction; the explicit reservoir now owns floor rebound. Floor dwell timing and easing functions remain unchanged.

Limits: this is artistic squash/stretch rather than a physical soft-body simulation. The stronger amplitude may reach the saturation limit at extreme settings; the animation-speed slider remains available. Targeted assertions and local WPF checks do not guarantee subjective appearance, every device or total-project coverage. Source synchronization only; no installer or Release is published.
