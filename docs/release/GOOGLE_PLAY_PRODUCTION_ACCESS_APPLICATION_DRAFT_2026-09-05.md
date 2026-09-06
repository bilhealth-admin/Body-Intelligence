# Google Play production-access application draft — 2026-09-05

## 2026-09-06 live form addendum — submitted, under review

The authenticated Console form now contains the following owner-confirmed,
bounded answers. Google added a recruitment-source free-text question that was
not represented in the original 5 September draft. After the owner gave the
explicit action-time instruction `نعم، أرسل الطلب الآن`, the final `Apply`
control was pressed once. Google accepted the application and now shows it as
under review. No release, rollout, price, track, or binary was changed.

1. **Recruitment source — 254/300:** `I live in Egypt and am originally from
   Jordan. Recruiting testers was very difficult because I had few close
   contacts and people were reluctant to share an email address. After repeated
   attempts, I gathered enough testers to evaluate successive versions.`
2. **Recruitment difficulty:** `Very difficult`.
3. **Engagement — 291/300:** `Engagement was uneven. Some testers opened the
   app briefly; others tested onboarding, profile/goals, navigation, refresh
   and cloud sync across successive builds. Not every tester used every
   feature. This was shorter and more task-focused than the broader repeated
   use expected in production.`
4. **Feedback — 262/300:** `We received 5 private Play reports from 29 Aug–2
   Sep on Android 10, 12, 14 and 16 (version codes 4, 5 and 7), plus WhatsApp
   messages, calls and screenshots. Feedback identified blocked target-weight
   entry, stale data until restart and occasional slow cloud sync.`
5. **Audience — 253/300:** `Adults aged 18+ who want to track nutrition,
   hydration, weight and body measurements, fitness activity, personal goals
   and wellness trends. BIL is a wellness and fitness tracker, not a medical
   device and not a substitute for professional medical advice.`
6. **Value — 290/300:** `BIL combines meal, hydration, weight and
   body-measurement logging, activity, goals and progress trends in one
   privacy-conscious multilingual app. Core logging works locally without an
   account; optional cloud, connected-health and AI features are available
   only when configured and entitled.`
7. **First-year installs:** `10K – 100K`, the conservative Console range that
   contains the owner's exact 100,000 estimate. The other live choices are
   `0 – 10K`, `100K – 1M`, `1M+`, and `I don't know`.
8. **Changes — 295/300:** `Feedback led us to fix stale profile/goal state,
   strengthen target-goal persistence, correct blank screens and deep links,
   improve Quick Add dismissal, bound AI waits, and improve barcode and
   video/network recovery. These changes target build 8; live closed-test build
   7 still had reported bugs.`
9. **Readiness — 279/300:** `We request production access because Play confirms
   at least 12 continuous opt-ins for at least 14 days and tester feedback
   guided build 8 improvements. Approval will not publish build 7. Signed build
   8 will receive final billing, permission and declaration checks before
   rollout.`

The authenticated Dashboard read-back at `2026-09-06T07:23:29.300Z` displayed
`We have your application for production access`, said the form is under review
and that an update usually takes seven days or less (but may take longer), and
showed `Applied today, 10:22`. This proves receipt only; it does not prove
approval. Production remained inactive, and build 7 was not published.

This addendum supersedes the three owner placeholders below. The historical
5 September preparation remains intact so its evidence boundaries can still be
audited.

## Status and decision boundary

The 5 September material below remains a historical copy-ready draft. The live
addendum above records the separate 6 September submission and supersedes any
older `not submitted` boundary for the application itself.

- **Production-access application:** submitted once and under Google review;
  this is not yet an approval.
- **Public production rollout:** not ready yet. Access approval must not be
  treated as permission to publish the current or local build.
- **Current version boundary:** closed testing has live release `1.0.0 (7)`;
  the current repository declares `1.0.0+8`. The latest tester-note fixes are
  source/test evidence, not a signed or Play-tested `+8` release candidate.

Google's current official question set and testing rules are documented in
[App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB).

## External dependency note — not an application answer

Meta is now Published/Live after the owner-authorised temporary removal of its
Android store platform entry. The anonymous Google Play details URL for this
package still returns HTTP 404, so that URL remains a blocker only to recreating
the Android entry in Meta. Applying for or receiving Production access does not
itself publish the URL. The separate evidence and fastest official visibility
path are documented in
[`GOOGLE_PLAY_PUBLIC_LISTING_FOR_META_DECISION_2026-09-05.md`](GOOGLE_PLAY_PUBLIC_LISTING_FOR_META_DECISION_2026-09-05.md).
Do not mention this Android-reattachment dependency in the Production-access
questionnaire unless Google explicitly asks for it.

## Two owner-only selections required before copying

Do not guess either selection. The evidence available to this audit does not
answer them.

| Console selection | Draft value | Why it cannot be inferred |
|---|---|---|
| How easy it was to recruit testers | **OWNER MUST SELECT the truthful Console option** | The Console proves the test threshold, but not the recruitment channel, effort, or difficulty. Do not claim friends, family, colleagues, a community, paid recruitment, or any other source unless the owner confirms it. |
| Estimated first-year install range | **OWNER MUST SELECT from a real business forecast** | The current installed audience is test evidence, not a public-acquisition forecast. If no forecast exists, select the lowest Console range the owner can honestly support; do not manufacture a growth estimate. |

