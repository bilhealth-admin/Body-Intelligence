# BIL Known Limitations

## AI Platform after BIL-AI-002

- Truth signals are contracts; no production domain engine emits them yet.
- Thresholds are deterministic defaults and are not a medical calibration policy.
- Confidence represents evidence reliability coverage, not medical certainty or statistical probability.
- No Body Twin, Decision Memory, One Best Action, provider, prompt, cloud, UI, or persistence integration exists.
- The engine does not diagnose, prescribe, or mutate health state.


## BIL-AI-002-R1
No new functional limitation. This package is a compilation repair only. Truth assessments remain deterministic, offline, provider-neutral, and non-medical.


## BIL-AI-003 limitations

- Rules are in-memory pure contracts; no persistence or registry is introduced.
- Proposition contexts remain feature-owned and are not connected to Body Twin or Daily Log.
- Rule calibration values are explicit inputs and are not learned or remotely configured.

### BIL-AI-003-R1

No new functional limitation. This package is a constructor-structure correction only; it adds no provider, cloud, UI, medical inference, or persistence behavior.
## BIL-AI-004 limitations

- The bridge does not generate candidates; domain packages must provide them explicitly.
- No One Best Action ranking, Body Twin integration, Decision Memory, AI Coach, prompts, providers, cloud transport, or UI is included.
- Confidence mapping is a deterministic coarse presentation policy and is not medical or probabilistic calibration.
- Uncertain and insufficient assessments always abstain.

## BIL-AI-005 limitations

The trace records rule identity and match provenance only. It does not persist history, rank actions, infer user intent, calibrate medical certainty, call providers, or expose UI. Those capabilities require later explicitly authorized packages.

## Host timing variability
Wall-clock tests can still reflect sustained machine contention. `BIL-QUALITY-002-R1` removes isolated single-sample noise but intentionally fails when the median reaches 500 ms or any sample reaches 1500 ms. It does not replace device profiling or release-mode benchmarking.


## BIL-AI-006 limitations

- Conflict analysis explains signal disagreement but does not decide clinical truth, recommend an action, or replace Truth Engine thresholds.
- No persistence, provider, prompt, cloud, UI, Body Twin, Decision Memory, or One Best Action integration is included.

## Resolved by BIL-AI-006-R1
The original AI-006 regression fixture incorrectly expected `supported` for score `0.300`. R1 aligns the test with the established threshold without altering production.


## BIL-AI-007 limitations

- The report explains one deterministic proposition evaluation only.
- It does not rank actions or create recommendations.
- It has no persistence, provider, prompt, network, cloud, clock, randomness, UI, or medical inference integration.

## BIL-AI-007-R1
Corrected AI-007 test fixtures to provide the required local evidence `source`; production contracts and behavior are unchanged.
