final class CountryPricingContext {
  const CountryPricingContext({
    required this.deviceCountryCode,
    required this.accountCountryCode,
    required this.storeCountryCode,
  });

  final String? deviceCountryCode;
  final String? accountCountryCode;
  final String? storeCountryCode;

  String? get billingCountryCode =>
      _normalize(storeCountryCode) ?? _normalize(accountCountryCode);

  bool get hasMismatch {
    final values = <String>{
      ?_normalize(deviceCountryCode),
      ?_normalize(accountCountryCode),
      ?_normalize(storeCountryCode),
    };
    return values.length > 1;
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim().toUpperCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
