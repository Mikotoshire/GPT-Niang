# Personal physics defaults — 2026-10-21 (unreleased)

AI-generated changes and documentation, insufficiently validated; see AI-NOTICE.md. These are limited automated checks and AI self-review, not independent human assurance.

The authorized profile is gravity 1.4, launch energy 2.5, tap compression 2, impact squish 1.5, animation speed 1, rebound 65%, compression curve 1.5 and ground friction 0.2. Internal retained energy is 55.25%. Only these selected numeric values were transcribed; private settings and real diagnostic files are excluded.

`physics-defaults.test.ps1` first failed on the old model defaults. The passing implementation checks model construction, nonfinite setter fallbacks, actual widget initial assignments, both production bridge entry points, absent/invalid rebound data, legacy migration, explicit zero and valid custom values. It also advances a default tap to its 60-DIP apex and rest, and a default 500-DIP drop through rebound to rest with neutral scale.

Historical interaction tests explicitly select their historical reference profile where necessary. The default-dependent landing energy bound now uses the configured retention rather than the obsolete fixed restitution square. No collision, motion, easing or friction formulas changed. The separate natural-elasticity menu preset remains unchanged.

Run on Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/physics-defaults.test.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/run-windows-tests.ps1
```

Node regression: 94 passed, 1 existing platform skip, 0 failures. The initial sandboxed Windows run passed physics/render checks but could not probe the Startup directory during installer tests; that is a permission failure and requires rerunning with filesystem access. Performance acceptance is separate: this default change does not resolve or reclassify the previously documented strict smooth-60 failure.

The rerun with the required filesystem access completed the full Windows runner successfully, including installer/update/lifecycle, native WPF menus, sizing, host readiness and widget checks. Native managed-render sample: approximately 92.8 FPS; this short mean is not strict smooth-60 acceptance.
