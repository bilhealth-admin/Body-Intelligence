# BIL Generated Workout Media Policy

Status: **active production policy**. This document defines the minimum
requirements for generated workout media. It does not assert that the video
catalog, its external hosting, or the target volume is complete.

## Adult performer standard

- Every depicted performer must be an unmistakable adult, specified and
  reviewed as age 25 or older.
- Resistance-training media uses an attractive, healthy adult man with a
  realistic, well-conditioned muscular build.
- Home-workout and cardio media uses an exceptionally attractive, healthy adult
  woman with a strong, proportional athletic build. A secure opaque sports bra
  or crop training top with visible midriff and high-waisted leggings is an
  approved professional outfit.
- Clothing must be professional, functional fitness clothing without visible
  third-party branding. Framing must show the joints and contact points needed
  to evaluate the movement.
- Every final outfit carries the approved white `BIL®` wordmark, including its
  small contained registration mark, centered on the chest. It must be composed
  from the real repository white vector asset and tracked with the torso; a
  generated misspelling, malformed registration mark, crop, or floating screen
  watermark is not acceptable.
- Sexualized posing, voyeuristic angles, transparent or excessively revealing
  clothing, exaggerated anatomy, body-objectifying crops, and emphasis on
  breasts, buttocks, or groin are prohibited.
- The performer must be presented as a capable athlete demonstrating movement,
  not as decorative or suggestive content. Generated people must not imitate a
  named or identifiable real person.

## Preview versus instruction

- A **preview** is short, silent promotional motion that helps identify an
  exercise or category. It must be labelled and stored as `preview`; it is not
  an exercise prescription and must not be presented as technique instruction.
- An **instruction video** demonstrates the complete movement, setup, range,
  breathing or pacing cues, common errors, and relevant safety limits. It must
  be labelled and stored as `instruction` and pass the human movement-safety
  review below.
- Animating a still image, parallax, crossfading poses, or AI-interpolating
  frames can qualify only as a preview. It can never be promoted to instruction
  evidence without human review of the actual continuous movement.
- The app and catalog must not imply that a preview is coaching, medical advice,
  rehabilitation guidance, or proof of correct form.

## Synthetic provenance and rights record

Each generated image or video must have an immutable provenance record linked
to its catalog item. At minimum, record:

- `media_kind`: `preview` or `instruction`;
- `synthetic_origin`: `generated`;
- generator provider, model, model version, creation timestamp, and internal
  generation job identifier;
- prompt digest and seed when the provider exposes them, without storing secrets;
- the BIL operator who approved the generation result;
- rights holder, commercial-use authorization, provider terms/version, source
  record, territory, and any attribution or redistribution restriction;
- a declaration that the performer is fictional/synthetic and not a known real
  person, plus the outcome of likeness review;
- the final file name, MIME type, byte size, SHA-256 digest, duration, dimensions,
  frame rate, locale applicability, performer variant (`male` or `female`),
  exercise/category identifier, and revision;
- safety-review status, reviewer identity, review timestamp, findings, and the
  exact media digest reviewed.

No API key, access token, account credential, recovery code, or private provider
response may be stored in the record, repository, media metadata, or logs.
Missing or ambiguous rights data is fail-closed: the media cannot be published,
downloaded, advertised as available, or included in a store screenshot.

## Mandatory human safety review

Every instruction video and every preview that depicts exercise form requires a
human review before catalog publication. The reviewer must verify:

- adult appearance, nonsexual presentation, anatomical plausibility, and absence
  of warped, duplicated, disappearing, or disconnected limbs/equipment;
- exercise identity, setup, joint alignment, balance, contact points, equipment
  use, continuity, and absence of unsafe or physically impossible motion;
- honest title/category mapping and no invented calorie burn, clinical benefit,
  rehabilitation claim, or unsupported performance promise;
- no third-party marks, copyrighted background media, recognizable person, or
  unlicensed audio; and
- first and last frames, loop boundary, compression, flashes, and motion comfort.

Automated checks, generated thumbnails, contract tests, or a successful render
do not replace this review. Re-encoding or changing any visual frames creates a
new digest and requires review of the new output.

## Catalog target and truthful availability

- The product target is **at least 100 unique, reviewed videos per declared
  workout category**, with meaningful exercise coverage rather than recolors,
  mirrored duplicates, or repeated clips.
- This is currently a target, **not a completed capability claim**. A category
  remains unavailable or visibly incomplete until its manifest contains 100
  distinct, rights-cleared, safety-reviewed video digests.
- Generated previews do not count as instruction videos. Male and female
  variants count as separate media only when they are genuinely distinct and
  independently reviewed, but they do not replace breadth of exercises.
- The UI must fail closed and show an honest unavailable/coming-after-verification
  state when a verified catalog or entitlement is absent.

## Delivery, integrity, and offline behavior

- Production media is delivered only from the approved HTTPS CDN. Provider
  preview URLs and temporary generation URLs must never ship in the app.
- The signed catalog must bind each URL to MIME type, byte size, SHA-256 digest,
  rights/provenance record, access tier, revision, and safety-review status.
- The client must validate the declared size and SHA-256 digest before playback
  or cache promotion. Digest mismatch, unsupported type, expired rights, or
  incomplete review must fail closed and remove the untrusted temporary file.
- Downloads are on demand; installing the catalog must not silently download the
  entire video library. Cache writes must be atomic, deduplicated by digest, and
  bounded by the documented cache policy.
- Offline playback is allowed only for a previously verified cached file whose
  catalog revision and rights status remain valid. Otherwise the app shows the
  truthful offline-unavailable state and never substitutes another exercise.
- Removal of a pack, account-data deletion where applicable, or rights revocation
  must invalidate catalog access and safely purge its cached media.
