# Personal Windows fork verification — 2026-10-19

Requirements: keep the installed high-quality character scaling, prevent upstream release installation, retain license notices, and maintain a recoverable personal Git history.

- Scaling: `widget.xaml` changes only the character image's `RenderOptions.BitmapScalingMode` to `HighQuality`. Prior local validation rendered 60%, 100%, 140% and 250%; size checks passed 288 physical resize cases and the widget layout/reset-time suite passed.
- RED: the four tests in `gpt-niang-usage/tests/fork-policy.test.mjs` failed on the original updater. Manual and automatic paths still requested upstream release metadata; cleanup did not report the fork's Git-only policy.
- GREEN: the same four tests passed after adding the versioned fork policy and backend guard. They use temporary app directories without `.git`, an explicitly enabled old update preference, and mocked release fetch/install hooks. No network call or installation is permitted.
- Full Node regression: `node --test tests/*.test.mjs` — 84 tests, 83 passed, 0 failed, 1 platform-specific macOS fixture skipped on Windows.
- WPF: `fork-policy.test.ps1` passed: initialization overrides a previously enabled preference, enabling the toggle remains disabled, manual update does not start a process, the menu reflects the policy, and a later background tick starts no updater.
- Existing settings-menu checks passed. Existing Windows updater transaction checks were run with explicit UTF-8 decoding and the original source directory; all 48 assertions passed using temporary fixtures and a startup-directory write probe.
- Publication scope: preserve LICENSE, character source/use notices and quotation license unchanged. Machine-specific `.mcp.json` remains a local skip-worktree override; generated installation and account/state files are excluded from publication.

This is targeted verification, not a whole-project coverage claim. macOS personal-fork behavior and login startup on another device are outside the verified scope.
