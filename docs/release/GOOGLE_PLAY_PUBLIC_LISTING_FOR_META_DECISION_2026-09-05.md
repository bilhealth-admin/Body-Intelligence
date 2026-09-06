# Google Play public-listing path for the Meta Live gate — 2026-09-05

## Superseding outcome

Meta publication is no longer blocked. After the Play URL failure below, the
owner authorised temporary removal of the Android store platform from Meta;
Meta then confirmed the app as **Published / Live**. The Website and iOS
platform entries remain configured and Meta reports no required actions. The
Android package was not removed from BIL or Google Play.

The still-private Play URL now blocks only an **optional** recreation of the
Android platform entry in Meta. Keep the captured package, activity, and
key-hash values out of this public record. BIL's current Facebook flow is hosted
browser OAuth via Supabase, not a native Meta SDK integration, so this absent
entry is not a dependency or release blocker for that flow. Recreate it only if
a later, separately reviewed native Meta SDK/store integration needs it and the
canonical Play URL returns anonymous HTTP 200. Signed Android and iOS `+8`
end-to-end browser-return validation remains required before release.

## Historical decision before Meta publication

The current Google Play URL is not public, and applying for Production access
does **not** publish it.

The fastest official Google path that can publish the store-listing page
without making the closed-test `1.0.0 (7)` binary downloadable to the public is:

1. submit the already-eligible Production-access application after the two
   owner-only questionnaire selections are confirmed;
2. wait for Production access approval;
3. with separate owner authorisation, configure and start a genuine
   **Pre-registration** campaign;
4. wait until the campaign is `Active`, then verify the BIL details URL from an
   anonymous browser before recreating the Android platform entry in Meta.

This remains the fastest **candidate** path to a public Play URL, not a
guaranteed Android-platform reattachment path.
Google proves that an active pre-registration campaign publishes the Store
Listing at the standard details URL, but it shows `Pre-register`, not `Install`.
Meta's Android-platform validator has not been tested against an active BIL
pre-registration page. If it requires an installable app rather than merely a
non-broken public URL, pre-registration will not be sufficient.

There is no safe immediate path to restore the Android Meta entry today: both
Pre-registration and Open testing
are currently locked behind Production access, the public BIL details URL is
HTTP 404, publishing `+7` is prohibited by the release evidence, and no new
build is authorised in this task.

## Live evidence

Read-only checks on 2026-09-05 established:

- Play Dashboard: Production is `Inactive`; all three access prerequisites are
  completed; `Apply for production` is enabled and was not clicked.
- Live Alpha: `1.0.0 (7)`, served through closed testing.
- Test and release: no unpublished changes.
- Pre-registration page: “With pre-registration, your Store Listing is
  published before you launch” and “Pre-registration is available when you
  have production access.” Only `Go to Dashboard` is currently offered.
- Open testing page: “Open testing is available when you have production
  access.” It cannot be configured yet.
- Anonymous HTTP check at 2026-09-05 14:23:46 `+03:00`:
  `https://play.google.com/store/apps/details?id=com.bilhealth.bodyintelligencelog&hl=en`
  returned `404` with no redirect.
- A separate HEAD check of the canonical URL without the locale parameter at
  2026-09-05 11:24:20 GMT independently returned HTTP `404`.
- Before the owner-authorised temporary removal, Meta's `Publish` flow reported
  a hard `Broken URL detected` for the Android Google Play package and offered
  no `Continue` action. Meta publication then succeeded without that platform
  entry.

No `Apply`, `Next`, save, campaign start, release, rollout, submission, upload,
or build was performed.

## What each Play path actually does

| Path | Public standard details page? | Binary available to the public? | Requires Production access? | Decision for BIL now |
|---|---:|---:|---:|---|
| Current closed test | No for an anonymous/Meta request; current URL is 404 | No; selected opted-in testers only | No | Does not satisfy Android reattachment |
| Submit/approve Production access | No | No | This is the unlock step | Necessary, but insufficient by itself |
| Pre-registration | Yes, after the campaign is reviewed and `Active` | No; users see `Pre-register` | Yes | Fastest candidate that does not publish `+7`; Meta Android-entry acceptance must be proven live |
| Open testing | Yes; early-access apps are discoverable and anyone can join/install | Yes, as a test release | Yes | Do not use `+7`; viable fallback only with a later signed replacement |
| Production | Yes | Yes, to users in selected countries | Yes | Do not use `+7`; final path only after all release gates |
| Managed Google Play private app | No general-public listing; organization users only | Only to configured organizations | Separate managed distribution | Cannot satisfy a public Meta URL and is the wrong product model |
| Consumer “unlisted” app | Not a standard Play publishing status or path | Not applicable | Not applicable | No supported route to use |

Google's official publishing-status table distinguishes Internal, Closed, Open,
Pre-registration, Production, Unpublished, Removed, and Suspended states. It
does not provide a general-consumer `unlisted but public by link` state.
Managed private apps are restricted to organizations; Google warns that making
such a package public later requires publishing a new app with a different
package name.

