# BIL Store Privacy and Health Evidence Boundary

## Accepted parent

- Branch: `phase-3-product-excellence`
- Parent HEAD: `70280d05eedad635be1c427c41ffaad18337e65c`
- Package: `BIL-V1-LAUNCH-004`

## Code-derived evidence

| Claim | Repository evidence |
| --- | --- |
| Local-first default | `AppEnvironment.useSupabase` defaults to false; external account, sync, AI, commerce, community, and coach capabilities remain unavailable. |
| No activated advertising or telemetry | No advertising, attribution, analytics, or crash-reporting dependency is declared in `pubspec.yaml`. |
| Android health minimization | The manifest requests explicit Health Connect types; writes are limited to weight and hydration. |
| Apple health minimization | HealthKit permission text is localized; production writes are limited to body mass and dietary water. |
| No tracking declaration | The Apple privacy manifest declares tracking false and has no tracking domains. |
| User-directed export | Export uses the platform share surface and requires the user to choose a destination. |
| Local deletion | The local-data lifecycle provides deletion/reset behavior without claiming deletion from external health sources. |
| Non-medical positioning | Onboarding and Settings contain health disclaimers; decision release boundaries require safety and evidence gates. |

## Interpretation boundary

These facts support a local-first store-declaration draft. They do not authorize
selecting **Data Not Collected**, submitting Data Safety, completing a Health
Apps Declaration, or publishing a privacy policy without inspecting the final
signed artifacts and enabled environment.

## External gates

Legal identity and contact, policy approval and HTTPS hosting, final dependency
and network inspection, Apple Xcode Privacy Report, Play Console Data Safety,
Play Health Apps Declaration, App Store Privacy answers, age/target-audience
answers, physical-device consent tests, store review, and rollout remain
external and must be approved by the Product Owner.