Remove every `OWNER MUST SELECT` placeholder before submission.

## Part 1 — About your closed test

### 1. How easy was it to recruit testers?

**Selection:** `OWNER MUST SELECT the truthful option shown in Console`

No supporting free-text claim should be added unless the form requests it and
the owner confirms the recruitment method.

### 2. Describe tester engagement, feature coverage, and expected production behaviour

**Copy-ready answer:**

> Tester engagement covered installing and opening the app, onboarding,
> profile and goal data, routine navigation, data refresh, and cloud sync. It
> did not cover every feature, and not every tester exercised the same paths.
> Usage was shorter and more task-focused than expected long-term production
> behaviour. Play feedback alone did not verify purchases, long-term
> retention, or every camera, microphone, connected-health, and device path.

Why this wording is accurate:

- It explicitly answers that **not all available features were tested**.
- It does not turn brief daily opens into a claim of deep engagement.
- It separates the observed test behaviour from expected longer-term use.
- It does not attribute the broader screenshot/device QA packet to every
  Google Play tester.

### 3. Summarise the feedback and how it was collected

**Copy-ready answer:**

> We received five private Play reports from 29 August to 2 September across
> Android 10, 12, 14, and 16 and version codes 4, 5, and 7. Two were positive
> general comments. Three reported blocked target-weight entry in onboarding,
> data sometimes requiring an app restart to refresh, and occasional slow cloud
> sync. Reports came through Play private feedback; the test also listed a
> support email. We separately reviewed supplied screenshots and written notes
> in project QA.

Do not add tester names. The five live reports were all five-star reports, but
the rating is deliberately omitted from the answer so the substantive findings
remain the focus.

## Part 2 — About your app

### 4. Specify the target audience

**Copy-ready answer:**

> Adults aged 18 and over who want to track nutrition, hydration, weight and
> body measurements, fitness activity, personal goals, and wellness trends.
> BIL is a wellness and fitness tracker, not a medical device and not a
> substitute for professional medical advice.

This matches the live Play target-age selection (`18 and over`) and the
repository health-app boundary.

### 5. Describe the app's value proposition

**Copy-ready answer:**

> BIL brings daily meal, hydration, weight and body-measurement logging,
> activity, goal tracking, and progress trends into one privacy-conscious,
> multilingual experience. Core logging works locally without an account.
> Optional cloud, connected-health, and AI features are available only when
> configured and entitled, helping users understand habits without presenting
> medical diagnosis or invented data.

### 6. Estimate the first-year install range

**Selection:** `OWNER MUST SELECT from a documented business forecast`

Do not use the live `Installed audience: 12` value as a public first-year
forecast. It describes current test/audience state, not expected acquisition.

## Part 3 — About your production readiness

### 7. Describe changes made based on the closed test

**Copy-ready answer:**

> Feedback led us to fix stale profile and goal state after writes, strengthen
> target-goal persistence, correct blank-screen and deep-link navigation,
> improve Quick Add dismissal and dragging, bound AI response waits, and add
> safer barcode recovery. The onboarding target-weight validation report and
> occasional cloud-sync delay remain explicit signed-build retest items. The
> newest fixes are source-tested but are newer than the live Alpha 1.0.0 (7).

The final two sentences must remain unless a signed replacement containing the
fixes is uploaded and the two Play-reported cases are retested successfully.

### 8. Describe how production readiness was determined

**Copy-ready answer for the current state:**

> We are ready to request production access because Play confirms the closed
> test gate of at least 12 continuous opt-ins for at least 14 days, the test
> produced actionable feedback across four Android versions, and Play
> currently shows no account or app policy issues. Approval will not trigger a
> public rollout. Before release, we will upload a signed build containing the
> latest fixes and complete phone/tablet, purchase, integrity, permission, and
> declaration checks.

This answer intentionally distinguishes **access readiness** from **public
rollout readiness**. Do not replace it with “the app is fully production-ready”
under the current evidence.

## Live evidence snapshot used by this draft

The following was read from Play Console without a write action and reverified
on 2026-09-05 at 13:57 `+03:00`:

| Evidence | Verified state |
|---|---|
| Developer account type | Personal account |
| Closed-test release | Alpha `1.0.0 (7)`, active; released 2026-09-01 |
| Production prerequisites | Closed release published; at least 12 testers opted in; at least 12 testers for at least 14 days — all displayed as completed |
| Production access control | `Apply for production` displayed and enabled; it was not clicked |
| Tester-list membership | 18 accounts in the configured list |
| Installed audience | 12 |
| Qualified continuous count | Exact number not exposed; the completed Play gate proves **at least 12**, not that all 18 qualify |
| Feedback | Five private reports; Android 10/12/14/16; version codes 4/5/7; dated 2026-08-29 through 2026-09-02 |
| Policy status | No account issue and no app issue displayed; App content showed no pending item |
| Pre-launch report | No report generated; Console requested an artifact upload |

