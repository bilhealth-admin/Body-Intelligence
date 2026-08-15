# BIL optional food catalogs

The application ships only the compact offline core. Larger regional and
branded catalogs are optional downloads and must never be placed in Flutter
assets.

## Release contract

1. Build each SQLite catalog with `mobile_catalog_builder.py`.
2. Put the catalog descriptions in a private copy of
   `tool/nutrition_platform/catalog_packs.example.json`.
3. Set an HTTPS `base_url` pointing to the final immutable download location.
4. Run `run_catalog_pack_publisher.ps1`.
5. Upload the SQLite files without changing their bytes, then upload the
   generated `manifest.json`.
6. Build Flutter with
   `--dart-define=BIL_CATALOG_MANIFEST_URL=https://.../manifest.json`.

The publisher rejects corrupt SQLite files, unsupported schemas, duplicate
pack identifiers, non-HTTPS download roots, and unknown access levels. The app
then verifies both `size_bytes` and `sha256` before atomically activating a
download. A failed optional pack never disables the bundled core.

Do not place API secrets, storage service keys, or signed private URLs in the
manifest. Public immutable catalog files or a server-issued short-lived URL
flow should be used for production.
