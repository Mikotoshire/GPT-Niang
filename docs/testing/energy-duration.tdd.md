# Retained-energy contact duration

AI-generated maintenance and documentation; insufficiently validated. No independent human review or whole-project coverage claim.

The user requested shorter bounce deformation for less energy, using published approximations or a simple chosen rule rather than expensive simulation. This change concerns floor compression/recovery, not airborne flight, which already follows the gravity model.

Research and design:

- [Russell's linear ball collision model](https://www.acs.psu.edu/drussell/bats/ball-bat-1.html) explains spring compression, restitution and damping, and explicitly notes that linear contact time is independent of incoming speed; nonlinear contact can shorten with higher speed. Therefore the user's desired ordering is not a universal material law.
- [OpenSees Hertz Damp documentation](https://opensees.github.io/OpenSeesDocumentation/user/manual/material/uniaxialMaterials/HertzDamp.html) describes contact force using indentation, velocity, stiffness and damping; it is a reference for the additional material-dependent terms deliberately omitted here.
- Chosen artistic mapping: `T = 0.060 + 0.240*x/(0.250+x)` seconds, where x is the existing cached logical spring compression. These constants are chosen for this widget, not taken from the papers. T increases smoothly with stored energy, has a 60 ms minimum, and approaches 300 ms. Only one bounded rational expression is evaluated per actual impact. Existing animation speed scales the result; curves and energy conversion are unchanged.

RED/GREEN evidence:

- Local RED checkpoint `d7f739e`: `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/energy-duration.test.ps1` failed at the assertion requiring weaker rebound to shorten contact at the same impact speed. Connector-synchronized checkpoint SHAs may differ while preserving messages and source trees.
- The same target passes lower retention/height producing shorter contact, zero-energy brief recovery without bounce, bounded durations, unchanged output vertical kinetic energy, inverse scaling by animation speed, Q independence, captured duration/energy surviving mid-contact changes, and progressively shorter successive contacts ending at rest.
- At a 240-DIP drop, actual measured contact spans at 1x animation speed are approximately 142/208/225 ms for UI rebound levels 5/50/100%. Values include fixed 1/240-second quantization and exclude airborne motion.
- Rebound-steps, compression-curve, energy-controls, collision-energy, elastic-impact, tap-compression, animation-speed, landing-easing/cycle, impact-squish, horizontal-impact, floor-contact, motion-tuning, gravity and gravity-wpf regressions passed. Gravity printed 637 loop assertions because the shorter dwell reduces simulated settling steps; no scenarios or assertions were removed. WPF reported 17 cases; actual menu tests also passed.
- Shared Node suite: 94 pass, 1 existing platform-specific skip, no failures.
- Strict WPF frame test: input 96.87 Hz, processing 79.30 Hz, mean CPU 1.376 ms on this device. Deterministic scheduling, window movement and notification assertions passed. This does not guarantee performance elsewhere.

Review: cache duration at impact using physical logical compression rather than Q-modified appearance; never recompute while the same contact is playing. No new state preference, solver, timer or root calculation is introduced. The stored energy released after neutral recovery remains identical, limited by the existing ceiling and final-stop policy. A shorter floor dwell naturally means less time under ground friction. Recovery ratio, decelerating vertical compression and frame-independent fixed steps are retained.

Limits: the duration curve implements the requested artistic relationship rather than true Hertz/viscoelastic contact. Global animation speed can make actual playback longer or shorter than the base range. Targeted tests do not cover every device, visual state or physical material. Private settings and diagnostics remain local. No installer or Release publication is part of this task.
