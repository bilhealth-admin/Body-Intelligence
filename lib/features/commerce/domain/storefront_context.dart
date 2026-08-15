enum BilMeasurementSystem { metric, imperial }

/// Non-financial storefront context. Currency and price deliberately remain
/// store-owned and are never inferred from locale or country.
final class BilStorefrontContext {
  const BilStorefrontContext({
    required this.languageTag,
    required this.countryCode,
    required this.measurementSystem,
  });

  final String languageTag;
  final String? countryCode;
  final BilMeasurementSystem measurementSystem;

  static BilStorefrontContext normalize({
    required String languageTag,
    String? countryCode,
    required String unitsPreference,
  }) {
    final normalizedLanguage = languageTag.trim().replaceAll('_', '-');
    final country = countryCode?.trim().toUpperCase();
    return BilStorefrontContext(
      languageTag:
          RegExp(
            r'^[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*$',
          ).hasMatch(normalizedLanguage)
          ? normalizedLanguage
          : 'en',
      countryCode: country != null && RegExp(r'^[A-Z]{2}$').hasMatch(country)
          ? country
          : null,
      measurementSystem: unitsPreference.toLowerCase() == 'imperial'
          ? BilMeasurementSystem.imperial
          : BilMeasurementSystem.metric,
    );
  }
}
