# Personal Windows fork verification — 2026-10-19

> **AI 生成与验证声明：** 本维护分支相对上游的修改，以及新增或改写的文档，均由 AI 生成，且未经充分验证或独立人工审查。现有自动化测试与 AI 自查仅覆盖有限场景，不能保证正确性、稳定性、安全性或完整合规性，可能存在未发现的问题。仅供试用，请自行评估并备份重要数据。此声明不将上游原作或第三方依赖归为 AI 生成，也不改变原许可和权利归属。

Requirements: keep the installed high-quality character scaling, prevent upstream release installation, retain license notices, and maintain a recoverable personal Git history.

- Scaling: `widget.xaml` changes only the character image's `RenderOptions.BitmapScalingMode` to `HighQuality`. Prior local validation rendered 60%, 100%, 140% and 250%; size checks passed 288 physical resize cases and the widget layout/reset-time suite passed.
- RED: the four tests in `gpt-niang-usage/tests/fork-policy.test.mjs` failed on the original updater. Manual and automatic paths still requested upstream release metadata; cleanup did not report the fork's Git-only policy.
- GREEN: the same four tests passed after adding the versioned fork policy and backend guard. They use temporary app directories without `.git`, an explicitly enabled old update preference, and mocked release fetch/install hooks. No network call or installation is permitted.
- Full Node regression: `node --test tests/*.test.mjs` — 84 tests, 83 passed, 0 failed, 1 platform-specific macOS fixture skipped on Windows.
- WPF: `fork-policy.test.ps1` passed: initialization overrides a previously enabled preference, enabling the toggle remains disabled, manual update does not start a process, the menu reflects the policy, and a later background tick starts no updater.
- Existing settings-menu checks passed. Existing Windows updater transaction checks were run with explicit UTF-8 decoding and the original source directory; all 48 assertions passed using temporary fixtures and a startup-directory write probe.
- Publication scope: preserve LICENSE, character source/use notices and quotation license unchanged. Machine-specific `.mcp.json` remains a local skip-worktree override; generated installation and account/state files are excluded from publication.

This is targeted verification, not a whole-project coverage claim. macOS personal-fork behavior and login startup on another device are outside the verified scope.
