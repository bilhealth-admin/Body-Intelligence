# App Store Privacy — Verified Repository Draft

**Status: repository evidence only. Do not submit unchanged.** Final App Store
Connect answers must be reconciled with the archived production binary, Xcode
Privacy Report, enabled build configuration, and every embedded SDK.

## Current local-first release candidate

- Tracking: No.
- Tracking domains: None declared.
- Third-party advertising or attribution: None activated.
- Analytics and crash reporting: None activated.
- Accounts, cloud synchronization, remote AI, commerce, and community: Not
  activated by the current production composition.
- Profile, body measurements, weight, nutrition, meals, hydration, preferences,
  and decision evidence: stored locally on the device.
- HealthKit data: read only after user authorization and processed locally.
- HealthKit writes: limited to explicitly selected weight or hydration records
  after separate write authorization.
- Bluetooth measurements: imported only after user-initiated discovery and
  pairing, then processed locally.
- User export: leaves the app only when the user explicitly invokes the platform
  share sheet and chooses a destination.

Under Apple's definition, data processed only on the device and never sent to
the developer is a candidate for **Data Not Collected**. This is not a final
answer: verify that the signed archive makes no developer-controlled transfer
and review every SDK manifest before selecting it.

Activating Supabase, a server endpoint, remote AI, support, analytics, crash
reporting, notifications, payments, or any other remote service invalidates
this draft and requires a new inventory before submission.
