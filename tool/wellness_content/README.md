# BIL wellness content pipeline

Recipe and workout media ship as optional verified downloads rather than in
the store binary. This keeps the app small and permits regional updates.

The current workout release is a registry of two separately approved packs:

- `bil-workouts-home-v1`: 200 Home Training movement videos.
- `bil-workouts-gym-six-month-v1`: 102 Gym / bodybuilding movement videos.

Together they contain 302 bundle-scoped logical records and 301 unique media
payloads. Ninety-four asset names intentionally occur in both packs and one
payload SHA-256 is intentionally shared. The app therefore keys identity by
`<bundleId>:<assetId>`, never by the asset name alone.

`artifacts/workout_media/workout_release_bundle_registry_v1.json` pins each
bundle manifest and owner-approval artifact by SHA-256. Every remote schema-v2
pack must exactly match its own registered IDs, object paths, SHA-256 values,
byte lengths, durations and H.264 delivery evidence. The two compatibility
derivatives retain non-destructive source lineage; their MPEG-4 originals are
preserved outside the app.

The publisher rejects missing rights metadata, non-HTTPS media, duplicate
IDs, and malformed recipes/workouts. Popularity or user votes never imply
verification.

```powershell
python .\tool\wellness_content\publish_wellness_catalog.py --config <config.json> --output <manifest.json>
```

Upload the packs and manifest to your CDN, then pass
`--dart-define=BIL_WELLNESS_MANIFEST_URL=<manifest-url>` when building.

No MP4 file belongs in Flutter assets or the APK/AAB. Only the small registry,
manifests, and owner-approval records are Flutter assets. Publishing remains
blocked until the owner selects an authorized HTTPS storage/CDN destination;
the publisher only creates hash-verified catalog metadata and never uploads.
