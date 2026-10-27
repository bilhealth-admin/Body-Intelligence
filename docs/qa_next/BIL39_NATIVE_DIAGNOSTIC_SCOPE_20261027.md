# Discovery branch only

Base: 89c528e1aff7145607ddf7dd6fe62b9a7923370d. Integration source stays frozen.

The iPhone-only workflow observes the actual existing feature entrypoint and bridge lifecycle. It preserves every test assertion, 1500ms reply budget and 8000ms Community readiness budget. It does not run crypto/settings/RunnerTests again and cannot supply release acceptance. Debug-only diagnostics record synthetic geometry, generation, callbacks and visibility; no cloud, account credentials, paid provider calls or production data. Existing 10-workflow signing gate is untouched. No baseline update, build-number change, TestFlight, signing certificates or store changes.

Local evidence before dispatch: five real Python parser/orchestration tests passed; 17 Flutter presentation/composition/interaction tests passed; analyzer on the five instrumented Dart files reported zero issues. Both new workflows passed actionlint (ShellCheck/Pyflakes unavailable), and both discovery shell scripts passed actual Bash syntax checks. These results validate the diagnostic harness only. They do not prove the remaining native journeys or authorize release.

iPad evidence: original artifact 12707031283 (SHA256 4fe45a4bed5fc3d1a6ab712581bc6ec9634f734eb9889549a1300772eeac9c12) shows VM service publication by the exact Runner PID at 02:41:06.850 UTC while Flutter drive waited for discovery until its 1800s limit. The isolated iPad probe runs the actual crypto target through explicit existing-VM attachment, not another three-scope certification run. Production signing, OS permissions and simulator entitlements remain unchanged.

## Corrections after actual first discovery runs

The first iPhone probe connected to the selected VM in 32.066s and produced real device captures, but the runner saw no test counters through Flutter's app-null log reader and hit its 180s bootstrap limit. This remains a failed probe, not a passed app test. The first iPad probe stopped at simctl launch's 60s wait. Its original receipt/log/screenshot are retained; the underlying reason is not declared proven from that timeout alone.

The launcher now writes simctl output to an owned file and waits for that process, avoiding an inherited-pipe EOF trap reproduced with real local child/grandchild processes (PIPE negative control times out; file/wait control returns the actual PID). A filtered OS log collector starts before launch. Its incremental JSON relay forwards only the selected Runner PID's real events, including actual test counters, while retaining the driver's complete raw output. It adds no fabricated progress or success messages and leaves existing timeout/summary assertions unchanged. Collector cleanup and driver exit remain required.

The iPhone discovery selection now contains exactly the four previously failed cases: first AR normal Coach reveal, Community ARdark1x, ENlight2x and ENdark2x. The full certification driver and full integration branch are unchanged. A separate four-case driver requires exact names, completion, nine original PNGs, and the existing native/read/send assertions. Per-case diagnostic JSON is also saved on the synthetic simulator so a failed driver cannot lose it.

Both discovery builders pass their exact selected simulator UUID into an opt-in Xcode destination. ONLY_ACTIVE_ARCH=YES avoids compiling the unused architecture. The legacy generic destination remains unchanged without that option. No signing identity, entitlement or permission is removed. Local controls: all 47 signer/identity/entitlement fixtures and all eight attachment/decoder/relay controls passed; final six-file analyzer returned zero issues. Real native results are pending and cannot authorize TestFlight.

## Proven VM discovery correction after 36e

Actual iPad run 40448435716 passed: VM discovered in 28.802s; real native counters and terminal `00:16 +4: All tests passed!`; exit0, no retries, no timeout, one verified simulator entitlement section. Artifact12709473569 SHA256 b376d7f7700120f9725427dc636e3fee2790c737638d193a303bcf0479cfc626 verified in full.

Actual iPhone run40448435745 failed before tests: a redundant `log show` command timed out, although its already-running filtered collector had captured the exact Runner PID's VM event. Replaying the actual retained386-event stream finds that VM in0.2744s with zero external commands. This is replay proof, not a new device pass. Artifact12710301979 SHA256 eb8835f89140aac9aa8c75258346b2e88838be3abe5cc665650108a59f6280b6 verified in full.

The corrected launcher waits for the stream's real readiness header before launch and discovers VM directly from its incremental captured JSON. It no longer runs `log show`. Ten input/decoder/relay/process controls passed locally, including rejected dead collectors and no-command stream discovery. The four-case driver now represents intentionally absent history as an empty collection; the full certification driver is untouched. A separate iPhone-only branch prevents rerunning the already successful iPad probe. Integration89c remains frozen.
