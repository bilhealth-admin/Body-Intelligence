# BIL final prebuild source acceptance — Android 30 / iOS 33

## Provenance

Native Android 29 / iOS 32 base: `9f439cae97d72b784880a1b1ac4ef1d33ede30c1`.
Retained Facebook, QR, Community and push fixes: `59839c7deb4d1cc860275b9e69578e299cc24d0a`.
Previously frozen Sapphire source: `927dce3f21f5984f4533c20296fc335b796ee8bd`.
Final audited application/test source: `960bead1d24ffea38d963b9e5f58fac0963a2579`.
Working branch: `fix/community-sapphire-health-3033`.

Final exhaustive QA run:
https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/36664811378

## Final fixes included

The accepted source retains the previously reviewed Community, QR, Facebook,
push, daily active-energy and completed-day heart-history work, then adds the
final prebuild corrections requested during visual review:

- Weekly Report previous/next controls are direction-aware in RTL/LTR.
- Nutrition empty-day "Log food" opens the existing real FoodLogPage inside the
  active navigator instead of entering the blank shell-child path; a direct
  widget navigation regression test covers open and return.
- Nutrition day navigation chevrons use the same direction-aware contract.
- More keeps every existing route and action, but uses the reviewed premium card,
  typography, spacing and semantic-icon presentation.
- The compact bottom dock preserves Dashboard / Quick Add / More only; Quick Add
  owns the reviewed blue-to-violet premium treatment and reserves physical space
  so it cannot overlap content.
- Quick Add's decorative sparkle is excluded from semantics and separately keyed
  from the real action glyph.
- Steps drill-in chevrons are direction-aware without changing health settings,
  native reads or Watch UI.
- The More implementation is split into a presentation part so the source-size
  architecture ceiling stays enforced rather than weakened.
- Reviewed golden masters were refreshed only for the intentionally changed
  Weekly RTL / More / affected settings review surfaces, then the one-shot
  refresh workflow was removed.

No store route, package/bundle identifier, purchase flow, native Watch settings,
native health permission surface, iOS/Google native login path, or Community
route was renamed by these changes.

## Complete unfiltered Flutter QA

Run `36664811378` completed successfully on exact source
`960bead1d24ffea38d963b9e5f58fac0963a2579`.

All `1,033` discovered `test/**/*_test.dart` files were assigned exactly once
across eight Windows 2022 shards with no path exclusions and no test-name
filters. Final visible case totals:

| Shard | Files | Passed | Failed | Errors | Conditional skips |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | 130 | 618 | 0 | 0 | 0 |
| 1 | 129 | 507 | 0 | 0 | 1 |
| 2 | 129 | 709 | 0 | 0 | 0 |
| 3 | 129 | 841 | 0 | 0 | 1 |
| 4 | 129 | 886 | 0 | 0 | 1 |
| 5 | 129 | 714 | 0 | 0 | 2 |
| 6 | 129 | 651 | 0 | 0 | 1 |
| 7 | 129 | 730 | 0 | 0 | 0 |
| **Total** | **1,033** | **5,656** | **0** | **0** | **6** |

The six skips are the existing host/opt-in conditional cases; no skip was added
to hide a regression.

The focused suite also passed `363` cases, and the two explicit performance
budget cases passed. `flutter analyze --no-pub` reported no issues.

## Visual, RTL/LTR, accessibility and Community acceptance

The final run passed the Community visual matrix in Arabic and English, light
and dark, normal and enlarged text. Eight final Community visual cases passed.
The reviewed Weekly RTL and More/settings baselines are strict byte/pixel
comparators again; the temporary one-shot baseline updater was removed before
this accepted source.

Focused and full-suite coverage includes RTL/LTR navigation, 25-locale copy
contracts, compact/wide shell navigation, enlarged text, Quick Add semantics,
More semantic icon spacing, Weekly Report history navigation, Nutrition entry
and return, and connected-health/Steps directionality.

## Cloud and data-integrity acceptance

The final visual/cloud job passed the isolated PostgreSQL Community contract and
12 Deno push-provider/community-dispatch tests with zero failures.

Production Supabase was also inspected read-only after the source fixes:

- every public table has RLS enabled;
- private/bil_admin_private tables expose no client DML grants;
- public RLS tables with no policy also have no client table grant;
- current production migrations include the QR visibility and Community
  attention/read migrations;
- `bil_rls_auth_initplan_optimization` replaced per-row auth.uid evaluation in
  the reviewed own-row policies without changing row authority;
- `bil_foreign_key_index_hardening` added advisor-requested FK covering indexes;
- database logs showed no sampled >=500 ms PostgreSQL duration event in the
  inspected window;
- push/community Edge Functions retain explicit auth/custom-secret boundaries.

The Supabase advisor still reports generic security-definer warnings for
authenticated RPCs. These RPCs were reviewed as an intentional API boundary:
the normal user-facing functions resolve `auth.uid()` directly or delegate to
gated helpers; the moderator wrapper delegates to the moderator-authority check.
The remaining leaked-password-protection warning is a project Auth setting, not
an application-source defect. The product login UI is passwordless/social; this
setting is not changed by SQL migrations.

Four performance warnings remain for duplicate permissive policies
(`bil_cloud_records` x3 and `bil_follows` SELECT). Removing those redundant
policies requires destructive policy replacement and was not forced through the
connector safeguard. They do not change correctness or authorization and are
not a source-build blocker.

## Health/Watch integrity boundaries

Native Watch settings, native health queries, dashboard/current-value UI and the
reviewed health permission surface remained byte-guarded in the final focused
run. Daily Active Energy remains one authoritative local-day total where
available. Heart history remains one completed-day recorded-sample mean, with
the >100 bpm day marker informational only; it is not a diagnosis or a
background/continuous alarm.

## Acceptance boundary

This record proves source-level, host-runtime, isolated SQL/Deno, visual
regression and cloud-contract acceptance for the final prebuild source. It does
not claim a signed AAB/IPA, real-device Facebook session, real FCM/APNs delivery,
terminated-app notification tap, physical HealthKit/Health Connect behavior, or
store approval. Those remain signed-artifact / physical-device acceptance after
source freeze.
