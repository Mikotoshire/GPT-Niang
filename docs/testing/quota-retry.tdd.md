# Bounded quota reconnect and retained snapshots

AI-generated changes and documentation; insufficiently validated. See AI-NOTICE.md. No independent human review is claimed.

Journeys were derived from the user's request: open recently fetched data without another query; retain complete old data while fetching and on failure; reconnect a transient failure at most once; clear data when a different account is confirmed.

RED: `node --test tests/quota-retry.test.mjs` executed six tests, with five failures for the missing retry function and partial replacement of a complete snapshot. Published checkpoint: `0273f3b476dec7e097257fef6baeb251efe44b56`. The Windows quota-cache test then failed because opening fresh data wrote a new refresh request; published checkpoint: `63436458889d77e87bd374b9627c5616ffe2d82b`. Local checkpoint commits have different author metadata and were preserved in branches/bundles; the published commits have identical source trees. Use these full GitHub commit IDs for public reproduction.

GREEN: the same targets pass after implementation. `quota-worker.test.mjs` exercises the actual worker, pipe/client and separate mock CLI process: old values remain visible during fetching and two failed attempts, recovery replaces them, and a confirmed account switch clears them. All account and quota fixtures are fictional. `widget.test.ps1` validates existing WPF layout and the changed warning titles.

Coverage command: `node --test --experimental-test-coverage --test-coverage-include=runtime/usage.mjs --test-coverage-include=runtime/refresh-queue.mjs tests/quota-retry.test.mjs tests/usage.test.mjs tests/watch.test.mjs tests/codex-path.test.mjs`. Result: 96.30% lines, 87.44% branches, 81.40% functions across these modules. This is targeted coverage, not a whole-project or visual acceptance claim.

Local real-worker queries also succeeded through the normal requestRefresh channel; only booleans and duration were inspected. Private snapshots and raw diagnostics remain outside Git. A separately spawned CLI was blocked by the test environment's filesystem permissions and is not counted as successful validation. No claim is made that network failures can always be repaired or that this change guarantees operation on every Windows environment.
