# BIL wellness content pipeline

Recipe and workout media ship as optional verified downloads rather than in
the store binary. This keeps the app small and permits regional updates.

The publisher rejects missing rights metadata, non-HTTPS media, duplicate
IDs, and malformed recipes/workouts. Popularity or user votes never imply
verification.

```powershell
python .\tool\wellness_content\publish_wellness_catalog.py --config <config.json> --output <manifest.json>
```

Upload the packs and manifest to your CDN, then pass
`--dart-define=BIL_WELLNESS_MANIFEST_URL=<manifest-url>` when building.
