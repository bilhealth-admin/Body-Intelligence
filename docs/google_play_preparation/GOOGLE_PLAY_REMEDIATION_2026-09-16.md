# Google Play remediation — 2026-09-16

Status: **locally verified source changes; not a signed release or store approval**.

## Source boundary

- Worktree: `G:/BIL_Project/body_intelligence_log_google_play_remediation`.
- Branch: `codex/google-play-remediation-20260916`.
- Parent: `cb389ebf4659eca1e946e5f850e61e429c8ec097`.
- The source used for iOS build 18 / Android build 15 was
  `d7fb5e5218ba82630ba635f227579fbc60b105f9`.
- This branch inherits the seven committed changes between those revisions.
  It does **not** incorporate the separate uncommitted purchase/refund/trial
  work in `body_intelligence_log_ios17_build18`, or the dirty main worktree.
  Those trees were not used as edit targets. Reconcile their pending work before
  choosing the eventual release commit; do not reset or overwrite either tree.
- No Supabase migration, deployment, entitlement grant, signed build, upload,
  Console save or review submission was performed in this remediation.

## Implemented changes

### Health Connect minimum scope

The Android manifest and runtime bridge now use exactly three **read-only**
types: Steps, Distance and ActiveCaloriesBurned. BodyFat, RestingHeartRate and
SleepSession named in the rejection, and all other Health Connect types outside
that allow-list, are removed. There is no Health Connect write, extended-history
or background-read permission. Initial history uses the ordinary 30-day window.

The Android export action is hidden and the native write/delete entry points
fail closed. Missing/unsupported read/request arguments never expand the scope.
Permission-status lookup still returns the three supported types when queried
without arguments, matching the existing Flutter bridge contract. Empty consent
requests do not open a permission sheet; launcher failure releases the pending
request.

This deliberately narrows **Android Health Connect imports**, including removal
of weight/nutrition/sleep/vitals imports. It does not remove manual recording,
compatible BLE device integration, or alter Apple Health scopes. Out-of-scope
old imports are filtered from the connection-status projection; the underlying
local history is not deleted. Android permission rationale text in all five
native locales and repository declaration/privacy drafts describe the new scope.

### Android subscription checkout

- A subscription purchase tap now refreshes the selected Play ProductDetails,
  with a 10-second bound, before opening billing. Opening the Plans screen is
  not a purchase action.
- A rotated offer token is accepted only when product, base plan, offer ID,
  currency and every pricing phase/period/cycle/recurrence still match.
- Missing products or changed terms update the Plans display and require a new
  deliberate purchase tap. They never silently substitute a different offer.
- The displayed-offer token is carried through the adapter so a stale screen
  cannot buy another cached offer for the same product ID.
- Account changes, stale/disposed request generations, duplicate taps, timeout
  and late query replies do not launch an unintended checkout.
- A same-product purchase is not passed to Play as a replacement of itself.
  Existing cross-product upgrade/downgrade handling remains intact.
- Subscription candidates without a usable offer token are excluded.
- The changed-offer message has explicit copy in all 25 app locales.
- The iOS purchase launch path and AI Boost discount/checkout contract were not
  migrated to this new Android subscription preflight.

These changes address reproducible client-side stale-offer and same-product
replacement hazards. They do **not** prove that either was the sole cause of
Google's original device error. Google advises against caching ProductDetails
because stale objects can fail billing launch:
[Play Billing integration](https://developer.android.com/google/play/billing/integrate).

### Release source audit

The permission audit now rejects any Health Connect permission outside the three
allowed reads. Two pre-existing stale audit assumptions were corrected without
changing build tooling or iOS entitlements: AGP is pinned to the actual `9.0.1`
project setting, and Debug APNs may be absent or `development`, never production,
unknown, malformed or duplicated. Regression tests cover these checks.

## Read-only live Console observations

Observed in the authenticated Google Play Console on 2026-09-16:

| Item | Observed state |
| --- | --- |
| Subscription IDs | `bil_premium`, `bil_premium_annual`, `bil_premium_ai_coach`, `bil_premium_ai_coach_annual`; each has one active base plan |
| AI Coach monthly | `monthly`, monthly auto-renewing, active in 169 regions; India INR 690.00 |
| AI Coach annual | `yearly`, yearly auto-renewing, active in 169 regions; India INR 5,600.00 |
| Historical annual-product base plan | ID `annual` is actually monthly and inactive; still marked backwards compatible; **not activated or edited** |
| AI Coach trial offers | `trial-7-day` shown active under the monthly and yearly base plans |
| Publishing overview | Recent changes rejected; five existing changes not yet submitted, including production version 13, closed-test version 14 and Health apps declaration; none submitted here |

The subscription IDs exist and the displayed India prices match the review
screenshot. This rules out claiming that the products are simply absent from
Console today, but does not establish what the reviewer account or old binary
received at the time of failure. Trial eligibility, the exact installed billing
response and successful device checkout remain to be verified. No prices,
availability, legacy plans, offers or declarations were changed in Console.

## Local verification

Diagnostics are local (ignored) under
`build/diagnostics/google_play_remediation/`:

| Check | Result / evidence |
| --- | --- |
| Offline dependency resolution | Passed; no dependency-lock changes |
| Commerce + new Android scope group | 93 passed; `commerce_regressions_retry.log` |
| Health, UI and release-contract group | 127 passed; `health_and_release_regressions_retry.log` |
| Final audit regression file | 5 passed; `release_audit_regressions_final.log` (overlaps the group above; do not add these as independent totals) |
| Changed Dart files (23) | No analyzer issues; `final_analysis_after_audit.log` |
| Source release audit | `EPIC14_RELEASE_AUDIT=PASS`; `release_source_audit_final.log` |
| Native Health Connect bridge | Isolated Kotlin compilation passed against the cached Android 36 / Health Connect 1.1.0 / Kotlin 2.3.20 APIs; `kotlin-check/` |
| Diff whitespace | `git diff --check` passed |

The first commerce run had one **test-harness** failure because its simulated
Android platform override was still active at widget-test teardown. The test
now cleans it up in `finally`; the complete commerce group was rerun from the
start and passed. Initial audit failures and initial test logs were retained.
The full repository 10-batch suite was **not** restarted. The isolated Kotlin
compile is not a Gradle application build, merged-AAB inspection or device test.

## Remaining release gates

1. Reconcile the separate pending iOS/purchase/refund/trial work with this branch
   and select one final source commit. Do not assume this branch contains those
   uncommitted changes.
2. Build a new signed Android artifact with an unused version code above 15.
   Inspect its **merged manifest**, package ID, native libraries and billing
   configuration. Keep the rejected version 13 out of the replacement submission.
3. Update the live Health Connect declaration to the three read-only data types,
   matching the final artifact and visible activity dashboard. Review the live
   privacy/Data Safety answers against actual enabled data flows; repository
   drafts do not update Console.
4. Install the exact candidate through a Google Play test track. Test monthly
   and annual Premium/AI Coach, trial-eligible and ineligible users, repeat taps,
   cancel, offline/retry, active subscription, upgrade/downgrade, restore,
   account switch, refund/revocation, trial cancellation and renewal. Verify
   server ownership and expiry; never infer access from a client success toast.
5. Test Health Connect grant, partial grant, denial, revocation, existing-user
   upgrade and daily totals on Android devices. Verify that the permission sheet
   contains only the three intended reads and no automatic permission request.
6. Capture new device evidence, then review and submit the intended replacement
   changes. Source tests do not establish Google approval or a published release.
