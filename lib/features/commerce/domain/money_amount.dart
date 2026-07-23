final class MoneyAmount {
  const MoneyAmount({
    required this.minorUnits,
    required this.currencyCode,
    required this.currencySymbol,
    this.fractionDigits = 2,
  }) : assert(minorUnits >= 0),
       assert(fractionDigits >= 0 && fractionDigits <= 3);

  final int minorUnits;
  final String currencyCode;
  final String currencySymbol;
  final int fractionDigits;

  double get majorUnits => minorUnits / _factor;
  int get _factor => switch (fractionDigits) {
    0 => 1,
    1 => 10,
    2 => 100,
    3 => 1000,
    _ => 100,
  };

  MoneyAmount discountedByPercent(int percent) {
    if (percent < 0 || percent > 100)
      throw ArgumentError.value(percent, 'percent');
    final discounted = (minorUnits * (100 - percent) / 100).round();
    return MoneyAmount(
      minorUnits: discounted,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      fractionDigits: fractionDigits,
    );
  }
}
