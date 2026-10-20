# Integer rebound levels

AI-generated maintenance and documentation; insufficiently validated. No independent human review or total-project coverage claim.

The user requested renaming the conversion control and five-percent integer levels, then explicitly chose 0–100% including zero: twenty intervals, twenty-one selectable values.

Local RED checkpoint `0f95e04`: `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/rebound-steps.test.ps1` executed and failed because `Get-WidgetReboundStrengthPreference` was missing. GitHub connector commits preserve messages and trees but may use different metadata/SHAs.

GREEN evidence:

- The same target passes exact levels, nearest-five rounding with upward midpoints, legacy defaults/maximum/zero migration, explicit new-zero priority, invalid-value fallback, production tuning/saving, integer preference restoration and bounded energy mapping.
- The actual WPF settings-menu test passes the renamed caption, 0/100 endpoints, tick and keyboard increments of five, snapping a non-level input of 63 to 65, and all twenty-one selectable values with integer labels. Curve and manual launch settings remain independent.
- Compression-curve, energy-controls, collision-energy, elastic-impact, tap-compression, animation-speed, landing-easing/cycle, impact-squish, horizontal-impact, floor-contact, motion-tuning, gravity (722 assertions) and gravity-wpf (17 cases) regressions passed.
- `node --test tests/*.test.mjs`: 94 pass, 1 existing platform-specific skip, no failures.

Review: the new UI percentage maps linearly to the unchanged 0–85% physical retention range, preserving energy loss at the maximum setting. No C# solver change, new timer or dependency is needed. The new `reboundStrength` field is an integer; legacy `energyConversion` remains a compatible internal value for rollback. Reading legacy settings rounds once to the nearest UI level, and saving the new field prevents repeated migration drift. The value-changed handler normalizes intermediate pointer values before applying/persisting a level, in addition to WPF tick snapping.

Limits: migration intentionally quantizes intermediate old settings and may slightly change their feel; displayed 100% means maximum rebound, not lossless physics. Targeted tests do not guarantee every device or visual state. Preferences remain local. Source synchronization only; no Release publication is included.
