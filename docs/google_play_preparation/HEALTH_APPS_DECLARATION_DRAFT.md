# Google Play Health Apps Declaration — Verified Repository Draft

**Status: repository evidence only. Do not submit unchanged. Final selections
require Product Owner and legal approval in Play Console.**

## Applicable product categories

- Nutrition and weight management.
- Activity and fitness tracking.
- Connected-health aggregation from Health Connect and paired fitness devices
  (a product capability, not an asserted Play category name).
- Wellness coaching and user-visible insights based on user-authorized evidence.

The Android remediation source dated 2026-09-16 restricts Health Connect to
**read-only steps, distance and active calories burned**, for the activity
dashboard. Initial history is limited to the ordinary 30-day window. No extended
history, background-read or write permissions are requested. BodyFat,
RestingHeartRate and SleepSession (named in the version-code-13 rejection), and
all other Health Connect types outside these three, are removed from both the
manifest and native runtime. The Android export action is unavailable.

This intentionally removes Health Connect imports for sleep, body composition,
vitals, nutrition and weight for this release. Local/manual records are not
deleted, and the Apple Health scope is unchanged. Existing out-of-scope imports
are hidden from the Android connection-status projection, not deleted from
the user's underlying local history. Paired BLE imports remain limited to weight, body
composition, and heart rate from compatible external fitness devices; BLE data
is not a Health Connect permission.

## Product representation

BIL's current user-facing claims describe general-wellness tracking and insights,
state that the app is not a medical device, and state that it does not diagnose,
treat, cure, or prevent a medical condition. The owner limited this Android
release to compatible external fitness devices. BLE discovery, restore/connect,
parsing, policy, and display allow only the standard weight-scale (`181D`), body-
composition (`181B`), and heart-rate (`180D`) profiles. Every other BLE profile
is excluded from the product paths by a positive allow-list. On that code, device, purpose, and claims
boundary, **Medical Device Apps is not applicable to this release**. Re-evaluate
before submission if the final signed AAB or intended devices/claims expand.

BIL does not replace qualified healthcare advice or emergency care. User-facing
health recommendations must remain evidence-gated, explainable, and capable of
abstaining when trusted evidence is insufficient.

## Submission gate

Before submission:

1. Map every requested permission to a visible core feature and current bridge
   capability.
2. Verify prominent disclosure and consent immediately before permissions where
   policy requires it.
3. Confirm the public privacy-policy URL and in-app privacy access.
4. Select every applicable Play health category without unsupported diagnosis,
   treatment, or clinical-decision claims. Preserve final-AAB evidence for the
   fitness-only/non-medical boundary used to mark Medical Device Apps not
   applicable.
5. Remove permissions unused by the final signed release.
   In Play Console, remove declarations for all Health Connect types except
   Steps (read), Distance (read) and ActiveCaloriesBurned (read). Do not enable
   writes or history/background access. Verify this exact set again in the
   final merged AAB manifest; the source change alone does not update Console.
6. Complete physical-device tests for permission grant, denial, revocation,
   partial authorization, and deletion behavior.
7. Test weight-scale, body-composition, and heart-rate BLE peripherals and verify
   that unsupported profiles never appear, reconnect, parse, or display.
