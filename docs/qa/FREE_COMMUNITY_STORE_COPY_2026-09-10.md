# Free Community — website and store copy

## Verified outcome

- Apple: saved and read back the en-US description for app `6805349703`, version
  `7a132506-d5a8-4810-a51f-b2dc2bd636cf`. It explicitly includes Community,
  friends and private messages in BIL Free for signed-in adults. Version state
  remains `DEVELOPER_REJECTED`, release remains `MANUAL`; build, other metadata
  and all four subscription resources/localizations were verified unchanged.
  No review submission or app release occurred.
- Website: published English and Arabic Free Community wording on the home
  page and subscription terms. It explicitly says this arrives with the next
  app update, because installed older binaries still have the old gate.
  Cloudflare version: `680badb1-b14f-4c07-9657-124bc58b6470`.
  Production `/app.js` matches local source exactly. Nine HTTPS routes returned
  200. Existing association documents and seven other public assets were
  preserved byte-for-byte; privacy and Community policy wording was unchanged.
- Google Play: saved and read back subscription benefit wording for
  `bil_premium`, `bil_premium_annual`, `bil_premium_ai_coach`, and
  `bil_premium_ai_coach_annual`. Community is no longer listed as an added paid
  benefit. Only `listings` was patched; full response comparison verified all
  other product fields, including base plans and pricing, unchanged.

## Google main listing — not saved

The new en-GB full description was prepared and validated, but the guarded
commit was rejected with HTTP 400: `Changes are sent for review automatically.
The query parameter changesNotSentForReview must not be set.`
The uncommitted temporary edit was deleted. No release track was written.
The current main description therefore has NOT been updated by this operation.
Do not call the entire store-copy task complete. Removing the no-review guard
would send changes for review and requires a separate decision; it was not done.

## Checks and evidence

- PASS: 12 Node code tests (six bilingual copy tests, six association-worker tests).
- PASS: JavaScript syntax checks, Wrangler dry run, final `git diff --check`.
- PASS: live website source/route/association verification and Apple read-back.
- PASS: four Google subscription PATCH response comparisons.
- FAIL: Google main-listing no-review commit, for the store restriction above.
- NOT RUN: device, simulator, emulator, screenshots, visual QA, mobile build.
- No git commit or push was created for this text-only task.

Private operational evidence (no credential contents):
`G:/BIL_Temp/community-free-copy-20260910/`: `apple-result.json`,
`site-result.json`, four `google-subscription-*.json` results, original store
snapshots and `google-proposal.json` containing the prepared main description.

An earlier user save request was initially interpreted as a backup request;
24 existing changed/untracked files, one deletion record, HEAD/branch and binary
diffs were preserved and verified at
`G:/BIL_Project_Backups/community-free-2026-09-10T09-21-45-946Z`.
The user then clarified that saving in the stores and on the domain was intended.
All pre-existing application changes were left intact.
