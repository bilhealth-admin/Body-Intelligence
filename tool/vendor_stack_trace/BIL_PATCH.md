# BIL stack_trace patch

This directory vendors `stack_trace` 1.12.1 from the Dart team, retaining its
upstream license and source. BIL changes only the Firefox/Safari trace detector
in `lib/src/trace.dart`: the nested quantified member-expression pattern is
replaced by a deterministic optional prefix so malformed worker trace strings
cannot trigger exponential backtracking. The public parsing API and package
version remain unchanged.

The source is used through the root `pubspec.yaml` dependency override. The
generated `web/drift_worker.dart.js` bundle must be rebuilt from
`tool/drift_worker.dart`; generated JavaScript must not be edited by hand.
