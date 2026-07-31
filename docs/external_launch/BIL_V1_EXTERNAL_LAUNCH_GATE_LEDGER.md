# BIL v1 External Launch Gate Ledger

## Authority

- Program: `BIL V1 External Launch Gates`
- Repository closure HEAD: `113ef663f28c0e55f80d07a79cb6fbde52875036`
- Product version: `1.0.0+1`
- Repository launch readiness: `COMPLETE`
- Global production launch: `NOT COMPLETE`

Only evidence may advance a gate. A plan, draft, local repository file, verbal
confirmation, or successful debug build is not completion evidence for an
external gate.

## Status vocabulary

- `COMPLETE` — required evidence exists and was reviewed.
- `READY` — prerequisites are complete and execution may begin.
- `BLOCKED_EXTERNAL` — requires an account, payment, legal acceptance, identity,
  device, macOS/Xcode, signing material, or final publication authority.
- `PENDING_DEPENDENCY` — an earlier gate is incomplete.
- `NOT_STARTED` — authorized but not yet prepared.

## Ordered gates

| Order | Gate | Depends on | Current status | Completion evidence |
| ---: | --- | --- | --- | --- |
| 0 | Repository launch closure | — | `COMPLETE` | HEAD `113ef663f28c0e55f80d07a79cb6fbde52875036` |
| 1 | Release artifact provenance | Gate 0 | `READY` | Verified AAB path, byte size, SHA-256, version, source HEAD, UTC timestamp |
| 2 | Legal identity and developer-account authority | Gate 1 | `BLOCKED_EXTERNAL` | Legal owner identity plus active Google Play and Apple Developer authority |
| 3 | Privacy-policy legal approval and public HTTPS publication | Gate 2 | `PENDING_DEPENDENCY` | Approved final text and publicly reachable stable URL |
| 4 | Android production signing and Play App Signing custody | Gates 1–2 | `PENDING_DEPENDENCY` | Keystore/upload-key custody evidence without committing secrets |
| 5 | Apple archive, distribution signing, and provisioning | Gates 1–2 | `PENDING_DEPENDENCY` | macOS/Xcode archive and valid distribution-signing evidence |
| 6 | Representative physical-device certification | Gates 4–5 | `PENDING_DEPENDENCY` | Executed Android/iOS device matrix with pass/fail evidence |
| 7 | Store metadata, privacy, health, rating, and listing declarations | Gates 2–6 | `PENDING_DEPENDENCY` | Saved console declarations and final listing evidence |
| 8 | Final store submission and review | Gate 7 | `PENDING_DEPENDENCY` | Submission identifiers and store review state |
| 9 | Staged production rollout | Gate 8 | `PENDING_DEPENDENCY` | Approved release plus rollout configuration |
| 10 | Monitoring, incident response, and rollback readiness | Gate 9 | `PENDING_DEPENDENCY` | Live telemetry review, owner rota, incident and rollback evidence |

## Dependency policy

Android and Apple execution may proceed in parallel only after Gate 2. Legal
publication may also proceed after Gate 2, but all three paths must converge
before store declarations and device certification can be accepted. No store
submission may precede production-signing evidence, physical-device evidence,
and a public privacy-policy URL.

## Product invariants

Every external action must preserve Privacy First, Offline First, Truth Engine,
Body Twin, One Best Action, and Explainable Intelligence. No console declaration
may claim data collection, medical capability, certification, or network
behavior that is inconsistent with the accepted repository evidence.

## Current executive decision

`BIL-V1-EXTERNAL-LAUNCH-001` is the active package. It may advance Gate 1 only.
It cannot advance Gate 2 or any later gate.
