# Implementation Notes

The log proved that the forced-onboarding `StreamProvider` opened a real Drift
query during startup tests. Drift schedules stream-query cleanup on disposal,
leaving a zero-duration timer visible to Flutter's test invariant.

The preference is a startup decision, not a continuously changing UI signal.
It is therefore read once through `FutureProvider.autoDispose`. The startup
tests also override the dependency explicitly, preventing accidental use of the
production database.

This removes the pending timer without weakening the startup tests.
