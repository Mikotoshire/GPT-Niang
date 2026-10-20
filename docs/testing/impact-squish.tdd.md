# Landing squish control

AI-generated code, tests and documentation; insufficiently validated. No independent human review is claimed.

Journey: adjust how much the character deforms on landing, without changing bounce physics, and retain the preference across restarts. The accepted default is the previous appearance; zero disables the landing pulse.

RED: `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File tests/impact-squish.test.ps1` failed because the model lacked `SetImpactSquish`. The actual WPF menu test failed because the slider did not exist. Both were preserved in the branch's `test: reproduce missing independent landing squish control (RED model and menu)` checkpoint before the feature commit. The initial test's peak accumulator was subsequently corrected from integer zero to double zero so PowerShell would not round fractional deformation measurements.

GREEN: both targets now pass. The model test compares 0/1/3 multipliers, verifies full recovery and finite/clamped tuning, loads the actual startup preference condition, exercises the actual tuning bridge and Save-Settings function, and verifies identical physics trajectories, horizontal movement and rebound counts. The WPF menu test changes the actual slider and checks the independent setting and numeric label.

Additional checks run: `motion-tuning.test.ps1`, `gravity-wpf.test.ps1`, `gravity.test.ps1` (552 assertions), `horizontal-impact.test.ps1`, and `floor-contact.test.ps1`. These passed. Tests use fictional settings and no account credentials. They are targeted regression evidence, not whole-project coverage or proof of visual quality on every device. Windows CI also runs the new model/preference regression through run-windows-tests.ps1.
