# Preserved historical owner reference dataset

This fixture exercises the historical visual-evidence metadata verifier. It is not the current BIL UI, current Polish approval, a Git2c518ee4 snapshot, a phone artifact, or store-review evidence.

The original metadata, 161 PNG files (10,321,500 bytes), and 35 real production source files were preserved from the owner's primary checkout. Exact source HEAD, branch, dirty-worktree context, per-file original hashes/byte counts, and the four existing screen-label discrepancies are recorded in provenance.json. All truth statuses, routes, hashes, and bytes remain unchanged; this fixture adds no visual approvals.

Production Dart source is stored byte-for-byte as .dart.txt so Flutter Analyze does not resolve an incomplete historical source tree. The test reconstructs the real original paths in a temporary root, checks integrity, and invokes the production verifier in read-only mode. It does not synchronize or alter current artifacts or Goldens.

The current UI has its own independently reviewed Golden evidence. Passing this historical metadata contract must not be reported as approval of the current UI.
