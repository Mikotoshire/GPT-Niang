# Animation speed evidence

AI-generated changes and documentation; insufficiently validated. No independent human review or whole-project coverage claim.

Journey derived from the user's request: adjust deformation speed in the existing gravity settings, remember the value locally, and retain the physical motion and charging rules. Source synchronization remains authorized; release publication requires a separate explicit request.

- RED: `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/animation-speed.test.ps1` executed and failed because the model lacked `SetAnimationSpeed`. Checkpoint: `2901351`.
- GREEN: the same command passed duration scaling, rebound energy, safe bounds, nonfinite defaults, reset retention, real-time press/free flight, continuous live adjustment, production bridge/save/load and invalid legacy preferences.
- Existing landing-easing, landing-cycle, impact-squish, horizontal-impact, floor-contact, motion-tuning, gravity (742 assertions), gravity-wpf (17 cases) and actual settings-menu tests passed in Windows PowerShell 5.1.
- Strict managed-frames test passed: measured input 108.79 Hz, processing 81.84 Hz and mean CPU 1.61 ms on this device. This does not guarantee frame rate on other hardware; animation speed does not change the frame budget.

Implementation review: only visual timer decrements are multiplied. Physical integration, stored bounce velocity and press/charge clocks remain real time. Changing speed does not reset timers. Slower floor dwell naturally applies ground friction longer, so horizontal trajectories after contact need not match. Old settings default to 1; malformed preferences are ignored. Settings and real account/diagnostic data remain local.

Limits: targeted assertions provide no whole-project coverage percentage or complete cross-device/visual assurance. Native runtime visibility and source synchronization are checked separately; no Release is created for this task.
