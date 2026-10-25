# BIL39 completion intake and current evidence

Status: **BLOCKED — no final integrated candidate or release approval.**

The central machine-readable register is `BIL39_CENTRAL_TRACEABILITY_20261025.json`. It preserves all 27 original cases, ten Coach additions, 18 additional Coach acceptance scenarios, the video/source requirement, two cloud scopes and ten cloud truth subgates. The validator now requires all 68 unique acceptance IDs; its own synthetic self-tests are not application QA.

## Preserved source

- Complete handoff ZIP SHA-256: `bd62a5c229b00687968cf43b816bc809478f7f0062c78169ca5e8ff8487fe28b`.
- Protected iOS38 base: `155b079696430919f8272df934371f033fb11be2`.
- All nested substantive handoff documents were read; all 35 original photos are retained privately with hashes. No private photo was committed.
- GitHub PR15–24 and all remote branches were inventoried. PR24 is an obsolete preview, not a final source. PR16 starts from an older base; only its two reviewed MP4 defense commits are carried into a separate completion branch.
- The original dirty checkout was preserved. Completion work uses separate worktrees and branches. Worker branches, main, iOS38, App Review, prices and Production have not been modified.

## Confirmed source fixes

- Coach: distinguish nutrition review from plan creation; recognize the explicit Arabic app-language command; preserve the approved entry welcome before Overview. Tests enter conversation through the actual Overview action and retain privacy, receipts, account isolation and lifecycle assertions.
- Cloud: deterministic post-model Arabic/English weight truth validation, including unknown versus verified-empty context; no added model call or credit reservation. Full typed handler suite: **164 passed on `9c2c7d259daa0a9538c36376fc12b9768f189943`**, [CI evidence](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/40187927852). This does not prove live Gemini or deployed staging.
- Video: English metadata-only source pages, isolated local Worker tests, and PR16 MP4 MIME defense. **68 local tests passed** before the CI-only commit; separate exact-SHA CI is running. No application source link has been redirected to an unproven deployed route.
- MyPlan: corrected Arabic text contrast in tabs, collapsed exercise title and session completion checkbox without reducing the existing Flutter accessibility checks. Actual new artwork/metrics surfaces were reviewed against old references; final baselines and complete test results are pending.
- Inherited QA failure: the release-configuration test now verifies the exact protected iOS38 conditional manifest and strict default, rather than expecting an obsolete literal. **8 focused tests passed**; the iOS38 workflow itself is unchanged.

## Mandatory remaining work

1. Finish scoped completion QA and source review for all workers; Crystal still has an explicitly partial arrow inventory. Do not label it complete because one shared back component exists.
2. Resolve the four documented overlaps semantically, preserving every worker's behavior. No automatic PR merge or overwriting another developer's branch.
3. Establish a genuinely isolated deployed staging environment. The pre-existing Workers staging configuration references production resources and must not be used as staging proof.
4. Run final format, analysis, focused, full Flutter, reviewed goldens, security, privacy/RLS, lifecycle/deeplinks and native iPhone/iPad plus Android 26/29/33/34/35/36 on the **same frozen integrated SHA**.
5. Complete physical acceptance and independent final review. No source test, debug APK, or queued CI job substitutes for those results.
6. Only after those gates pass: prepare/sign Build39 and upload to internal TestFlight. Do not submit to App Store review.

No final integration, production deployment, version bump, signing, TestFlight upload or store submission has occurred in this completion work.
