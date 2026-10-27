# Discovery branch only

Base: 89c528e1aff7145607ddf7dd6fe62b9a7923370d. Integration source stays frozen.

The iPhone-only workflow observes the actual existing feature entrypoint and bridge lifecycle. It preserves every test assertion, 1500ms reply budget and 8000ms Community readiness budget. It does not run crypto/settings/RunnerTests again and cannot supply release acceptance. Debug-only diagnostics record synthetic geometry, generation, callbacks and visibility; no cloud, account credentials, paid provider calls or production data. Existing 10-workflow signing gate is untouched. No baseline update, build-number change, TestFlight, signing certificates or store changes.

Local evidence before dispatch: five real Python parser/orchestration tests passed; 17 Flutter presentation/composition/interaction tests passed; analyzer on the five instrumented Dart files reported zero issues. Both new workflows passed actionlint (ShellCheck/Pyflakes unavailable), and both discovery shell scripts passed actual Bash syntax checks. These results validate the diagnostic harness only. They do not prove the remaining native journeys or authorize release.

iPad evidence: original artifact 12707031283 (SHA256 4fe45a4bed5fc3d1a6ab712581bc6ec9634f734eb9889549a1300772eeac9c12) shows VM service publication by the exact Runner PID at 02:41:06.850 UTC while Flutter drive waited for discovery until its 1800s limit. The isolated iPad probe runs the actual crypto target through explicit existing-VM attachment, not another three-scope certification run. Production signing, OS permissions and simulator entitlements remain unchanged.
