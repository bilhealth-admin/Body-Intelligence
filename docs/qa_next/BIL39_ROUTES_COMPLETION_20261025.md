# BIL39 route preservation and focused proof

PR17 `a2c396cb0c55054eadab0d885f4cf4472126f9a9` is preserved. No additional application route change was justified by the reviewed source and focused checks. The independent completion branch adds the shared inherited release-configuration test correction without changing the iOS38 workflow.

**29 focused tests passed on `b654acf5a7e8f27dd998013ff185fc47adabd38e`**, none skipped: safe return and PopScope widgets, route contracts, real steps history navigation, session video return, cold workout deep links without automatic paywalls, and release-configuration guards.

Review confirmed internal session return requires both its expected path/query and the in-process navigation extra; a forged external cold URL cannot acquire that state. Safe return checks do not substitute for native iOS swipe or Android system-back evidence. These remain final-candidate gates.

There was no merge, protected branch/main edit, Production change, real purchase, store submission or signing/upload action.
