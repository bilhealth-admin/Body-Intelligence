# BIL privacy and store disclosure inventory

This is the source of truth for App Store Connect, Google Play Data Safety and
the public privacy policy. Update it whenever a connector changes.

## Product position

- BIL is a health and nutrition logger, not a medical diagnosis product.
- The default experience is local-first; cloud features are opt-in.
- The Free plan can use the bundled AdMob SDK only for contextual,
  non-personalized ads after adult, region and explicit-consent gates pass.
  Ad requests are restricted to general discovery surfaces; health, nutrition,
  weight, location, profile, search and private-community data are not ad
  targeting inputs. Pro is ad-free.
- AI suggestions require confirmation and never invent measurements.

## Data handled on device

- Profile, age/date of birth, sex, height, location, time zone, units, goals,
  preferences and user-selected profile/progress images.
- Weight, water, meals, nutrients, activity, sleep/context tags, measurements,
  reminders, notes, plans and decision history.
- Explicitly permitted HealthKit, Health Connect, watch or BLE device readings.
- Installed content packs, local settings, integrity metadata and migrations.

## Optional cloud data

- Supabase Auth handles account identifiers and authentication data.
- Sync, community posts, relationships, messages, shared foods and review
  evidence are uploaded only when the user enters the corresponding feature.
- Apple/Google handle card data. BIL verifies transaction identifiers and keeps
  entitlement state; it does not collect payment-card details.
- Meal images leave the device only after explicit action and only when the
  configured vision endpoint is available.

## Permissions

- Camera: barcode, meal, profile and progress capture.
- Photos: user-selected meal, profile and progress images.
- Microphone/speech: explicit voice meal entry.
- Bluetooth: explicit connection to supported devices.
- HealthKit/Health Connect: only categories selected in the system sheet.
- Notifications: reminders scheduled by the user.

## Required controls

- Continue locally without an account and request permissions per feature.
- Export data, remove packs, clear local data and sign out independently.
- Delete account and associated cloud data through a verified backend flow.
- Report/block/moderation controls before public community is enabled.

## Submission gate

- Public privacy, terms, support and deletion URLs are live.
- Apple privacy labels and Play Data Safety match this inventory.
- All production SDKs and required-reason APIs are audited.
- Retention, deletion SLA, moderation and security contacts are approved.
- Marketing never implies diagnosis or unavailable devices/content.
