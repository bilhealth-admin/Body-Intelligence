# BIL rejected brand asset retirement — 2026-09-06

Status: **OWNER DIRECTED / SOURCE TREE CLEANED**

## Controlling owner clarification — later on 2026-09-06

The owner explicitly clarified that **BIL with the green leaf** is the approved
logo and that **the current store logos are correct and must not be changed or
described as wrong**. This clarification supersedes any broader inference made
from the historical local-path retirement below. In particular, a matching
local `feature_graphic.png` retirement row is not authority to reject, remove,
or replace the live Google Play graphic. The proposed store-logo defect was
withdrawn; no store-logo mutation occurred. The table below remains a record of
past local deletions, not a new determination that an owner-approved store
graphic is forbidden. Current source/guard metadata is being reconciled with
this clarification without changing store assets.

The owner rejected the historical blue, cyan, metallic, person/body-network,
abbreviated-BIL, and derived plan/store logo variants. They were removed from
the working tree, from Flutter asset declarations, and from positive store
evidence. This record is recovery provenance only. It must not be used to
override the later explicit approval of current store branding above.

## Current identity authority

- App icon source: `assets/branding/bil_app_icon.png`
  - SHA-256: `f6a183d2fdfb0a27e44c9eedc368cf6437b9e45ca65c4054da75818b092d0b46`
  - Source history: `f29e6294e49c9c93b977035591530360a2d5f906`
- Full wordmark: `BilFullWordmark` in
  `lib/shared/widgets/bil_wordmark.dart` (`BODY INTELLIGENCE LOG™`).
- Full-wordmark splash raster: `assets/branding/bil_splash_identity.png`
  - SHA-256: `ec56f3c02556f0f5a9736f65f3eef2be1b961d497715da788529dde6bc237429`
- Full-wordmark motion: `assets/branding/bil_splash_motion.mp4`
  - SHA-256: `15145a4fc414df7fe59597c0adaa83a94e6f1c54c5ba33b3e61995525884646d`
- iOS 1024 icon derivative:
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
  - SHA-256: `7e9a64e33b371873cc77f60361322a5f2884ef61ec21328390ab8d257c3e6484`
  - Restore history: `955baf101ea8582c14a093b747dc040bb12c7bd0`
- Android xxxhdpi launcher derivative:
  `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
  - SHA-256: `4e7808e467ccfb46975dce6d158a5ede7bbf1f2d4af5ce1b137dbcb13f90e926`

The Android and iOS native full-wordmark splash rasters are byte-identical to
the approved Flutter full-wordmark splash raster above.

## Removed tracked files and Git blobs

All files were tracked at base commit
`21f16767fad82d625ced9b6da2146b66b4b27953` before deletion. A maintainer can
recover a rejected file for forensic comparison with `git show
21f16767fad82d625ced9b6da2146b66b4b27953:<path>`; it must not be restored to
the release tree.

| Rejected path | Git blob |
|---|---|
| `assets/branding/bil_icon_master.png` | `b94a0cbb930c656d8ea2173725bd2f7057aafe5c` |
| `assets/branding/bil_splash_wordmark.png` | `b79ee10687633238a117e7e86382f7a429655306` |
| `assets/branding/bil_wordmark_registered_blue.svg` | `3b5220732fcb3220d496b092715b1d598c1bb67e` |
| `assets/branding/bil_wordmark_registered_white.svg` | `b8b245eac25156fb4964865607fda22cc5e54847` |
| `assets/images/branding/bil_logo_registered_v8.webp` | `a7d7e9e33a9522c6a1bab21147a1df8430e978ca` |
| `assets/images/branding/bil_logo_silver_v10.webp` | `516475d844bcd4dce298e484999081ea3fef3f19` |
| `assets/images/v9/v9_logo_registered.webp` | `a7d7e9e33a9522c6a1bab21147a1df8430e978ca` |
| `artifacts/brand/bil_launch_badge.svg` | `890dde52f6e2c40b0ec29454d54c19ab401ef223` |
| `artifacts/brand/bil_splash_preview_1080x2400.png` | `45ca6c70457610fbf560f0216eacf833176c58a9` |
| `store_assets/graphics/brand/bil_emblem_master.png` | `d53317224e3cf726382ec5f270f3499423a7e7a6` |
| `store_assets/graphics/brand/bil_horizontal_dark.png` | `1acea0644873b1c48b7eb8dfa0a7dc4a1d2201fe` |
| `store_assets/graphics/brand/bil_horizontal_light.png` | `ee82f2bc156665c81872713130f854519ae1f702` |
| `store_assets/graphics/google_play/feature_graphic.png` | `cc524b89f6e7f01c29c3823b82584ed52dcc8cc6` |
| `store_assets/graphics/plans/free.png` | `9ca3630bdd34edee7d79279aee57c9c261d62210` |
| `store_assets/graphics/plans/plus.png` | `18112b48e4cd1a1cd95e5c394b9209183e3236f2` |
| `store_assets/graphics/plans/pro.png` | `3b7eec058794154ac23f7a401e0e5918a9fe9fe0` |
| `store_assets/source/BIL-Brand-Assets-v1/01-bil-app-icon.png` | `b209e00e17c1c209516be73128dc325a0395e0ff` |
| `store_assets/source/BIL-Brand-Assets-v1/02-bil-splash.png` | `a69438789171944c6b21f1b701d8666f7bf4008d` |
| `store_assets/source/BIL-Brand-Assets-v1/03-bil-horizontal-logo.png` | `b5e5d7708cf785945c8fa2629974ed06415298ee` |
| `store_assets/source/BIL-Brand-Assets-v1/04-bil-onboarding-hero.png` | `9d55d44c92d9a450bb52fb4386e0811256b7b6c4` |
| `store_assets/source/BIL-Brand-Assets-v1/05-bil-store-feature-graphic.png` | `1fc3394b59db2d397f90aae433eb3dce20d6bbfe` |
| `store_assets/source/BIL-Brand-Assets-v1/06-bil-free-plus-pro.png` | `08c48c572cc09b4b660bc6e59726976a738a9c30` |

## Enforcement

- `test/release_metadata_test.dart` pins the approved app-icon SHA-256 and
  asserts every rejected path is absent.
- `tool/epic15_store_asset_audit.dart` enforces the same identity authority,
  the full wordmark contract, retired archive status, and rejected-path
  absence.
- `store_assets/evidence/*` no longer presents rejected graphics as approved
  evidence or renders them in its preview index.
