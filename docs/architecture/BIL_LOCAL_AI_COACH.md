# BIL Local AI Coach

## Release architecture

- Model: `Qwen3-4B-Q4_K_M.gguf` (Apache-2.0).
- Runtime: official `llama.cpp` `llama-server`.
- Required model SHA-256:
  `7485FE6F11AF29433BC51CAB58009521F205840F5B4AE3A32FA7F92E8534FDF5`.
- Desktop development endpoint: `http://127.0.0.1:18080`.
- Authentication: a private `BIL_LOCAL_AI_API_KEY` of at least 32 characters is
  mandatory for both `llama-server` and the Flutter build.
- No OpenAI dependency, key, or paid request.
- The language model explains and selects from an allow-list. It never writes
  directly to Drift and never calculates health values itself.

## Data path

1. `CoachContextSnapshot` reads the complete local weight, meal, nutrient,
   water, and measurement history.
2. `CoachHealthTools` uses BIL's deterministic BMR/TDEE engines and emits
   screening values with an explicit non-diagnostic notice.
3. `LlamaCppLocalGateway` sends the snapshot only to the configured local
   engine and requests a JSON-only response.
4. `ModelBackedLocalCoachApi` validates the returned action against a closed
   allow-list and validates numeric ranges.
5. `IntelligenceCenterPage` asks for confirmation before every write or
   sensitive operation. Account deletion remains behind the existing second
   confirmation in the account screen.

## Fast navigation

Navigation and common logging commands are parsed deterministically before an
LLM call. They therefore do not depend on model latency and can complete in
under one second on a warm UI.

## Mobile deployment boundary

The Windows loopback server is for development and private desktop use. It is
not reachable from a physical Android or iPhone. Production mobile delivery
must use one of these audited options:

1. an on-device native `llama.cpp` library with a separately downloaded model;
2. a private authenticated BIL inference service with TLS, consent, deletion,
   rate limiting, and data-retention controls.

The app must never bind the development server to `0.0.0.0` or send full health
context to an unauthenticated LAN endpoint.

## Start command

Set `BIL_LOCAL_AI_API_KEY`, run
`artifacts/release/run_bil_local_ai.ps1`, then launch Flutter with:

`--dart-define=BIL_LOCAL_AI_URL=http://127.0.0.1:18080 --dart-define=BIL_LOCAL_AI_API_KEY=<same-private-key>`
