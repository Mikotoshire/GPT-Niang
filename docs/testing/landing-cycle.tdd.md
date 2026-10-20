# Speed-driven landing and delayed rebound

AI-generated changes, tests and documentation; insufficiently validated. No independent human review or universal compatibility is claimed.

Journey: downward impact speed controls deformation; the character stays vertically on the floor while compressing and recovering, then bounces. Horizontal inertia continues. Repeated weaker collisions deform less, and interruptions cancel pending rebound.

RED: `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File tests/landing-cycle.test.ps1` failed at `Contact must begin compression before any upward bounce`. The branch's test checkpoint precedes the feature implementation. An additional case then reproduced the lost downward-fling energy near the floor, and passed after the initial energy threshold included both velocity directions.

GREEN: the same target passes, covering increasing deformation at three downward speeds, capped extreme shape, no upward movement before recovery, preserved solver rebound energy, horizontal movement during contact, one collision/rebound per cycle, decreasing deformation across repeated bounces, final settling, cancellation after compression has begun, and zero-height cancellation. The existing squish test was adjusted to compare multiplier scaling on speed-dependent deformation rather than a fixed 15% depth.

Additional passing checks: `impact-squish.test.ps1`, `gravity.test.ps1` (624 assertions in this run), `horizontal-impact.test.ps1`, `floor-contact.test.ps1`, `gravity-wpf.test.ps1` (17 cases), `motion-tuning.test.ps1` and the actual settings menu test. `managed-frames.test.ps1 -AllowLimitedCompositor` passed its deterministic burst/jitter/cap regressions and measured input 119.72 Hz, processing 83 Hz, mean CPU 0.659 ms on the local test environment. This measurement does not guarantee performance on other devices.

No credentials or private snapshots are used in these tests. Rendering remains on the existing WPF loop and 240 Hz physics substeps; no separate animation timer or replacement physics engine was introduced. New runtime tests are included in the Windows CI runner.
