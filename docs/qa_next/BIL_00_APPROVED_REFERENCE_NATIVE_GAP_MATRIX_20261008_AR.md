# BIL-00 · Approved Reference ↔ Native Flutter gap matrix · 2026-10-08

**Status: QA evidence, NOT pixel-parity acceptance or Google Play resubmission approval.** This tracks approved private BIL reference concepts and public synthetic Flutter QA snapshots without copying the user's private reference artwork to GitHub.

## Immutable references and exact evidence

- Approved AI Coach artwork SHA256: `07f25ba0fffc661e5232a4fba6365ee3ff96cbea69636c2672b97f4fafce63d0`.
- Approved Community eight-panel concept SHA256: `db67d1c6bb1f4ecd3c539ada3de72a980c610b7c1d2331c4796b7fa27e3bbea4`.
- [Actual native Flutter run 37812679789](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37812679789), SHA `c3928674e2f85559171cdee1be2cad88bb0f05da`, SUCCESS; [artifact 11566196411](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37812679789/artifacts/11566196411) contains **272 PNGs** plus logs, only short-retention (do not rely on the artifact remaining available indefinitely).
- Representative actual native PNG SHA256 (synthetic fixtures; identifiers reference artifact-relative paths, **not uploaded copies of private owner references**):
  - `community/composer_en_light_1.png` → `826bfc052375c91ad41c18955e6c08b26f629179ffa086307fa79bc321b1cf84`.
  - `community/feed_en_light_1.png` → `0606f08fbadf1aef1bf949c33981bd10b04d2870a0bb384448e1f5e516cebac0`.
  - `community/circles_en_light_1.png` → `8f96ad59399611a1b376ad607ab86ac53530aa24e7fa1ec3b37a78cdbf2d61b7`.
  - `community/moderation_en_light_1.png` → `417176fd4b9c8ef0f63162ce6cf92aeddb8e82262e97f0ed96cf4378ccc52d35`.
  - `community/channels_en_light_1.png` → `9d5d1a809ea5312ce20ba09eb689eb08c6ce10c89ccb9323f10f3eec6d4de161`.

Artifact and hashes establish **reproducible captured bytes**, not visual similarity scores. Approved drawing is a multi-phone composite: per-panel phone crop, pixel density, screenshot status bar, real content and viewport must be normalized before objective pixel comparisons.

## Owner reference review matrix

| Panel | Actual Flutter UI and checks | Remaining visible difference / required gate | Acceptance |
|---|---|---|---|
| 1. Community Home / Explore | Native Feed is real, 4 bundled BIL photos render as 2×2, Like is a heart, Save a bookmark, topic chips sourced from real taxonomy, Dock navigates | Reference shows richer real avatar/story/gallery and more compact card/engagement content than synthetic QA. Verify same author/photo/copy fixtures and crop | **Functional visual capture passed; pixel parity open** |
| 2. Notifications | Real Activity widget displays reaction/comment/mention and a **synthetic server-shaped** approved-post +5 AI receipt, never a real credit grant | Reference mixes approved post, reactions, new follower and comments with different avatar/title density. Verify genuine server receipts and matching fixture rows | **Layout captured; receipt/device E2E open** |
| 3. Composer | Real editor captured with **three decoded JPEG photo tiles and fourth Add tile**; strict RawImage pixel presence and 200% scale without 2dp overflow; Publish/Save intact | Approved concept uses 2000 counter; owner-approved BIL contract is **1200 Unicode**, never increase to 2000 for superficial parity. Native photo picker and server upload still need device E2E | **Native visuals passed; device E2E open** |
| 4. Profile | Native cover, avatar, action rail, Moments/Reviews/owner access render; reference geometry restored to 80/248 ratio, min 88.5dp actions | Approved visual has specific personalized cover/photo, badges and four profile content categories. QA fixtures cannot prove the private live profile nor pixel match | **Geometry tests in progress; pixel parity open** |
| 5. Drafts | Real Private Drafts list, decoded 2×2 media tile, Edit/Continue/Select, cache/retry checks | Approved concept has two distinct photo-rich drafts. QA screenshot includes one fixture draft; cannot infer actual cross-device ownership or encryption | **Capture passed; two-row/source-of-truth parity open** |
| 6. Circles / Groups | Native discovery/search/membership cards and actions, separate from Chat; synthetic visual expansion prepared from 2 to 6 rows | Existing QA artifact has two rows, approved artwork six with photo avatars; **six synthetic rows prepared but not yet accepted by CI**. No right to invent Production circles | **Expanded capture pending** |
| 7. Community Chat (channels) | Native public-channel directory and conversation tested separately from private DM; synthetic category rows and read-only counters | Reference requires six channels with avatars, online states and unread badges. Six-row synthetic directory prepared; presence/typing/read receipt needs authorized server/device E2E | **Native code covered; final visual pending** |
| 8. Moderation / Earn | Moderator authorization, pending queue, Approve/Reject, reports and real server-side credit receipt paths retained; QA media comes from bundled BIL assets | Reference has compact multi-post cards and Earned/Reviewed tabs; current native presentation is longer and shows Hidden/Reports sections. **Do not fake a complete Earned/Reviewed ledger**. Three-row pending fixture prepared; needs matching authoritative backend data | **Functional UI captured; reference parity open** |
| AI Coach right workspace | Native Chat/Insights/Plan/Progress/Tools, macro cards, focus, 4 actions, photo meal banner and timeline all rendered | The approved concept also contains a distinct left conversational pane with food confirmation, daily log readback, correction and undo. Separate flow receipts and comparable fixtures needed; no fake committed rows | **Workspace capture passed; full two-pane/receipt E2E open** |

## Mandatory integrity and next execution

1. A **single exact final SHA** must pass original `flutter-checks`, 4 `portable-regression` partitions, isolated PostgreSQL-17 SQL contracts, `flutter-visual-capture`, full native candidate, and Community R5. No skipped or softened assertions.
2. Preserve original approved references (hashes above), owner content **private**. The third-party `IMG_9637`–`IMG_9782` series is a separate inspiration set; never substitute it for BIL approvals or edit Dashboard.
3. Per-surface cross-compare **same viewport + theme + language + text scale + media + state**. Record difference and test evidence per row. An independently calculated parity metric is not yet authorized by comparable captures. Keep `native_visual_parity_verified=false`.
4. Backend readback/correction/undo, publish/moderation/receipt, premium signed entitlements, restore/offline retry, full account isolation must be verified with authorized test account, not inferred from synthetic fixtures.
5. Google Play `versionCode 32` remains rejected; future reviewer-access/device test and authorized **new** store build/submission are specifically outside this QA-only scope. Do not mark store-compliance closed.
6. Scope freeze: only `qa/coach-community-next-20261005`; do **not** touch `main`, Production Supabase, store builds, prices/Trial, or Dashboard visual files.

Related [QA issue #8](https://github.com/bilhealth-admin/Body-Intelligence/issues/8), [visual capture 37812679789](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37812679789), [integration run 37812680250](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/37812680250).