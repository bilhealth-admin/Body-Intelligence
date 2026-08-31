# App Store product-review goldens

These files are internal App Store review screenshots, not public product-page
screenshots. They are rendered from the current production Plans widget at an
accepted `1170×2532` iPhone size with product-specific verified test metadata.

Regenerate only with:

```powershell
flutter test test/features/commerce/apple_review_product_screenshot_test.dart --update-goldens
```

The test must keep monthly and annual selections distinct and must not invent
an AI Boost discount without complete store-supplied offer metadata.

Truthful storefront states in this pack:

- Premium monthly: `EGP 129.99`, Monthly selected, Egypt storefront. Premium
  is not available in the USA.
- Premium annual: `EGP 999.99`, Annual selected, Egypt storefront, `Save 36%`
  derived from `EGP 129.99 × 12`.
- Premium + AI Coach monthly: `$5.99`, Monthly selected.
- Premium + AI Coach annual: `$49.99`, Annual selected, `Save 30%` versus
  `$71.88`.
- AI Boost: `$2.49`, one-time 2,500-token product selected, no synthetic
  discount.

After regenerating, create the opaque RGB upload package with:

```powershell
dart run tool/apple_store_connect/package_app_review_goldens.dart
```
