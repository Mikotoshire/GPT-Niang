# Lightweight collision spring reservoir

Historical stage evidence. Current independent conversion settings and smooth Q saturation supersede the earlier shared-control formula; see `energy-controls.tdd.md`. Legacy comparison fixtures explicitly set both controls to reproduce the original scenarios.

AI-generated changes and documentation; insufficiently validated. No independent human review or full-project coverage claim.

The user requested a simple shared conversion from collision speed to elastic energy, compression/force and upward velocity, avoiding expensive physical simulation. This replaces the preliminary visual-only elasticity adjustment in this development stage.

For unit-mass proxy values, calculate once on actual floor contact:

```text
incomingEnergy = 0.5 * downwardSpeed^2
retention = min(0.85, 0.64^2 * elasticitySetting)
storedEnergy = incomingEnergy * retention
peakCompression = sqrt(2 * storedEnergy / stiffness)
peakForce = stiffness * peakCompression
```

Stiffness is an artistic constant of 4,000,000. Displayed squash is the existing time envelope times `min(0.72, Q * peakCompression)`. The Q multiplier and visual saturation affect appearance, not the retained energy. These are simplified proxy units, not real material parameters. Force is a derived peak value, not a separately integrated solver.

After neutral recovery, release `upwardSpeed = sqrt(2 * storedEnergy)`, limited by the current available height, then clear stored energy/compression/force. Terminal small landings dissipate the reservoir instead of rebounding; cancellation clears it immediately. Elasticity changes apply to the next collision's captured energy. Aether still handles gravity, contact detection, horizontal impacts and sliding friction; floor restitution is zero to avoid applying two rebounds. Each contact uses a fixed amount of arithmetic and one square root; release uses one square root. No per-frame spring solver, allocations or additional timer is added.

TDD evidence:

- `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/collision-energy.test.ps1` failed at the missing positive reservoir assertion (`8d1faa6`). An additional RED check caught force remaining loaded after energy release (`0bcb8c3`).
- The same target passed after implementation: configured energy fractions; `E=0.5*k*x^2`; `F=k*x`; upward kinetic energy equals the captured reservoir; stronger elasticity increases compression and rebound speed; spring unloads after recovery; reset/press/drag cancel storage; successive collisions lose energy and settle.
- Elastic-impact, tap-compression, animation-speed, landing-easing, landing-cycle, impact-squish, horizontal-impact, floor-contact, motion-tuning, gravity (722 assertions; count changes with settling duration), gravity-wpf (17 cases) and settings-menu regressions passed. These preserve input timing, smooth neutral takeoff, Q independence, inertia and floor placement.
- Strict real WPF frame test passed: input 102.56 Hz, processing 82.05 Hz, mean CPU 0.758 ms on this device. This is a local measurement, not a guarantee for other environments.
- Shared Node suite in this development stage: 94 pass, 1 existing platform-specific skip, no failures. No Node production code changed.

Review limits: simplified energy bookkeeping and an artistic deformation envelope do not simulate a real deformable body. The visual clamp and Q=0 deliberately decouple displayed size from logical peak compression. No new-device installation/VM or exhaustive visual validation was performed. Privacy checks exclude account/settings/diagnostic data from commits. Source synchronization is authorized; no installer or Release is published.
