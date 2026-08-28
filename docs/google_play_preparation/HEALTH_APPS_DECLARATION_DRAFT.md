# Google Play Health Apps Declaration — Verified Repository Draft

**Status: repository evidence only. Do not submit unchanged. Final selections
require Product Owner and legal approval in Play Console.**

## Applicable product categories

- Nutrition and weight management.
- Activity and fitness tracking.
- Connected-health aggregation from Health Connect and paired fitness devices
  (a product capability, not an asserted Play category name).
- Wellness coaching and user-visible insights based on user-authorized evidence.

The Android v1 production permission surface reads steps, active energy,
exercise sessions, sleep sessions, heart rate, resting heart rate, heart-rate
variability, oxygen saturation, weight, and nutrition from Health Connect.
These readings power the user-visible watch, sleep, recovery, and activity
views. Write permission
is limited to weight and nutrition records explicitly selected by the user for
synchronization. Other measurements shown by BIL can come from explicit manual
entry. Paired BLE imports in this release are limited to weight, body
composition, and heart rate from compatible external fitness devices; BLE data
is not a Health Connect permission.

## Product representation

BIL's current user-facing claims describe general-wellness tracking and insights,
state that the app is not a medical device, and state that it does not diagnose,
treat, cure, or prevent a medical condition. The owner limited this Android
release to compatible external fitness devices. BLE discovery, restore/connect,
parsing, policy, and display allow only the standard weight-scale (`181D`), body-
composition (`181B`), and heart-rate (`180D`) profiles. Blood-pressure (`1810`),
glucose (`1808`), pulse-oximetry (`1822`), and thermometer (`1809`) BLE profiles
are excluded from the product paths. On that code, device, purpose, and claims
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
6. Complete physical-device tests for permission grant, denial, revocation,
   partial authorization, and deletion behavior.
7. Test weight-scale, body-composition, and heart-rate BLE peripherals and verify
   that unsupported medical profiles never appear, reconnect, parse, or display.
