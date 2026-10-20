# Animation work reduction and supported ground drag

AI-generated maintenance changes and documentation; insufficiently validated. No independent human review or whole-project coverage measurement.

User journey: reduce stutter in bouncing, dragging and menus without lowering image quality or the frame-rate requirement, and make horizontal floor slides slow down visibly.

## Changes

- Keep the existing fixed 240-Hz Aether integration and 90-Hz presentation budget. Skip identical scale writes and repeated follower placement when rounded coordinates, side offsets and bottom offset are unchanged. Still advance physics and visual deformation; desktop placement retains its actual HWND check. Host events continue moving the attached widget immediately.
- Captured-mouse drag can receive another move event at the same screen cursor coordinate after moving its own window. After a successful placement, remember the coordinate and return early on duplicates. The first move and all changed coordinates retain DPI, bounds and native movement checks. This avoids redundant queries, sizing and SetWindowPos; it does not change inertia sampling or the release velocity policy.
- Only replace submenu width/height resources when their numeric values change. Replacing equal ResourceDictionary entries invalidates DynamicResource consumers; the old menu-follow path could do this four times per second. Resize constraints and side placement remain active.
- Floor contact friction is now zero in the solver, avoiding both impulse-driven horizontal cancellation and dependence on cached normal impulses while HoldOnFloor pins the body. On supported continuous contact or the existing landing hold, explicitly reduce horizontal speed by `mu * EffectiveGravity * dt`, clamped to zero without reversing direction. `mu=0.18` (previous solver coefficient 0.12). The first actual impact still retains exactly 0.82 of horizontal speed once. No floor drag in the air; walls remain Aether collisions. At default gravity, drag is about 518.4 design DIP/s². No per-frame I/O, new timer or dependency.

## RED / GREEN evidence

1. The new ground-slide test failed with `Ground friction is noticeable and does not reverse sliding`. The new stationary-frame placement test failed with `Unchanged animation positions repeatedly invoked native follower placement`. After implementation, both pass. A six-frame frozen-time fixture invokes follower placement once instead of six times while retaining all six rendering callbacks.
2. Duplicate-cursor regression failed on the previous real drag handler, and repeated-menu-bounds regression failed because the width resource object was replaced. Both pass after implementation. Drag runs all six host/desktop DPI cases; menu testing also changes host width and verifies bounds still update.
3. Horizontal tests cover both directions, expected time-based deceleration, eventual rest within two seconds for a 600-DIP/s slide at default gravity, 60/144-Hz equivalence, repeated-impact retention and no airborne drag. Existing energy, compression-curve, duration, launch, landing, floor-contact, motion, gravity (637 assertions), WPF (17 cases), desktop and menu checks pass. Node: 94 passed, 1 existing platform fixture skipped.

Strict two-second local WPF measurements, using the same acceptance thresholds: before changes input 93.65 Hz / processing 79.63 Hz, mean step 2.959 ms, mean CPU 1.758 ms, max step 24.696 ms. After changes, two runs measured 79.55/79.27 Hz processing, mean step 2.568/2.855 ms, mean CPU about 1.769 ms and max step 23.757/23.192 ms. Input differed, so these are not a controlled speedup claim. Average FPS is essentially unchanged; deterministic tests establish eliminated redundant work. Native placement still dominates measured step time. These tests do not prove that every reported hitch is resolved or measure physical display scan-out. No acceptance threshold was relaxed, no anti-aliasing setting changed, and no Release was published.

Private settings, quota, paths and runtime logs remain outside the public repository. Git checkpoints and external bundles preserve rollback.
