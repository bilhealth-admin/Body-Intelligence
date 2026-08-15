# BIL MFP / Dashboard checkpoint — 2026-08-13

## Current verified build

- APK SHA-256: `941D71A9C4CC674F2540E91EFAC14198E525F0CE737E027D843CD51997CABCD2`
- Dashboard: preserved `PremiumDashboardBenchmark` / `_ReferenceDashboardPhone` composition.
- Empty repository state: honest `0` / `—`; no personal fixture values.
- AI Coach: canonical `/intelligence-center`; hydration guidance is in-scope and non-mutating.
- Language: dedicated `/settings/language`, 25 canonical tags; More row uses standard title + chevron with no leading globe.

## Dependency map

| Surface | Source of truth | Route / dependency | Evidence |
|---|---|---|---|
| Dashboard shell | `DashboardPage` / `DashboardGrid` | `/dashboard` | `artifacts/runtime_evidence/dashboard_qa_final_en.*` |
| Preserved phone UI | `PremiumDashboardBenchmark` / `_ReferenceDashboardPhone` | repository-derived inputs | `dashboard_exact_backup_restored_top.*` |
| AI Coach | `IntelligenceCenterPage` / `IntelligenceCenterEngine` | `/intelligence-center` | `dashboard_hydration_superseding.*` |
| More | `SettingsPage` | bottom navigation `/settings` | source and route contracts |
| Language | `LanguageSettingsPage` / app settings repository | `/settings/language` | locale persistence tests |
| Profile summary | `ProfileSummaryPage` | `/profile-summary`; `userProfileProvider`, `displayNameProvider` | read-only audit pending QA verdict |
| Database truth | `body_intelligence.sqlite` | repository providers | `dashboard_qa_final_sidecar.json` |

## Guardrails

- Do not seed/import or overwrite live data.
- Do not touch Dashboard visuals pending independent QA.
- Do not copy owner/reference personal values into product code.
- More/Profile changes require real repository state and current-build functional evidence.