## Why Production access alone is not enough

Google describes access approval as unlocking the Production and Open-testing
surfaces. A draft app is published only when a release is rolled out, while the
live BIL Pre-registration and Open-testing pages both state that those features
remain unavailable until access is granted. Therefore this sequence is false:

`Apply for access -> public Store Listing`

The valid no-public-binary sequence is:

`Apply for access -> approval -> start Pre-registration -> review -> Active -> public Pre-register page`

## Fastest authorised operating sequence

### Phase A — Production-access application

1. Owner confirms the true recruitment-difficulty selection.
2. Owner selects an evidence-based first-year install range.
3. Copy the reviewed answers from
   [`GOOGLE_PLAY_PRODUCTION_ACCESS_APPLICATION_DRAFT_2026-09-05.md`](GOOGLE_PLAY_PRODUCTION_ACCESS_APPLICATION_DRAFT_2026-09-05.md).
4. Only after explicit submission authority, send the application.
5. Keep at least 12 qualifying testers continuously opted in and keep the
   closed test active during review.

Google says the access review usually takes seven days or less, but can take
longer. There is no supported expedited route.

### Phase B — Optional Pre-registration bridge

Use this phase only if the owner genuinely accepts a public pre-launch campaign
and its 90-day launch clock; do not activate it solely as an undocumented URL
bypass.

1. After access approval, re-open the live Pre-registration page.
2. Confirm that the store listing, declarations, graphics, countries, and
   supported-device configuration are suitable for public visibility.
3. If Play requests an AAB for supported-device targeting, use only an
   explicitly approved existing artifact or later candidate. Google states
   that AABs uploaded to the pre-registration track for supported-device
   targeting are not released to users. Do not assume, before the page is
   unlocked, that Play will accept or automatically reuse Alpha `+7`.
4. Do not create a pre-registration reward.
5. Select the intended public countries and start the campaign only with
   explicit authority. Starting the first country begins that country's
   90-day deadline to launch in Production.
6. Wait for the status to become `Active`; `Draft` or `In review` is not public
   proof.
7. If the owner separately chooses a future native Meta SDK/store integration,
   check the exact standard details URL anonymously. Require HTTP 200 and a
   visible BIL `Pre-register` page before recreating the Meta Android entry.
8. For that optional integration only, recreate the Meta Android platform from
   the captured confirmed values and
   validate the unchanged package URL. If Meta shows
   `Broken URL detected`, stop and use the fallback below; do not remove or
   rewrite package identity as an improvised workaround.

Google does not publish a separate guaranteed duration for this specific
campaign review. Its general publishing guidance says reviews can take up to
seven days or longer in exceptional cases. For planning, allow up to seven
days for Production-access review plus up to seven days or longer for the
pre-registration publication review; either stage may finish sooner.

### Phase C — Guaranteed installable fallback

If a future native integration requires Android reattachment and Meta rejects
the active pre-registration page
because the app is not installable, the next least-expansive official path is a
public **Open testing**
release:

1. generate and sign the newer release candidate only under separate build
   authority;
2. complete the required device, purchase, integrity, permission, declaration,
   and pre-launch checks;
3. release that newer candidate to Open testing under separate submission
   authority;
4. verify the public listing and installation path anonymously, then recreate
   the optional Meta Android platform entry.

Do not promote or expose Alpha `+7` to Open testing or Production. If the owner
does not accept Pre-registration's public campaign and 90-day obligation, wait
for this newer-candidate path rather than publishing the old binary.

## Official sources

- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB): Production access unlocks Production, Open testing, and Pre-registration; access review usually takes seven days or less.
- [Build awareness with pre-registration](https://support.google.com/googleplay/android-developer/answer/9859047?hl=en): the listing uses the standard `details?id=<package>` URL, supported-device AABs are not released, and an active campaign has a 90-day Production deadline.
- [Set up an open, closed, or internal test](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en): an early-access Open test is visible/searchable and installable by users who join.
- [Publish your app](https://support.google.com/googleplay/android-developer/answer/9859751?hl=en): access/status is distinct from publication; Production is downloadable, Pre-registration is pre-registerable, and review can take seven days or longer in exceptional cases.
- [Publish private apps](https://support.google.com/googleplay/android-developer/answer/9874937?hl=en): private apps are restricted to managed organizations and are not a public-link substitute.

## Final recommendation

Apply for Production access as soon as the two truthful owner-only answers are
confirmed. Do not expect the application or its approval alone to publish the
Play details URL.

After approval, Pre-registration is the only documented Google route that can
make the BIL Store Listing public without releasing `+7`. Use it only with an
actual 90-day launch plan, then prove the exact BIL URL anonymously before
recreating the Meta Android platform. Treat Android reattachment as unproven
until Meta saves and re-reads the entry successfully. If it fails, wait for a
signed, verified replacement and use Open testing or Production; there is no
supported `unlisted` shortcut. Meta app publication itself is already proven.
