import 'package:intl/intl.dart';

/// Locale-aware dynamic values. Static translated copy remains separately
/// human-reviewed; this prevents string concatenation with English units.
class BilLocaleFormatter {
  const BilLocaleFormatter(this.localeTag);

  final String localeTag;

  String get _intlTag => localeTag.replaceAll('-', '_');

  String decimal(num value, {int maximumFractionDigits = 1}) =>
      NumberFormat.decimalPatternDigits(
        locale: _intlTag,
        decimalDigits: maximumFractionDigits,
      ).format(value);

  String percent(num ratio) =>
      NumberFormat.percentPattern(_intlTag).format(ratio);

  String currency(num value, String currencyCode) =>
      NumberFormat.simpleCurrency(
        locale: _intlTag,
        name: currencyCode,
      ).format(value);

  String shortDate(DateTime localDate) =>
      DateFormat.yMMMd(_intlTag).format(localDate);

  String measurement(num value, String unitSymbol) =>
      '${decimal(value)}\u00a0$unitSymbol';
}
