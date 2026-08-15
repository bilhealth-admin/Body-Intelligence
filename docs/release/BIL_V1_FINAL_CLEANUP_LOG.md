# BIL v1 final cleanup log

Cleanup started 2026-08-05 from protection commit
`e9df20573eea4706d045f98db3c9fa6ebcba0b57`.

| Classification | Action | Reason | Recovery |
|---|---|---|---|
| Root test/log outputs | Delete | Reproducible transient output; superseded by final gate evidence | Git history where tracked; regenerate otherwise |
| Root TODO/package/execution notes | Retain with retired banners | Safety review required preserving traceability; each explicitly points to the final constitution | Git history |
| Phase/BDAR constitutions and historical execution matrices | Retain with retired banners | Active traceability tests still reference them; each now defers to `docs/BIL_V1_FINAL_RELEASE_CONSTITUTION.md` | Git history |
| Epic 1–14 generated gate logs/scripts | Known local historical evidence, excluded from release commit | A safety review rejected bulk removal because it could break traceability; they are reproducible and not release authority | Historical commits |
| Epic 15 baseline summary | Retain until final gate | Required to establish the accepted store-assets baseline | Final gate evidence |
| Epic 16 logs, hashes, summary | Retain | Required final release evidence | Regenerate with final gate |
| 177 visual originals, coverage CSV, manifest, HTML | Retain | Required traceability and owner review | Source archive plus protection history |
| Final production/test Goldens | Retain | Release visual regression evidence | Git history |
| `build/` and `.dart_tool/` | Remove after evidence capture | Reproducible cache/output; final AAB hash is retained separately | Rebuild from clean checkout |
| Licensed/generated professional media | Retain | Production content with provenance and rights records | Git history |

No credential, keystore, database, migration, Edge Function, production asset,
privacy manifest, entitlement, or final test evidence is authorized for cleanup.
