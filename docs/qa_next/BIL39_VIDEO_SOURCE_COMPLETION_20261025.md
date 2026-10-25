# BIL39 video source completion — source and isolated local evidence

This branch is based on protected iOS38 `155b079696430919f8272df934371f033fb11be2`. It changes neither that branch nor deployed resources. It is not a TestFlight or release approval.

## Behavior

`/v2/source/workouts/v1/{home|gym-six-month}/movements/<slug>.mp4` serves an English HTML attribution page for a known catalog movement. Metadata is derived from the existing approved runtime packs. It contains the publisher, terms link and synthetic performer disclosure. It contains no player, media bytes, object URL, account data, credentials or entitlement bypass.

Source pages do not read environment bindings. Unknown/traversal paths fail closed. HEAD has no body and Range does not turn this page into a video response. Protected playback remains separately authenticated and entitled.

The application has not been switched to this new endpoint: a successful isolated deployment is required before wiring it as a working source destination.

## Evidence before commit

Node 24.18.0, locked dependencies (`npm ci`). `npm run check` passed. `npm run test:bil39-isolated` passed 67 tests in six files, including all existing protected delivery tests and 18 source-page tests. The source test first reproduced the missing route with HTTP 404 before implementation. These results describe the working tree; CI on a committed SHA is still required.

The local fixture uses separate emulated R2 bindings, synthetic `.invalid` authentication hosts and no routes. `remoteBindings` is explicitly false. The validator checks isolation against the actual production configuration. This is local Workers emulation, not proof of a deployed staging service.

## Critical configuration finding

The existing `wrangler.jsonc` staging environment references production Supabase and R2 resources. It has not been used or deployed. The production configuration is unchanged. A genuinely separate remote staging environment remains required; no production resource may be used to make that check pass.

## Remaining gates

- Preserve and test the narrowly scoped PR16 MP4 MIME defense without merging its older base wholesale.
- CI on the exact resulting source SHA.
- Deploy only to a separately authorized isolated staging environment; verify public English source page and protected anonymous/free/expired/paid playback independently.
- Wire and test the app's safe source-opening action after that proof, including iPhone and iPad.
- Production deployment requires separate approval. No deployed or store readiness is claimed here.
