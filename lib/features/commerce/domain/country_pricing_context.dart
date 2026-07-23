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
      if (_normalize(deviceCountryCode) case final value?) value,
      if (_normalize(accountCountryCode) case final value?) value,
      if (_normalize(storeCountryCode) case final value?) value,
    };
    return values.length > 1;
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim().toUpperCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
