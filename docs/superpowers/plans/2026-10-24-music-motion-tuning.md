# Music motion tuning and post-merge stutter investigation

AI-generated maintenance plan; insufficiently validated. Preserve upstream attribution and licenses.

User feedback takes precedence over the earlier synthetic acceptance: music works, but ordinary mode also feels slightly more jerky. Increase only the music-driven lateral walk, preserve flick momentum, and investigate new overhead without another rendering rewrite.

- [x] Preserve d0975fb with a backup tag, an external bundle and an isolated personal/music-motion-tuning worktree. Daily main remains unchanged until checks pass.
- [x] Reproduce existing beat travel at 25 DIP/s with a failing behavior test; tune to 35 DIP/s and check both directions across 3 DPI scales and 4 step rates. Keep throw, edge, vertical motion and pause behavior.
- [x] Measure newly added geometry notifications: original callback boxes WINDOWPOS even when SWP_NOZORDER already means it will not request a scan. Move the existing decision before structure unmarshalling. Verify actual foreign coverage/cloaking behavior is retained.
- [x] Improve allocation regression after AI review: measure current-thread allocated bytes when the runtime supports it; process GC counts alone are diagnostic. Old source fails with 56 MB across one million notifications; candidate observed 0 bytes. Unsupported runtimes explicitly report the measurement limit.
- [x] Observe real runtime numerically without storing window names, accounts or quota data. A 20-second name-event sample had 17 events, only 2 relevant root names, so it did not justify replacing event routing. A separate 20-second live frame sample had p95 30 ms and maximum 46.4 ms, with no drag/menu work. It does not prove the cause of perceived stutter.
- [x] Run affected music, occlusion, native-router and full-entrypoint regressions; Node tests; serial default-profile host-mode performance comparison. Reject samples overlapping other tests or external menu dismissal.
- [x] Request C# review and resolve important findings; do not equate microbenchmark gains with overall frame-rate acceptance.
- [x] Update maintenance records, privacy-audit staged source, commit independent changes, fast-forward main, reload and verify fresh heartbeat/native visibility. Compare another real runtime sample and request user feedback.
- Source synchronization uses a normal push to the personal repository. No release packaging/publication. Preserve backup history and revert only a worsening experiment if actual use regresses.

Validation: 28 affected Windows scripts passed; Node 153 passed / 1 platform skip / 0 failed. The first overlapping baseline is rejected. Valid serial p95 baseline/candidate was bounce 14/17 ms, drag 10/10 ms, persistent menu 12/11 ms, quota 17/11 ms, with no >=50 ms gaps. This is not proof of improved real screen FPS. A pre-existing off-screen fixture forced HWND_BOTTOM and got error 5 while restoring the music backdrop; keeping the isolated fixture above desktop shell windows fixed the case without changing runtime lifecycle, timeout or assertions. C# review accepted this fixture correction. Preserve these limits in the final report.

- [x] Add music travel slider (2026-10-27), default100, 0..200 step10, live/persisted; model/helper/menu/startup RED then GREEN; AI review approved. User accepted prior tuned speed and reduced stutter. Live before/after music states differ, so do not compare those frame samples.
