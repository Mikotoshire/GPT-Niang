# Natural elasticity calibration (2026-10-20, unreleased)

AI-generated changes and documentation; insufficiently validated. No independent human review or whole-project coverage measurement.

The user prefers compression curve 1.5 over 3.0 and requested research into real bouncy objects and a practical calibration. This is a visual reference preset, not a fitted material simulation.

## Evidence and interpretation

- [Rod Cross, The bounce of a ball (1999), sections II/IV and Table I](https://www.physics.sydney.edu.au/~cross/PUBLICATIONS/BallBounce.pdf): measured center-of-mass displacement during compression is approximately sinusoidal. Under the simplified linear spring assumption the normalized compression is `sin(pi*t/2)`. Measured displacement and sprite height deformation are different quantities, so this motivates rather than proves a visual fit.
- [Tanaka, Yamazaki and Okumura, Bouncing gel balls (2003), abstract](https://arxiv.org/abs/cond-mat/0302167): soft gels behave approximately elastically, but increasing impact speed changes the deformation regime from Hertz-like contact to pancake shapes. There is no single curve for every soft object and impact.
- Force versus deformation and deformation versus time are different graphs. A nonlinear force law does not imply an exponential animation in time. Initial compression can be nearly linear because restoring force is initially small; it then slows toward maximum compression.

Our existing cubic at 1.5 becomes `C(t)=1.5*t-0.5*t^3`. It starts with zero curvature, decreases speed continuously and ends at zero speed. It differs from the ideal quarter-sine by less than 0.021 over normalized time. At halfway, compression is 0.6875; curve 3.0 gives 0.875 and brakes immediately, making early squash/dwell more prominent. This explains a plausible visual preference, not a universal perception result. The model still evaluates a few multiply/add operations per step; no new solver, dependency or timer.

## Chosen preset

`重力与弹性 → 应用自然弹性` explicitly applies curve 1.5, rebound 75%, Q 1x and animation 1x, then uses the existing production tuning/save/menu-refresh path. Rebound 75% maps to 63.75% retained energy and an ideal outgoing/incoming speed ratio about 0.798. As a rough reference, Cross's measured tennis-ball speeds 2.95 and 2.38 m/s give ratio 0.807 and energy ratio 0.651. This does not identify the character with a tennis ball or model every substrate/material. Q=1 is the existing standard visual amplitude, not an experimentally calibrated modulus.

The source default/invalid fallback curve changes from 1.6 to 1.5. Existing valid preferences are preserved on ordinary startup; selecting the preset is explicit. The preset leaves gravity, manual launch energy, manual press shape, mode and appearance unchanged. Legacy retained-energy preference remains consistent for rollback. Changing the curve during contact still affects only the next collision. Existing Q changes may affect the current visual amplitude as before.

Contact duration remains the previous energy-dependent artistic 60–300 ms base envelope, compression/recovery ratio remains about 0.414/0.586, and neutral recovery still precedes takeoff at the user's request. Real contact can last milliseconds and real balls can leave while still deformed. Do not claim this entire animation is physically exact. The previous weaker-energy/shorter-animation design is preserved even though it is not a universal contact law.

## Verification

RED checkpoint: the new default/quarter-sine test failed with `Natural default uses gentle initial braking` before implementation. GREEN: compression-curve and actual WPF settings-menu tests pass, including the preset's applied values, updated controls, and unchanged unrelated physics preferences. Existing tests retain endpoint, monotonically decreasing actual squash speed, energy independence and no mid-contact curve jump checks. Additional regression results are recorded after execution below. Local application backs up private preferences outside the public repository; private values and backup files are not published. Source synchronization only; no installer or Release publication.

Executed local regressions: compression-curve and WPF settings menu; energy-duration, rebound-steps, energy-controls, collision-energy, elastic-impact, tap-compression, animation-speed, landing-easing/cycle, impact-squish, horizontal-impact, floor-contact, motion-tuning, gravity (637 assertions) and gravity-wpf (17 cases). Node: 94 passed, 1 existing platform fixture skipped. These are automated checks, not independent visual approval or a new-device installation test.
