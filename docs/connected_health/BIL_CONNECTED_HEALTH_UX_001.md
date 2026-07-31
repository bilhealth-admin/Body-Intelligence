# BIL-CONNECTED-HEALTH-UX-001-R4

Adds one independent Connected Health dashboard card and one management page.

## Boundaries

- Personal Health AI remains unchanged.
- Existing `PremiumSurface` and `DashboardCarousel` behavior is reused.
- Apple Health and Health Connect are read only after explicit native permission.
- Synchronization remains local-first and stores only a compact UI snapshot with provenance.
- Unsupported desktop and web platforms report an honest unavailable state.
- Cloud, analytics, billing, and external accounts remain disabled.
