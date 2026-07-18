# Performance budgets

BIL keeps startup free of network waits. The startup page opens the local shell
while starter-catalog seeding is deferred. Food search is debounced in the UI,
limited in the repository, and backed by indexes for exact barcode and common
ordering/join paths. Daily meals use canonical indexed day keys.

The automated performance test creates a fresh schema, inserts 1,000 foods,
and records database startup plus cold and warm bilingual/keyword search. The
budgets are deliberately checked in source:

- local database startup: under 2,000 ms on the test host
- 1,000-row local food search: under 500 ms cold and warm

Run the reproducible host measurement with:

```sh
flutter test test/performance_budget_test.dart --reporter expanded
```

Look for the `BIL_PERF` output line. These figures are developer-host evidence,
not physical-device cold-launch claims. Before a store release, record fresh
and warm end-to-end launch traces on representative low/mid/high Android
devices, Windows hardware, and supported browsers. iOS launch measurement
requires the release Mac and physical iPhone/iPad.

Latest recorded Windows-host full-suite run (2026-07-18, in-memory native test
database): startup 148 ms, cold search 50 ms, warm search 3 ms. Re-run rather than assuming
these timings apply to a device, browser storage backend, or future catalog.
