# Personal GPT-Niang maintenance

> **AI 生成与验证声明：** 本维护分支相对上游的修改，以及新增或改写的文档，均由 AI 生成，且未经充分验证或独立人工审查。现有自动化测试与 AI 自查仅覆盖有限场景，不能保证正确性、稳定性、安全性或完整合规性，可能存在未发现的问题。仅供试用，请自行评估并备份重要数据。此声明不将上游原作或第三方依赖归为 AI 生成，也不改变原许可和权利归属。

This is Mikotoshire's personal Windows fork. Read `docs/PERSONAL-FORK.md` before changing deployment or update behavior.
For current interaction architecture, physics constants and regression checks, also read `codex.md`.

- Preserve upstream Git history, copyright, LICENSE, character artwork/source notices and quotation licenses. Do not imply ownership of third-party artwork.
- `origin` is `Mikotoshire/GPT-Niang`; `upstream` is reference only. Never push to upstream or automatically install its releases.
- Keep deployed, tested code on `main`. Use a `personal/<feature>` branch for changes and merge only after appropriate checks. The user's recurring intent is to maintain this personal fork, back up completed changes to their GitHub repository and keep the local installation on that version.
- Current user policy: continue synchronizing reviewed, tested source code to personal GitHub after completed development stages. Do not package a distributable, create a release tag or publish a GitHub Release until explicitly requested. Code synchronization and release publication are separate actions.
- Before substantial changes create a backup tag and a bundle outside this repository. Do not rewrite or discard user work, force push, or use destructive clean/reset commands.
- Keep fork-policy release updates disabled. Do not add background Git pulls or automatically run remote code. Synchronize during an authorized development session.
- Never commit installation.json, credentials, account/session files, quota snapshots or private preferences. Installation generates a machine-specific `.mcp.json`; its local skip-worktree flag is intentional. Handle template changes explicitly.
- Run Node tests, targeted Windows checks and reload/health checks appropriate to the actual change. Windows PowerShell 5.1 may require explicit UTF-8 loading of test scripts.
- After source synchronization, inspect the remote CI result before declaring validation complete. Retry confirmed transient infrastructure failures in a bounded way; investigate repeatable test/code failures and fix their cause before rerunning. Do not weaken checks or repeatedly rerun an unexplained failure just to obtain green. Record any remaining external blocker and validation limits.
- Windows startup uses OS-resolved physical paths to avoid MSIX AppData redirection. A registered/running task alone is insufficient: verify a fresh supervisor heartbeat and visible widget. Preserve binding ownership and legacy-task migration checks.

- This repository is public. Inspect every unpublished commit before synchronization for credentials, account/quota/session data and personal machine paths. Keep real diagnostics and settings local; use fictional test data. Verify any vendored binary against its documented public source/hash and retain its license.

- Keep AI-NOTICE.md and visible AI-generation / insufficient-validation notices in documentation, plugin metadata, installer, menu and releases. Historical tests and AI self-review are not sufficient validation or independent human assurance. Do not attribute upstream work or third-party dependencies to AI.
