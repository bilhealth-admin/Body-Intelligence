# BIL39 Coach presentation: actual evidence and remaining boundaries

Status: native component verification passed; full integrated release acceptance remains pending.

## Preserved contracts

The deployed `ai-coach` v131 source returns complete validated JSON. The read-only transport receipt is `BIL39_COACH_TRANSPORT_READ_ONLY_20261025.json`. This presentation change does not add SSE, simulate model token streaming, change prompts, select models, or change the cloud contract. The existing response is rendered with Markdown once received.

The existing composer, main navigation, status copy, status placement and request-state transitions are retained. In particular, **Preparing your reply…** and **Working on your question…** remain the existing strings. Existing structured health cards, confirmation flows and execution receipts remain in the Flutter message surface. An outgoing-message transition uses the composer message's measured rectangle, with a single semantic message and immediate presentation when reduced motion is enabled.

On iOS, `BILCoachMarkdownBridge.swift` hosts `BILCoachMarkdownView.swift` and `BILCoachMarkdownDocument.swift`. The bridge validates per-view generation, bounds, finite height, ownership and ready state. A failed native view falls back to readable Flutter Markdown; the native acceptance observer requires the real platform view and cannot certify that fallback as native success. External links reject unsafe schemes, local/IP destinations, user information and unexpected HTTPS ports. The existing application action dispatcher remains responsible for supported cards and commands.

## Verified native component

The isolated branch `bil39/native-coach-ui-20261025` contains eight presentation/QA files only. Its source is incorporated in the integration worktree; it is not the final integrated candidate.

| Evidence | Result |
| --- | --- |
| Initial component CI at `3a13899c2ed47bf361ccd8775dcae6464b4af89b` | Both native jobs passed; visual inspection nevertheless found clipping of the final Arabic paragraph |
| Corrected component CI at `2aa94a65c8acc4a039198d50971fed93e65f5a87` | Both native jobs passed; source uses the Flutter-owned safe area correctly |
| Foundation parser/direction tests | Five actual XCTest cases per device, including malformed Markdown, headings/lists/table/code, first strong script, and preserving an Arabic paragraph after a table |
| Native rendering | Real iPhone 16 Pro and iPad simulators, Arabic/English × Light/Dark × 1x/2x text: 16 actual PNG captures |
| Bridge SDK compatibility | All three Swift files type-checked against the pinned Flutter framework and iOS 15 target |
| Personal visual review of corrected captures | Both eight-frame review sheets inspected: final Arabic paragraph visible, English code block visible, intentional horizontal table scrolling retained |

CI: [initial run](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/40221969648), [corrected run](https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/40226658015).

Corrected component SHA-256:

- `ios/Runner/BILCoachMarkdownDocument.swift`: `eb4272f95d9c376eda27a3b1289cb94d732c3581ec603b980cecd7845f7df3a8`
- `ios/Runner/BILCoachMarkdownView.swift`: `682665c716f5c47f23dc001427b4343e01602ad00314050f1d821d7f26a86db6`

The component QA uses system font rendering. Production font registration, real Flutter platform-view embedding, keyboard/history behavior and the complete app still require the integrated native jobs and installation of the new IPA. A component CI result is not evidence of final BIL39 QA or TestFlight publication.

## Device-discovered behavior

`BIL39_PHYSICAL38_COACH_STARTERS_20261025.md` records the four starter failures observed on physical Build38. Local BIL39 behavioral tests exercise the real Overview chips, routing policy, engine and context pipeline with a recording gateway; they do not claim live Gemini verification. Navigation proposals cannot auto-run merely because **review** contains **view**. Personal recorded sleep requests no longer take the generic duration-only shortcut.

The strict physical reviewer is independently testing the installed signed **38**. Those observations remain separate from source tests or native component **39** evidence. Sandbox purchase success, restoration and cancellation are separate acceptance outcomes.

Personal inspection of 104 actual local API33 v6 frames found one outgoing draft painting over the header after a long reply moved its row offscreen. New behavioral tests reproduced the viewport defect. The transition now measures its actual render viewport, skips an offscreen destination and clips its paint to the transcript/composer region. It also vanishes if the user scrolls the destination out of view. Eight actual API33 Coach reveal/history cases subsequently passed with per-frame clip assertions; corrected visual captures are being collected separately. This finding is retained rather than treating the earlier native PASS as visual approval.

## Required before internal TestFlight39

1. Freeze the complete integration source and pass final exact-SHA CI, including full Flutter shards, native iOS app integration, Android startup/native tests, security and cloud handler tests.
2. Complete authorized cloud publication with exact source readback and actual live verification before recording the cloud gate.
3. Sign Build39, verify IPA identity, entitlements, configuration and source, then upload only to the existing internal group.
4. Test the installed Build39; keep physical acceptance pending until that actual artifact is installed. Do not submit App Store review.
