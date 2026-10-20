# Tap compression evidence

AI-generated maintenance and documentation; insufficiently validated. No independent human review or whole-project coverage measurement.

User journey: adjust single-click compression independently of bounce energy and impact squash, retain the value locally, and use it in both ordinary and gravity modes. Continue source synchronization; do not publish a release.

RED evidence, using Windows PowerShell 5.1:

- `tests/tap-compression.test.ps1` failed because `SetTapCompression` was missing (`c348963`).
- Extended production settings and ordinary-click tests exposed the fixed ordinary animation (`4a62be1`). A subsequent horizontal-budget assertion exposed clipping risk when scaling the whole group above the original pulse (`9d78317`).
- `tests/gravity-wpf.test.ps1` injected a real WPF animation clock; switching gravity mode failed to clear it (`888fb9e`). Maximum charged character bounds also checked at 3×.

GREEN evidence:

- `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/tap-compression.test.ps1`: passes 0/default/max amplitude, horizontal expansion, live tuning, finite/bounded validation, reset retention, unchanged charge/launch energy and falling/landing behavior, production save/load with missing/invalid preferences, ordinary-click composite transforms and bounded full charge.
- `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/gravity-wpf.test.ps1`: 17 cases pass, including maximum deformation in both facing directions and removal of stale animation clocks on mode switch.
- Animation-speed, landing-easing, landing-cycle, impact-squish, horizontal-impact, floor-contact, motion-tuning, gravity (742 assertions), and settings-menu tests passed. Menu test uses the runner's UTF-8 `-SettingsMenuOnly` path.
- `node --test tests/*.test.mjs`: 94 pass, 1 existing platform-specific skip, no failures.

Review: the new coefficient scales only the base pose terms; the charge contribution and physical launch formula are unchanged. The ordinary animation keeps its shared pulse within the original budget, applying additional compression to the character; both transforms return to neutral. Maximum charged scale remains positive. Tests use fictional temporary settings and do not persist account data. Existing licenses and AI notices remain intact.

Limits: endpoint/physics and WPF layout assertions do not guarantee all intermediate visual frames, all hardware or a whole-project coverage percentage. Installation packaging and new-device installation were not repeated for this settings-only feature. No release is published.
