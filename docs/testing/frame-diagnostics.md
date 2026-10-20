# Frame pacing diagnostics and targeted UI fixes

AI-generated maintenance changes and documentation; insufficiently validated. No independent human review or whole-project coverage measurement.

## Test plan and interpretation

Average FPS can hide isolated stalls. Record two separate distributions: increasing WPF presentation timestamps and actual UI-thread callback delivery times. These are callback observations, not hardware scan-out or exact dropped-display-frame counts. Duplicates/backward timestamps are ignored; explicit hidden pauses break the interval sequence. Keep count, mean, p95, p99, maximum and intervals over 25 / at least 50 / at least 100 ms. Percentiles use fixed 1-ms histogram bins capped at 1000 ms; maximum remains uncapped. No unbounded sample list.

`GptFrameProbe` attaches only for an explicitly requested recording, normally 60 seconds (bounded 5–120). It detaches on completion/shutdown; the regular UI tick also enforces the deadline when rendering is absent. It keeps at most 32 recent stalls and 32 work events plus fixed category summaries. Allowed labels are quota, maintenance, drag, menu, worker, placement and persistence. Event times are relative; no account, quota value, path, window title/content or input coordinate is recorded. Maintenance includes nested work, so category durations must not be added together.

Entry: settings `更新 → 记录60秒性能`; local request mode `frame-probe` also supports a bounded seconds value. Latest local `frame-diagnostics.json` has schema, random session id, recording/complete state, timing distributions and work summaries. Starting replaces the previous recording; save wanted reports privately before re-recording. There is no automatic upload or permanent idle rendering subscription. Observing rendering can itself affect scheduling, so compare like workloads and retain limitations.

Tests:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/frame-diagnostics.test.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/frame-stress.test.ps1 -SecondsPerPhase 6
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/frame-stress.test.ps1 -SecondsPerPhase 6 -RequireSmooth60
```

The first is functional and runs in Windows CI: synthetic isolated hitches despite a fast mean, duplicate/pause/reset handling, bounded work history/privacy labels, deadline/disposal, a real injected 100-ms UI block after initial frames arrive, and nonblocking worker verification. The stress fixture is opt-in and creates an independent real WPF window with fictional quota data. Four sustained phases exercise actual bounce, drag handler, settings popup and quota painting. Drag supplies scripted coordinates to the real handler; it neither moves the user's cursor nor measures hardware input latency. Physical window size is synchronized before recording; an earlier draft wrongly included that initial size/layout change in the first drag. Do not use those early 50–70-ms first-drag observations as proof of a production drag defect.

The strict heuristic requires each phase to have at least 100 intervals, mean <=17.5 ms, p95 <=20 ms, and no >=50-ms gap. It writes every phase before failing. It is a practical pacing budget with tolerance, not a guarantee of every interval <=16.67 ms. Report-only completion is not smoothness acceptance. Existing managed-frame minimum cadence, 120-Hz scheduler, CPU and real-position checks remain unchanged. Stress data are excluded from public source; never publish real recording files.

## Confirmed changes

1. Quota painting allocated new equal brushes and computed the same row layout repeatedly for rows, tooltip and theme. Reuse bounded frozen static brushes; pass one computed row set to tooltip/theme. RED tests observed a changed brush reference and three row computations; both now pass with shared identity/one computation. Status, expiry, colours and account-cache semantics remain tested.
2. A live 60-second recording found a roughly 61-ms maintenance maximum and ten >=50-ms delivery gaps. A follow-up split found synchronous worker process-path/start-time inspection reaching about 47 ms. `GptWorkerHealthCheck` performs that read-only work on a C# background Task; the UI never waits for Task.Result while pending. Fresh heartbeat/owner token, PID, start stamp and parent bind the result. The existing local process handle rejects an already-exited worker. Pending checks are revisited on later ticks with a two-second policy deadline; mismatch/failure uses existing recovery. Normal verification remains approximately five-second cadence. Task timeout does not forcibly interrupt an OS process query; exceptional restart/kill paths can still block and are not claimed solved.
3. The disabled personal release updater wrote idle telemetry every second although no update could start. Skip that maintenance only when release updates are disabled and no explicitly started updater is active. Enabled-update and cleanup/recovery behavior is retained. RED fork-policy regression caught the redundant file; GREEN fork-policy and 48 isolated Windows updater checks pass.

## Evidence and remaining limits

- Functional diagnostics, quota/cache UI, real menu, 9 lifecycle assertions, worker executable identity, crash restart/cleanup, drag/DPI, WPF gravity and related energy/friction regressions pass. Node: 94 passed, 1 existing platform fixture skipped. Managed frames still pass with about 91.5 processed Hz and 1.11-ms mean CPU in one local short run; this is not a smoothness guarantee.
- A corrected six-second phase run still measured drag p95 about 32 ms, menu p95 21 ms and quota p95 22 ms. Strict smooth-60 acceptance failed in later four-second runs; it was not waived or relabeled as success. Test-driver overhead, cold paths, native window/compositor behavior and unrelated host load still affect the results.
- Live short split measurements after async checking and inactive-updater suppression: worker UI maximum about 3.6 ms (previously 47 ms); maintenance mean about 17 ms with a remaining 52-ms maximum. A 20-second session still had two >=50-ms delivery gaps and maximum about 57 ms. Workloads/durations differ, so this does not establish a controlled percentage speedup or complete repair. Quota/persistence and remaining synchronous UI work are future candidates; preserved numeric summaries make the next investigation concrete.

No image-quality reduction, physics-rate change, release package or publication. Git checkpoints and external bundles preserve rollback; only source and generic maintenance notes are synchronized.
