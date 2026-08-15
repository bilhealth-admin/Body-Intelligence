# BIL v1 Epic 16 release-candidate coverage

The final pre-gate reconciliation is machine-readable at
`docs/release/BIL_EPIC16_FINAL_GAP_AUDIT.json`. It traces each release area
through its production chain, points to behavior evidence, rejects internal
`partial`, `mock`, `disconnected`, and `missing` classifications, and keeps
credential, store-console, device, legal, linguistic, penetration, and human
visual review gates explicitly external and unclaimed.

The final gate proves code, tests, localization, accessibility, security,
rights, store assets, Android signing, AAB integrity, and identifier consistency.
It records rather than disguises external blockers.

- Google Play account: created and paid; identity/address review pending.
- Apple Developer Program: incomplete; manual identity review requested.
- Public legal URLs: content/path ready, publication must be verified externally.
- Store products and real transactions: external sandbox/closed-track proof remains required.
- iOS signed archive and TestFlight: require Apple membership and macOS/cloud signing credentials.
- Android/iOS IDs are currently consistent as `com.kadem.bil`; no rename is authorized.
- Advertising is disabled until explicit consent and reviewed production configuration.
- No publish, upload, push, account creation, identifier mutation, or credential handling is performed by the gate.

An `EPIC16_GATE=PASS` means the repository is a technically verified release
candidate with the declared external gates still open. It does not mean either
store has approved or published the app.
