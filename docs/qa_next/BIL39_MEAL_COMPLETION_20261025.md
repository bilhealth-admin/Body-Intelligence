# BIL39 Meal Planner bounded recovery

Worker source `19fd1384220a892fad439426e2f1ab0de7e82781` is preserved. Its owner-fenced snapshot loading, atomic compare-and-set saves, grocery serialization, draft versus saved servings, recipe-to-diary search and explicit final food confirmation remain intact.

Source review found one remaining indefinite-loading path: the initial `Future.wait` of saved preference/plan reads had no deadline. A stalled local repository could keep the spinner forever without reaching the existing safe retry state.

The read-only load now expires after 12 seconds and uses the existing translated recovery message. It does not delete, replace or write a plan. An expired read completing later cannot clear the error; the member must use Retry to start a fresh load. No timeout was added around an in-flight mutation, where a late commit would require reconciliation rather than assuming no write.

The new real widget regression first failed on the original worker (`Retry` was absent after the deadline), then passed after the source fix. It holds the actual repository reads, checks the unchanged saved week and zero mutation attempts, releases the late result, and verifies explicit successful retry. All 33 Meal Planner tests passed in the working tree. These local results do not establish final integrated/native readiness; exact committed CI remains required.

No commerce, prices, protected iOS38 branch, main or Production change is included.
