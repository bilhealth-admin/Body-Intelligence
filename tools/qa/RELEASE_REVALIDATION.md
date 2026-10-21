# Current BIL release revalidation

Run `tools/qa/run_bil_release_revalidation.ps1` from the reviewed repair worktree.
`-PlanOnly` prints the complete plan without running tests, committing or dispatching.
The launcher starts a hidden Python controller and records its PID under
`build/revalidation-launches/`. The dashboard defaults to `http://127.0.0.1:8775/`.

Execution order:

1. Under the existing owner lock, resolve dependencies with the pinned Flutter
   engine using `pub get --enforce-lockfile`. Require every resolved package root
   to exist, parse package library URIs as local paths, and bind
   `body_intelligence_log` to this worktree with its library directory present.
   Verify the required scanner Dart entrypoint. Asset-only dependencies need no
   library directory; Pub cache and legitimate external package roots are allowed.
   A bootstrap or discovery failure stops before any formatting or test stage;
   the source checkpoint still rejects tracked source or lockfile changes.
   Then check reviewed Dart formatting and execute every complete focused file.
2. Discover and execute every golden-related test entrypoint, including transitive
   helper imports. No baseline updates or test-name filters.
3. Analyze the entire Flutter project with fatal warnings and infos.
4. Run the original `bil_owner_full_test_runner.py` unchanged, with its original
   resource guard, full file inventory, source fingerprint and acceptance rules.
5. Only after every local gate passes: commit exactly the reviewed dirty paths,
   verify committed blobs against tested bytes, push once to the unchanged
   integration branch, then verify the remote SHA.
6. Run the explicit affected/unproven CI profiles. Reuse an automatically started
   push run only where its source and profile match. Never retry an ambiguous
   dispatch or accept another source, skipped required job or partial root run.

Each stage keeps its actual exit code, raw log and result. A failed prerequisite
blocks the expensive full suite and publication; the focused/golden/analysis
diagnostic stages retain their failures. Source changes invalidate progression.
The dashboard server remains available after success or failure.

The script does not change application versions, sign builds, submit to a store,
send an appeal, or declare store readiness. The plan lists separate production,
store-console, final-artifact and physical-device gates with their actual status.
The newly deployed Circle migration has a separate checked-in readback receipt;
local SQL success alone is never deployment evidence.

The controller never resets/cleans the worktree, weakens the original 4GiB RAM
guard, kills unrelated applications, or applies automatic fixes to failed tests.
If that resource threshold remains unmet it waits visibly, then stops honestly.

Use a new run label for a new attempt. Existing run evidence is never overwritten.
The full runner's original dashboard is linked from the current sequence page.
