# Removing heartbeat disk I/O from rendering — 2026-10-21

AI-generated maintenance code and documentation, insufficiently validated. Limited automated tests and AI self-review; no independent human assurance or whole-project coverage claim.

## Investigation and references

The [WPF threading model](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/threading-model) explains that a UI operation runs to completion and input cannot interrupt it. The existing one-second maintenance callback synchronously serialized and atomically wrote the heartbeat. A local 20-second recording measured persistence UI work averaging 6.16 ms and reaching 17.22 ms, a significant part of a 16.67-ms budget.

Do not interpret every idle rendering callback gap as a displayed animation drop. The WPF repository has a [matching report about idle Rendering cadence](https://github.com/dotnet/wpf/issues/1908), also reproduced on .NET Framework 4.8. This does not prove that issue causes our active-animation stutter. Keep the separate active four-phase stress gate and its original thresholds.

A private test also requested 1-ms timer resolution temporarily and balanced it with `timeEndPeriod` in `finally`. Drag p95 stayed 31 ms and strict smooth-60 still failed, so no timer-resolution request was added to production. Microsoft's [timeBeginPeriod documentation](https://learn.microsoft.com/en-us/windows/win32/api/timeapi/nf-timeapi-timebeginperiod) describes the Windows 11 visibility limitation and potential scheduler/power cost; it is not an established solution here.

## Implementation

`GptLatestFileWriter` performs heartbeat disk operations in a C# Task, without a PowerShell runspace or UI callbacks. It permits one active write and at most one replaceable pending JSON string. New pending heartbeats replace stale queued ones. It writes UTF-8 without BOM, then atomically moves/replaces the destination and retains the existing single `.bak` policy. Failed temporary-file cleanup is best effort; the original write failure is exposed as an exception type through `LastError` and a failure counter. There is no autonomous retry loop: only the next ordinary submission can retry.

`Write-WidgetPresence` still constructs/serializes the snapshot on the UI thread, then submits it immediately. Observed failures are recorded locally in `presence-error.txt` as an exception type, without payload/path details. Settings and other durable state retain their existing synchronous writes and backup behavior. The update does not alter account or quota-cache semantics.

Shutdown closes submissions and allows at most 250 ms for accepted heartbeat writes to drain. It deletes its own heartbeat only after drain completes; on timeout it warns, leaves the record for existing PID/freshness checks, and retains the widget mutex until process exit. That prevents a new owner starting while an old disk write could still overwrite its heartbeat. Ordinary frame processing never calls `Drain` or waits for a Task.

Point/rectangle creation in drag and physics bridge paths uses direct typed constructors instead of `New-Object` command dispatch. DPI validation, size synchronization, screen bounds and mouse-release velocity sampling remain in place. This is a small hot-path cleanup, not a demonstrated cure for drag stutter.

## Evidence and limits

`async-presence.test.ps1` first failed because the writer did not exist. It now checks a deliberately blocked C# sink, nonblocking submission, newest-only bounded queue, bounded shutdown while blocked, atomic native writes, failure recovery on a later submission, production heartbeat ownership, and drain-before-owned-record-removal. It does not simulate every filesystem failure or indefinite OS I/O stall.

| Measurement | Before | After |
| --- | ---: | ---: |
| Live heartbeat UI mean | 6.16 ms | 0.186 ms |
| Live heartbeat UI maximum | 17.22 ms | 0.244 ms |
| Live maintenance mean | 12.11 ms | 7.93 ms |
| Live delivery p95 | 31 ms | 33 ms |
| Live delivery maximum | 57.35 ms | 67.07 ms |
| Live gaps >=50 ms | 1 | 2 |
| Independent drag stress p95 | 31 ms | 31 ms |

Live observations were separate 20-second sessions with different callback counts and uncontrolled desktop load, including idle periods. They confirm that measured heartbeat work no longer includes disk I/O; they do **not** establish an overall FPS improvement. A remaining worker check reached 24 ms in the after sample. All four independent six-second stress phases still failed the original strict smooth-60 gate. Do not report this as stable 60/120 FPS or a complete stutter repair.

Actual reports and timer-experiment scripts remain outside the public repository. Only generic methods and numeric summaries are published. No image-quality/physics/default-parameter changes, package or Release.

Validation: full Windows runner completed successfully; after the final ownership guard, async-persistence and lifecycle checks were rerun. The blocked-close regression probes the named mutex from a different C# thread to avoid mistaking recursive ownership on the calling thread for a released mutex. Node: 94 passed, 1 existing platform skip.
