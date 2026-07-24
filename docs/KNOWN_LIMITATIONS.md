# BIL Known Limitations

## Authoritative execution baseline

- Branch: `phase-3-product-excellence`
- Baseline HEAD: `8f67e0effa480e9af0769ec546973ef0644a32f8`

## Current limitations and activation boundaries

### Scientific and product interpretation

- BIL intelligence is evidence-driven and explainable, but it is not a substitute for clinical diagnosis or emergency medical care.
- Confidence describes the quality and coverage of available evidence; it is not absolute medical certainty.
- Missing or stale evidence can reduce confidence or force safe abstention.

### Local logging completeness

- Forecasts and actions depend on factual local measurements and recorded nutrition, hydration, activity, sleep, and decision history when those inputs are required.
- Unlogged intake, supplements, measurements, activity, or symptoms are not invented.
- A supported projected weight or weight-based action requires factual weight-event provenance within the accepted analysis window.

### External Cloud activation

Cloud Platform Core is closed at the provider-neutral production boundary. Hosted operation still requires Product Owner-controlled infrastructure and configuration, including as applicable:

- owned authentication and transport services;
- server-side authorization and row-level security;
- encryption-key custody and secure device storage;
- deployment credentials and environment configuration;
- production monitoring, alerting, backup drills, and disaster recovery;
- platform-specific background execution and physical-device validation.

These are deployment and operational activation boundaries, not unfinished Cloud Core architecture. The application must remain honestly local-only when those external ports are not configured.

### Release readiness

Owned application identifiers, signing material, store records, privacy disclosures, physical-device validation, and current platform-policy review remain required before public release where they are not already completed.

## Closed-stage status

- Foundation — **Closed**
- Nutrition Platform — **Closed**
- AI Platform — **Closed**
- BIL Intelligence Integration — **Closed**
- BIL Intelligence Reality Closure — **Closed**
- Cloud Platform Core — **Closed**

Historical package limitations and delivery-candidate notes are available through Git history and package archives and are not current limitations.
