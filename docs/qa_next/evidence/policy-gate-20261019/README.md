# BIL policy reconciliation — 19 October 2026

Decision: **NOT CERTIFIED FOR STORE SUBMISSION**. This review records implementation and evidence, without guaranteeing store acceptance or claiming legal approval. Current store-console access was deferred by the owner.

Official sources:
- [Apple guidelines](https://developer.apple.com/app-store/review/guidelines/): 1.2, 1.4, 2.1, 3.1.1/3.1.2, 4.8 and 5.1.1–5.1.3.
- [Google user data](https://support.google.com/googleplay/android-developer/answer/10144311).
- [Google UGC](https://support.google.com/googleplay/android-developer/answer/9876937).
- [Google AI content](https://support.google.com/googleplay/android-developer/answer/13985936).
- [Google account deletion](https://support.google.com/googleplay/android-developer/answer/13327111).

## Repairs and evidence

| Boundary | Implementation and observation | Remaining evidence |
| --- | --- | --- |
| Meal-photo permission | Owner fencing covers receipt, user choice, save and confirmation. Privacy settings replace stale account data and verify withdrawal. A/B/ABA and actual settings regressions reproduce the old failures and pass after repair. | Exact signed-device journey. |
| Translation | Cancelled or retired owner visits cannot start a request. Privacy now names Google Cloud Translation for community text and food-search phrases/names, across all25 app locales. | Current store data disclosures. |
| Server transport | Google keys use headers, with fixed endpoints and redirect rejection. community-translate v2 and food-search v62 match deployed source. Genuine synthetic Google/USDA requests pass. | External processor terms and operational reliability. |
| UGC safety | Content-specific reporting, blocking, independent moderation and revision checks cover posts/comments/replies/messages/profiles/circles. | Human moderation response and clean-device reviewer access. |
| Circles | New text/images stay pending until independent review. Real hosted multipart PNG is private, immutable and pending. SQL rollback and native PostgreSQL exercise authority, stale revisions and deletion. | Signed-device creation/review journey. |
| Profile consent | Published20261019083913 guard denies public-profile creation before explicit acceptance. Live rollback and genuine API checks pass; synthetic residues are zero. | Old build36 profile-first onboarding must be replaced. No acceptance was fabricated. |
| Public policies | Server-rendered pages work without JavaScript. Deployment6a7dab10-616e-455c-9345-61afad429750 matches37 URLs. New GET-only EPIC15 proof preserves historical evidence and stale-proof rejection. | Publication does not establish legal approval. |
| Cloud ledger | Prior rows and source hashes unchanged;8 added bodies match6 app and2 independent-admin migrations after LF normalization. Ledger233local/248remote passes. | Historical timestamp aliases and dirty source do not prove a signed release. |

## Open submission gates

1. Match current Apple App Privacy, Google Data Safety/health declarations, age questionnaires and reviewer access to the candidate. Historical tracking declarations are not assumed corrected. Browser access is deferred.
2. Complete the stable-source full test cycle and authenticated CI on the final commit. Old HEAD runs do not certify dirty files.
3. Verify exact signed IPA/AAB, SDK privacy manifests, merged permissions and clean-install journeys for consent/withdrawal, deletion, purchases/restoration/refunds and review access.
4. Finalize the independent admin commit and update its workflow pin, preserving existing staged/untracked work.
5. Assess remaining security advisors. Intentional deny-by-default RLS and authenticated definer APIs are not automatically vulnerabilities. Leaked-password protection is currently disabled and is not claimed fixed.

The138-requirement inventory measures required evidence, not138 implementation defects. Artifact, device, Console and operational gaps remain open. No store upload or submission occurred.


## Latest additional observations

All18 active Edge functions were read back. All54 source files for15 mobile functions match the application worktree; all9 source files for3 administration functions match the independent admin worktree, after LF normalization. This is deployment identity evidence, not a runtime assertion for every API.

Google attribution is now explicit for cloud-generated food labels, with full approved badges. Plain domain strings use reviewed or canonical names; cloud names require an attributed surface. Help includes processor information, the required warranty notice and the official link. Five authored store descriptions include the Google Translate attribution; current store-console text remains unverified.

The expanded local cycle initially reported3266 passes and13 failures. Two were stale source expectations; eleven purchase fixtures lacked the launcher's required build define. All56 cases in the corrective rerun passed with the correct setup. These logs are preserved; this is not a stable-source full-suite result. New food attribution, actual FoodPage, small-screen/large-text and Help tests subsequently passed60 cases.


## Image metadata privacy: repaired source, legacy cloud gap remains
Actual failures reproduced GPS/EXIF surviving small-image and resized meal uploads, community validation, profile saving and legacy previews. The candidate strips metadata via fresh pixels, validates real decodable images, corrects orientation and preserves alpha as appropriate. Invalid signature-only positive fixtures were replaced; production no longer accepts them. Circle reservation fingerprints are computed after sanitization, with overlapping requests coalesced. Legacy avatar local replacement uses an atomic preference comparison so a newer selection wins. Focused gates102,105,70 and27 passed (overlapping coverage, do not add).

The fourth full-suite attempt was intentionally interrupted after discovery of this real defect. Its performance prerequisite and shard0 passed; no full result exists. A new frozen-source cycle is required.

Read-only live Storage audit found recognized GPS data in2 of31images, both profile avatars; no read/decode errors. No photo bytes or metadata values were written to evidence. Existing blobs are not repaired by the Dart changes. Automatic approval review rejected the command preparing a remediation utility with “blocked by policy” and no detailed reason; no retry, bypass or photo mutation occurred. Those two existing objects remain an explicit privacy gate.


## R6 full-cycle findings and repair
R6 completed on unchanged files:10179success,5failure,8error,0skip. The13 non-success outcomes comprised four stale source-shape expectations, missing nine Community reporting translations, seven changed visual references and a stale Help row count. Full logs remain preserved. No commit or publication was accepted from R6.

Reporting copy now covers all25locales in a separate bounded catalog; the architecture ceiling remains unchanged. Focused regression and architecture checks39PASS. Eight visual references were inspected individually against the approved Community layout, current legal revision date and required Google Translate Help row. Original PNGs and hashes were preserved. Dialog geometry/copy is unchanged; its translucent interior changes by at most one RGB level with the new backdrop. Pixel matching remains exact. Complete strict visual rerun is separate evidence.

The continuation uses the original tools/qa/bil_owner_full_test_runner.py unsharded root runner after source audits and refreshed analysis. GitHub publication requires all current test files to load, complete and pass on unchanged files. Publication stages into a separate temporary index; the existing179 staged paths and local HEAD stay untouched. A real extra blank EOF line in the SQL QA fixture was removed; temporary-index staging and whitespace preflight passed. None of this constitutes store certification or closes the documented device/Console/legacy-photo gates.

Complete strict actual-production visual suite126PASS after the eight reviewed reference updates. The repaired focused/source/locale/architecture suite39PASS. Neither run used relaxed comparators, skipped tests or updated-golden flags. Final root/CI gates remain pending.
