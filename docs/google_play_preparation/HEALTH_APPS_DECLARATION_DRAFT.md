# Google Play Health Apps Declaration — Verified Repository Draft

**Status: repository evidence only. Do not submit unchanged. Final selections
require Product Owner and legal approval in Play Console.**

## Applicable product categories

- Nutrition and weight management.
- Activity and fitness tracking.
- Health-data aggregation from Health Connect and paired health devices.
- Wellness and decision support based on user-authorized evidence.

The Android v1 production permission surface reads steps, active energy,
exercise sessions, weight, and nutrition from Health Connect. Write permission
is limited to weight and nutrition records explicitly selected by the user for
synchronization. Other measurements shown by BIL can come from explicit manual
entry or separately paired BLE devices; they are not Health Connect permissions
in this release.

## Product representation

BIL is a health tracking and decision-support application. It is not represented
as a medical device and does not diagnose, treat, cure, or prevent a medical
condition. It does not replace qualified healthcare advice or emergency care.
User-facing health recommendations must remain evidence-gated, explainable, and
capable of abstaining when trusted evidence is insufficient.

## Submission gate

Before submission:

1. Map every requested permission to a visible core feature and current bridge
   capability.
2. Verify prominent disclosure and consent immediately before permissions where
   policy requires it.
3. Confirm the public privacy-policy URL and in-app privacy access.
4. Select every applicable Play health category without claiming diagnosis or
   regulated medical-device status.
5. Remove permissions unused by the final signed release.
6. Complete physical-device tests for permission grant, denial, revocation,
   partial authorization, and deletion behavior.
