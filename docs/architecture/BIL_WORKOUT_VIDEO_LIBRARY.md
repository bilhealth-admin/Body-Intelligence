# BIL workout video library

## Product boundary

The 82 screenshots extracted from `مكتبة التمارين.zip` are interaction and
layout references only. They do not grant BIL rights to the depicted people,
videos, copy, brand, or workout catalog. BIL therefore reproduces the useful
information architecture—Explore, My Routines, category carousels, routine
details, movement previews, playback, and confirmed logging—without copying
third-party branding or media.

No unlicensed exercise video may be bundled, advertised, or shown as
available. Until a reviewed catalog is configured, the production UI remains
an honest empty state with a verified-pack action.

## Trusted catalog contract

Workout packs use schema version 2. A pack is rejected unless every declared
category contains at least 100 distinct routines and every routine contains:

- a unique main video and cover with HTTPS URL, MIME type, byte size, and
  SHA-256 digest;
- one or more movement segments, each with its own thumbnail, video,
  instruction, repetitions or duration, and optional rest;
- mobile, paid-product, and offline distribution rights;
- publisher, source, license, author/attribution, zoned review date, and a
  completed safety review;
- duration, category, equipment, difficulty, and localized user-facing copy.

The installer verifies the signed JSON pack size and digest. Video playback is
allowed only after the media cache downloads the exact declared byte count and
verifies SHA-256. Corrupt, duplicated, insecure, unreviewed, or unavailable
media fails closed. Confirming a routine logs only its identity and measured
duration; BIL does not invent calories.

## Licensing decision

A white-label exercise-media provider is required for the requested catalog
size. Procurement must include written rights for Android and iOS, paid and
subscription tiers, CDN streaming, offline caching, five locales or permitted
localization, worldwide territories, model releases, derivative thumbnails,
and continued use after contract termination.

Provider fit was checked against the vendors' official public material on
2026-08-06. This is procurement research, not a license or an inventory audit:

| Candidate | Publicly documented fit | Required BIL adapter / unresolved gate |
|---|---|---|
| [Your Move](https://ymove.app/exercise-api/docs) | Hosted exercise API and video delivery. Its [pricing](https://ymove.app/exercise-api/pricing) distinguishes a non-offline tier from a higher offline-capable tier, and its [terms](https://ymove.app/terms-and-conditions) govern continued access/caching. | Use a server-side provider adapter with expiring URL refresh and cancellation cleanup; do not import its URLs as permanent schema-v2 assets. Contract, taxonomy count, offline tier, and safety review remain external. |
| [Exercise Animatic](https://www.exerciseanimatic.com/license) | Public license language covers commercial mobile applications and paid subscriptions while prohibiting raw standalone redistribution. | A purchased asset export can fit the checksum pack after legal review, per-file taxonomy mapping, safety review, and proof that the selected package reaches each required category count. |
| [Vital Animations](https://vitalanimations.com/) | Downloadable animation library with commercial-use positioning and structured metadata. | A purchased raw-asset license is the closest fit for the static offline pack, subject to the actual license version, non-redistribution controls, category-count audit, localization, and safety review. |
| [Funxtion](https://docs.funxtion.com/) | Exercise content delivered through an API/SDK product. | Requires a quoted commercial contract and a live adapter or contractually permitted export. Exact category counts, offline rights, and supported locales must be proven from the contracted dataset. |

No candidate is selected, paid for, configured, or represented as available in
the production app. Public headline totals cannot prove the requested minimum
of 100 distinct, reviewed videos in every BIL workout type.

Free stock aggregators are not an approved substitute for hundreds of
instructional videos. Their mass-download and standalone-library restrictions,
plus missing exercise safety review, make them unsuitable without separate
written permission.

## External activation gate

The following must exist before the catalog is declared available:

1. executed media license and model-release evidence;
2. exercise-professional safety approval for every routine and movement;
3. provider manifest transformed to schema v2 and passing the publisher audit;
4. private HTTPS CDN URLs and catalog environment configuration;
5. real Android/iOS playback, offline, removal, and accessibility review.

Until those conditions pass, the code path is ready but the requested
100-videos-per-category content remains externally blocked and unadvertised.
