# Personal GPT-Niang maintenance

This is Mikotoshire's personal Windows fork. Read `docs/PERSONAL-FORK.md` before changing deployment or update behavior.
For current interaction architecture, physics constants and regression checks, also read `codex.md`.

- Preserve upstream Git history, copyright, LICENSE, character artwork/source notices and quotation licenses. Do not imply ownership of third-party artwork.
- `origin` is `Mikotoshire/GPT-Niang`; `upstream` is reference only. Never push to upstream or automatically install its releases.
- Keep deployed, tested code on `main`. Use a `personal/<feature>` branch for changes and merge only after appropriate checks. The user's recurring intent is to maintain this personal fork, back up completed changes to their GitHub repository and keep the local installation on that version.
- Before substantial changes create a backup tag and a bundle outside this repository. Do not rewrite or discard user work, force push, or use destructive clean/reset commands.
- Keep fork-policy release updates disabled. Do not add background Git pulls or automatically run remote code. Synchronize during an authorized development session.
- Never commit installation.json, credentials, account/session files, quota snapshots or private preferences. Installation generates a machine-specific `.mcp.json`; its local skip-worktree flag is intentional. Handle template changes explicitly.
- Run Node tests, targeted Windows checks and reload/health checks appropriate to the actual change. Windows PowerShell 5.1 may require explicit UTF-8 loading of test scripts.
- Windows scheduler startup error `0x8007010B` is a known local limitation; a registered task is not evidence of a running task. Preserve working direct-launch behavior.

- This repository is public. Inspect every unpublished commit before synchronization for credentials, account/quota/session data and personal machine paths. Keep real diagnostics and settings local; use fictional test data. Verify any vendored binary against its documented public source/hash and retain its license.