### Timing interpretation

- Alpha reached 100% rollout on 2026-08-17 at 06:02 in the Console-displayed
  timezone.
- The tester list and feedback channel were attached on 2026-08-17 at 06:54.
- The earliest possible exact completion of 14 continuous 24-hour periods from
  that attachment time was 2026-08-31 at 06:54. The live completed gate is the
  authority; individual opt-in timestamps were not exposed.
- At the 2026-09-05 13:57 `+03:00` recheck, 19 days, 7 hours, and 3 minutes had
  elapsed since the list attachment. That is only the maximum possible tenure
  for a tester who opted in immediately and never opted out; it is not an
  individual tester duration exposed by Play.
- Eight testers doing brief daily actions from 31 August through 4 September
  spans five calendar dates and does not by itself prove either 12 testers or
  14 continuous days. It must not be presented as the qualifying cohort.

## Local evidence and remaining release boundary

- [`TESTER_NOTES_CLOSURE_2026-09-04.md`](TESTER_NOTES_CLOSURE_2026-09-04.md)
  records source fixes and automated regression evidence, while explicitly
  stating that the repair batch is not a signed release candidate or device
  proof.
- [`BIL_LIVE_STORE_PREFLIGHT_2026-09-04.md`](BIL_LIVE_STORE_PREFLIGHT_2026-09-04.md)
  records the live Alpha `+7` release and no Production release, plus unresolved
  price and territory reconciliation.
- [`PLATFORM_PARITY_AUDIT_2026-09-03.md`](PLATFORM_PARITY_AUDIT_2026-09-03.md)
  keeps signed-device, Play Billing, Play Integrity, final declaration, and
  phone/tablet validation as release gates.
- [`BIL_EPIC15_PLATFORM_METADATA.json`](BIL_EPIC15_PLATFORM_METADATA.json)
  supports the 18+ wellness/nutrition/fitness positioning and the non-medical
  claim boundary.
- [`../google_play_preparation/STORE_LISTING_INVENTORY.md`](../google_play_preparation/STORE_LISTING_INVENTORY.md)
  records version `1.0.0+8`, 25 configured locales, RTL support, and the
  health/fitness, nutrition, and weight-management category direction.

## Claims policy — what must not be said

Do not state or imply any of the following in the application or reviewer
notes:

1. “Eight testers completed the requirement” or “31 August to 4 September was
   the 14-day test.” The qualifying fact is Play's completed **at least 12 for
   at least 14 days** gate.
2. All 18 list members were continuously opted in. List membership, installed
   audience, and continuously qualifying testers are different measurements.
3. Every tester used every feature, or brief open/close activity was
   production-like engagement.
4. Every reported issue is fixed in the live Alpha `+7`. The latest closure is
   current-source evidence; a signed replacement and device retest remain.
5. The onboarding target-weight validation issue or occasional cloud-sync
   delay is closed without a recorded signed-build retest.
6. Purchases/restores, Play Billing, Play Integrity enforcement, camera,
   microphone, barcode recognition, Health Connect/BLE hardware, long-term
   retention, tablets, or a pre-launch report were fully validated when the
   evidence does not prove that.
7. “Zero crashes” or “fully stable” merely because no crash/ANR issue row was
   visible in sparse Android Vitals data.
8. Production access approval means a release was published, a signed release
   candidate exists, or public rollout is ready.
9. Universal barcode/nutrition coverage, medical diagnosis, treatment,
   prevention, or guaranteed AI/cloud results.
10. Recruitment sources or first-year install forecasts that the owner has not
    confirmed.
11. Tester identities, credentials, private account data, or operational
    account details.
12. The existing generic feedback-reply wording about “reading news”. That text
    describes the wrong product and must not be reused for BIL.

## Pre-submit operator checklist

- [ ] Owner selected the truthful recruitment-difficulty option.
- [ ] Owner selected an evidence-based first-year install range.
- [ ] No placeholder remains in the answers.
- [ ] At least 12 qualifying testers remain opted in while Google reviews the
  request.
- [ ] The live prerequisite cards still show completed immediately before
  submission.
- [ ] The operator understands that `Apply` requests access only and does not
  authorize a Production rollout.
- [ ] The signed `+8` candidate and the remaining release gates stay blocked
  until separately completed and verified.

## After a separately authorised application

This is the operating plan only; it does not authorise the application itself.

1. Keep the qualifying closed test active and keep at least 12 testers opted in
   throughout Google's review.
2. Monitor the account-owner email. Google states that review usually takes
   seven days or less, but can take longer.
3. If Google requests more testing, continue the same closed test and address
   the stated engagement or tester-count issue; do not create a substitute
   production rollout.
4. If access is approved, treat it only as an unlocked Production/Open-testing
   capability. Keep the public release blocked until the signed candidate and
   all device, commerce, integrity, declaration, asset, price, and territory
   gates are reconciled.

No `Apply`, `Next`, `Save`, submission, release, rollout, build, or commit was
performed by preparation of this draft.
