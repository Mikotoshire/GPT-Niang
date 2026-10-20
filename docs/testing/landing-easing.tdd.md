# Landing recovery timing and continuity

AI-generated changes, tests and documentation; insufficiently validated. No independent human review or subjective visual approval is claimed.

Journey: compression and recovery have changing speeds, recovery lasts longer than compression, and contact/takeoff do not snap between flight stretch and the landing pose.

RED: `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File tests/landing-easing.test.ps1` failed at `Incoming flight stretch must not snap away on contact`. The new test was committed before the implementation. It also requires longer recovery, varying recovery speed and neutral shape at takeoff.

GREEN: the same target passes after using separate quarter-sine compression and half-cosine recovery, extending total contact time to 180–260 ms, fading the incoming pose and easing in post-takeoff stretch over 80 ms. Tests compare sampled model poses: compression decelerates near the peak; recovery takes at least 1.3 times compression, accelerates then brakes; takeoff has neutral scale; there is no large one-step shape jump; final nonbouncing landings settle normally.

Additional passing checks: landing-cycle, impact-squish, horizontal-impact, floor-contact, motion-tuning and gravity-wpf (17 cases), plus gravity (742 assertions in this run). The frame regression passed deterministic burst/jitter/cap checks and its local managed-frame measurement. These tests are targeted numeric/WPF regressions, not a whole-project coverage claim or proof that every user will prefer the timing. The new regression is included in Windows CI.

Impact-squish comparison now measures deformation relative to the zero-strength pose so that fading pre-contact stretch is not misclassified as added landing squash. Solver restitution, collision loss, cancellation and fixed-step timing remain covered by their existing tests. No new dependency, engine or animation timer was added.
