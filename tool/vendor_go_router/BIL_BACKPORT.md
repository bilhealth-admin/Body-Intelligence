# BIL ShellRoute collision backport

Base package: the published `go_router` **17.3.0** used by BIL38/BIL39.
The original BSD license is retained in `LICENSE`; original-file hashes and
published archive provenance are in `UPSTREAM.json`.

BIL reproduced `!keyReservation.contains(key)` using the actual production
router, approved My Plan, Meal Planner recipe sheet, and real DailyLogPage.
The reproducible sequence leaves a ShellRoute, pushes root feature pages,
then pushes a destination in the same shell. The prior branch contains a
shell page and navigator with the same keys as the newly pushed branch.

Upstream documents the fix in
[18.1.1](https://pub.dev/packages/go_router/changelog#1811). The exact published
18.1.1 archive was downloaded and SHA256 verified as
`07089be6dc124eb9596a51b5e359c657f30a59929287f11b126c2cd13eaaece0`.

The complete 18.x migration switches to distinct Material/Cupertino UI
packages. BIL retains the original Flutter widget types, public 17.3 API,
route composition and dependency versions. Only these files differ from the
copied 17.3.0 runtime:

1. `lib/src/match.dart`: carry ancestor/current shell matches into an
   imperative branch clone; scope colliding shell page and navigator keys to
   that imperative match; allow `ShellRouteMatch.copyWith` to carry the scoped
   keys. The upstream key classes use `route.pageIdentity`, introduced later;
   the backport uses the original 17.3 stable route-object identity instead.
2. `lib/src/builder.dart`: use the navigator key as a local ValueKey for the
   navigator container, rather than registering a GlobalObjectKey derived
   from only its integer hash.

No authorization, redirect, entitlement, route path, route builder, payment,
subscription, health, account or persistence behavior is changed here.

Verification belongs to BIL's real production-router journey regression and
the per-destination shell re-entry matrix, followed by the full app tests and
native device/simulator gates. A source copy alone is not release acceptance.

## Analysis configuration

The published 17.3.0 package includes an analysis file that inherits the
Flutter packages repository rules. Its relative include is relocated to the
frozen, exact tagged `upstream_analysis_options.yaml`; source and hashes are
in `UPSTREAM.json`. Those upstream rules enable strict casts, inference,
raw types and API documentation. They deliberately allow deprecated SDK
members (including the original Navigator `onPopPage` hook), as stated in
the upstream file. BIL application rules and test expectations are unchanged.
No blanket exclusion of vendor runtime source is added.
