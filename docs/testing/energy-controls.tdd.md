# Independent collision conversion and slider audit

AI-generated maintenance and documentation; insufficiently validated. No independent human review or whole-project coverage claim.

User journey: expose collision energy conversion, audit previous sliders for overlap or dead ranges, preserve useful controls and existing preferences, and keep source backup separate from release publication.

The six physics sliders now have distinct roles, listed in `codex.md`. The former shared elasticity slider remains useful for manual launch energy and the corresponding tap-height stopping threshold; it is renamed in the UI. Collision retention is an independent 0–85% setting. Other physics controls still affect gravity, initial press appearance, landing appearance or visual timing. No whole slider was unused; the duplicate collision-control responsibility and the hard Q plateau were removed.

RED checkpoints are local Git records; connector-synchronized commits preserve messages and source trees but may have different SHAs:

- `1d8d29d`: `tests/energy-controls.test.ps1` executed and failed because the model lacked `SetEnergyConversion`.
- `3307403`: production migration tests exposed Windows PowerShell selecting integer `Math.Min` for an integer first argument, rounding 61.44% to 61%. The expected 61.44% assertion failed before using `85.0` to select the double overload.

GREEN verification:

- `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/energy-controls.test.ps1` passes independent retention, reset preservation, launch/conversion separation, higher conversion increasing energy/compression, zero efficiency settling without rebound, finite/default/clamped limits, visible Q changes from 1 to 2 to 3 at maximum efficiency, and eventual rest at maximum efficiency with the minimum stopping threshold.
- The same test imports actual preference, bridge and save functions: missing old settings migrate the previous retention formula; explicit zero survives; invalid settings safely fall back; malformed legacy physics fields do not abort loading; fractional values are preserved; saved conversion restores independently of launch energy.
- Actual WPF menu test verifies the renamed caption, percentage value/limits, unsnapped fractional efficiency and independent values. Collision-energy, elastic-impact, tap-compression, animation-speed, landing-easing/cycle, impact-squish, horizontal-impact, floor-contact, motion-tuning, gravity (722 assertions) and gravity-wpf (17 cases) passed. Existing legacy comparison fixtures explicitly apply both the launch and migrated conversion settings.
- `node --test tests/*.test.mjs`: 94 pass, 1 existing platform-specific skip, no failures.
- Strict WPF frames: input 99.19 Hz, processing 80.87 Hz, mean CPU 1.074 ms on this device; all deterministic frame scheduling and movement assertions passed. These measurements do not guarantee performance elsewhere.

Implementation review: energy percentage is captured only on the next actual collision, so adjusting it during recovery does not recreate or alter stored energy. Appearance uses `0.72*a/(0.30+a)` for `a=Q*logicalCompression`; the response remains increasing rather than clipping at an exact plateau. Cache updates only on collision or Q changes; force/velocity conversion remains unchanged. Invalid preference parsing is isolated per legacy physics field. No new engine, timer, dependency, credential access or private committed setting is introduced.

Limits: input-energy changes still alter the final tap-height stop threshold by design; they do not alter the retention fraction. Smooth saturation becomes less visually sensitive at very high input but has no hard dead interval. Targeted tests do not prove every visual frame or all device environments. No VM/new-device install, installer package or Release was produced for this task.
