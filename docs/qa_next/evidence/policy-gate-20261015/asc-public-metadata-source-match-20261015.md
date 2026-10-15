# ASC public metadata — read-only source match, 2026-10-15

Live record: iOS1.0.0 REJECTED, attached build35. Candidate36 is not verified by this readback. Four targeted public ASC GET requests returned200. No review credentials, images, store writes or builds/tests/CI were used.

| ID | Field | Status | Source match | Remaining |
|---|---|---|---|---|
| ASC-M01 | Exact version/build association | PASS | NOT_A_CANDIDATE_BINARY_CHECK | Signed candidate36 identity and runtime remain separate. |
| ASC-M02 | Name/subtitle/keywords/category | PASS | PASS_SOURCE_SCOPE | No medical-device status inferred from category. |
| ASC-M03 | Description: core logging and offline behavior | PASS | PASS_SOURCE_SCOPE | No offline device journey performed here. |
| ASC-M04 | Description: 1,500 recipes | PASS | PASS_STATIC_INVENTORY | Runtime loading/offline playback not verified by inventory alone. |
| ASC-M05 | Description: 300+ workout videos | PASS | PASS_STATIC_INVENTORY | This does not certify every hosted media URL or count unique instructional videos as302. |
| ASC-M06 | In-app Plans workout scope | PASS | PASS_SOURCE_SCOPE | This closes only the source copy and affected Golden regression scope. Signed build 36, live deployed backend, App Privacy and store acceptance remain independent blocked gates. |
| ASC-M07 | Description: 25 languages | PASS | PASS_DECLARED_RELEASE_TARGETS | Only en-US storefront localization currently exists; app locale runtime and accessibility remain separately tested. |
| ASC-M08 | Description: AI recipient and consent | BLOCKED | SOURCE_BOUNDARY_PRESENT_DEPLOYMENT_UNVERIFIED | Need exact deployed provider configuration/terms and signed36 first-use + withdrawal journey. A local recipient fix is not evidence of deployment. |
| ASC-M09 | Description: microphone audio and Gemini | PASS | PASS_IOS_SOURCE_SCOPE | No device/network capture; do not generalize iOS on-device behavior to Android recognition services. |
| ASC-M10 | Description: meal photo separate consent and review | BLOCKED | PASS_SOURCE_ORDER_CHECK | Signed36/network capture + deployed Gemini recipient and confirmed logging journey are not established by this readback. |
| ASC-M11 | Description: Community/friends/private messaging | PASS | PASS_SOURCE_ACCESS_MODEL | Real reviewer access, push destination, moderation response and message isolation require their separate E2E evidence. |
| ASC-M12 | Description: non-medical and promotional text | PASS | PASS_SOURCE_SCOPE | Disclaimer does not itself certify underlying clinical accuracy. |
| ASC-M13 | Support/marketing URLs | PASS | PASS_LIVE_PUBLIC_GET | HTTP + document content checked; no rendered browser or actual support response claim. |
| ASC-M14 | Privacy Policy URL and optional Privacy Choices URL | PASS | PASS_LINK_AND_DOCUMENT_SCOPE | These links do not disclose the actual ASC App Privacy questionnaire answers. |
| ASC-M15 | Terms/EULA and Community Guidelines links | PASS | PASS_DISTINCT_LEGAL_PURPOSES | No new legal certification; links/content read only. |
| ASC-M16 | Age rating and adult eligibility | PASS | PASS_CONFIGURATION_SCOPE | Self-declared age and ageAssurance=false are not treated as equivalent to legal age verification; country-specific legal requirements not inferred. |
| ASC-M17 | Age rating content flags | BLOCKED | NO_NEW_STATIC_CONTRADICTION_FOUND | Reconcile advertising flag with final36 artifact/configuration before submission. Do not change questionnaire from source assumptions alone. |
| ASC-M18 | Subscription identifiers and periods | PASS | PASS_SOURCE_BINDINGS | No prices/trials/territories were requested or changed; sandbox purchase/renewal/restore is not proved. |
| ASC-M19 | Subscription display names and public benefit descriptions | PASS | PASS_SOURCE_TIER_RELATIONSHIP | READY_TO_SUBMIT is not review approval; PREPARE_FOR_SUBMISSION localization is not proof of a missing required metadata field. |
| ASC-M20 | AI Boost public localization/type | PASS | PASS_SKU_AND_COPY_SCOPE | Server crediting/idempotency/ownership and real transaction result require separate checks. |
| ASC-M21 | App Privacy four-way reconciliation and latest rejection text | BLOCKED | NO_LIVE_QUESTIONNAIRE_OR_CORRESPONDENCE | Authenticated supported UI/export for exact App Privacy and rejection message, then final artifact/network comparison. Privacy URL or NSPrivacyTracking=false does not close5.1.2(i). |
| ASC-M22 | Screenshots against final candidate | BLOCKED | NOT_REVIEWED_FROM_COUNT | Compare final intended36 screenshot set and actual source/device screens; do not infer from metadata counts. |

Full public text, exact rationale, paths and hashes are in the companion JSON and asc-public-metadata-text-sanitized.json. The original misleading in-app300+home claim was corrected in all25 display locales; focused verification remains root-owned.

Update 2026-10-15T17:06:01.759225+00:00: ASC-M06 is PASS_SOURCE_SCOPE after root verified20/20 copy and affected Golden cases. The complete raw run has36/36 PASS. Raw SHA256: `984c8cb444452c5b8e9d775349ebe11eca2fcc4be542d5ac8bdce014c178ef07`; evidence: `docs/qa_next/evidence/policy-gate-20261015/copy-and-pearl-visual-focused.log`. No signed36, App Privacy, deployment or store approval is certified. Other metadata rows remain unchanged.
