# WPF cadence feedback and real fractional motion — 2026-10-21

AI-generated maintenance code and documentation, insufficiently validated. Automated tests and AI self-review provide limited evidence, not independent human assurance or a universal no-stutter guarantee.

## Findings and controlled variations

The previous remote Windows CI completed successfully in about two minutes. CI is a finite regression job triggered by source synchronization; it is not a requirement to keep a process running indefinitely and does not establish local display smoothness.

Private isolation fixtures compared a frozen sprite, changing image scale, native HWND movement, both, and genuine fractional visual translation. Image-only motion had approximately 7-ms p95; native movement without changing the visual tree had approximately 30-ms p95. Opaque-window observations were much slower and were not treated as a product comparison. Explicit visual invalidation and suppressing `WM_WINDOWPOSCHANGING` did not solve the problem and were not deployed. No dummy animation, artificial counter increments, permanent repaint loop or global timer-resolution change was added.

The decisive control used the same four-phase fixture and source with only the 120-Hz return/skip disabled: all four original smooth-60 checks passed. A bounded 240-Hz variant also passed. These separate runs strongly implicate interaction between the old limiter and WPF's producer cadence: after a fast callback is skipped, the visual tree may have no new drawing work, and the next callback can be delayed. This is an evidence-backed explanation, not a claim to have traced every internal WPF/DWM decision.

References: Microsoft's [per-frame Rendering documentation](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/graphics-multimedia/how-to-render-on-a-per-frame-interval-using-compositiontarget), the WPF repository's [idle Rendering cadence report](https://github.com/dotnet/wpf/issues/1908), and [SetWindowPos flag semantics](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos). [`InvalidateVisual`](https://learn.microsoft.com/en-us/dotnet/api/system.windows.uielement.invalidatevisual) forces a layout pass; calling it indiscriminately is not the chosen optimization.

## Production changes

- Raise the existing two-token rendering budget from 120 to 240 Hz. Keep the actual-elapsed-time clock, duplicate/reentrant protection, inactive unsubscribe behavior and 240-Hz fixed physics steps. This is a bounded processing budget, not a claim that the display presents 240 unique frames. CPU acceptance remains under 5 ms per managed step.
- Preserve true subpixel position. HWND coordinates remain integers; `MotionOffset` on `AnimationStage` carries `(exactPosition-nativePosition)/Unit`, bounded to half a physical pixel per axis. It translates the whole completed sprite/bubble consistently, outside press/mirror transforms. Native vertical position is derived from the same rounded bottom offset used by host following, including half-pixel cases. No fabricated visual jitter is introduced.
- In gravity mode, mouse events update the newest bounded target instead of directly performing every native move. `GptDragMotion` tracks it in the C# frame loop with `1-exp(-dt/0.012)`, settling within about 0.1 second. It produces genuine intermediate positions and fractional motion. Bounds and DPI updates still apply; desktop and host movement use the same controller. A stopped/failed render loop falls back to the existing direct input path.
- Drag rendering does not advance gravity or invent release momentum. The independent native cursor sampler remains authoritative for release velocity; stop-before-release and capture-cancel behavior are preserved. Release stops drag rendering before starting the normal flight scene. Mode switches/drag entry clear obsolete residual transforms. Mirror preference, physics/default parameters, image quality and saved preferences remain unchanged. Ordinary non-gravity dragging retains its existing direct path.

## Regression and acceptance

RED checkpoints cover missing subpixel geometry support, missing drag tracking, and the former sustained 120-Hz budget. Tests now check:

- 480-Hz synthetic input remains bounded near 240 processed frames/second; all legitimate 120-Hz input survives.
- A 200-Hz adaptive producer that backs off for 33 ms after a skipped callback avoids that feedback trap with the new budget.
- Actual HWND coordinates plus residual equal the model's position across physical sizes/DPI, including half-pixel bottom rounding; residual stays within half a physical pixel.
- Dragging uses time-based bounded tracking without gravitational acceleration, converges without long tail lag, survives DPI refresh and releases/cancels correctly. Existing pointer-stop, inertia, floor and friction tests remain in place.

The opt-in stress fixture keeps the **same** minimum sample count, mean <=17.5 ms, p95 <=20 ms and zero >=50-ms gaps. It now binds the actual production drag controller, and offers `-DefaultProfile` and `-HostMode`; the latter creates/destroys an independent native Win32 host and uses the real host follower. It never moves the user's mouse or queries an account. Reported render rate/native-move counts describe the final uninterrupted loop segment; delivery distributions cover the entire phase.

| Final run | Bounce p95 | Drag p95 | Menu p95 | Quota p95 | >=50-ms gaps |
| --- | ---: | ---: | ---: | ---: | ---: |
| Default profile, desktop, 12 s/phase | 13 ms | 17 ms | 17 ms | 15 ms | 0 in every phase |
| Reference fixture, desktop, 6 s/phase | 20 ms | 17 ms | 17 ms | 16 ms | 0 in every phase |
| Default profile, native host, 8 s/phase | 18 ms | 15 ms | 14 ms | 18 ms | 0 in every phase |

All three runs passed the original strict gate. Desktop default-profile dragging processed approximately 137 Hz with 1251 native moves over 12 seconds; native-host dragging approximately 162 Hz with 797 native moves over 8 seconds. Fractional visual motion also occurs between changed integer positions. A managed benchmark measured approximately 146.5 processed Hz and 0.64-ms mean CPU per step. These are callback/placement measurements, not hardware scan-out measurements. Desktop load was not fully controlled; the host run also overlapped a brief live-widget reload. No universal percentage speedup is inferred.

Full local Windows regression and Node tests pass (94 Node passes, one existing platform skip). Fresh native visibility, process ownership and supervisor/widget heartbeats were checked after reload. Actual diagnostic reports and experimental copies remain private, outside the public repository. Previous reports that failed smooth-60 are retained as historical evidence, not reclassified as passes.

Reproduce on a Windows desktop:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/run-windows-tests.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/frame-stress.test.ps1 -SecondsPerPhase 12 -DefaultProfile -RequireSmooth60
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File gpt-niang-usage/tests/frame-stress.test.ps1 -SecondsPerPhase 8 -DefaultProfile -HostMode -RequireSmooth60
```

These results qualify the tested local scenes; OS/GPU stalls and different devices can still need investigation. Source synchronization only; no package, release tag or GitHub Release.
