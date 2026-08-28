import 'store_offer_metadata.dart';

/// Store-derived annual value comparison.
///
/// Every amount is calculated from the monthly and annual offers returned by
/// the device store. No app-authored price or discount enters this model.
final class StorePriceComparison {
  const StorePriceComparison({
    required this.twelveMonthlyPaymentsMicros,
    required this.monthlyEquivalentMicros,
    required this.savingsPercent,
  });

  final int twelveMonthlyPaymentsMicros;
  final int monthlyEquivalentMicros;
  final int savingsPercent;

  bool get hasSavings => savingsPercent > 0;

  static StorePriceComparison? forAnnualOffer(
    BilStoreOfferMetadata annual,
    Iterable<BilStoreOfferMetadata> tierOffers,
  ) {
    if (annual.billingPeriodIso8601 != 'P1Y' || annual.priceMicros <= 0) {
      return null;
    }
    BilStoreOfferMetadata? monthly;
    for (final candidate in tierOffers) {
      if (candidate.kind == annual.kind &&
          candidate.billingPeriodIso8601 == 'P1M' &&
          candidate.currencyCode == annual.currencyCode &&
          candidate.priceMicros > 0) {
        monthly = candidate;
        break;
      }
    }
    if (monthly == null) return null;

    final comparisonMicros = monthly.priceMicros * 12;
    final rawSaving = comparisonMicros - annual.priceMicros;
    final savingsPercent = rawSaving <= 0
        ? 0
        : ((rawSaving * 100) / comparisonMicros).round().clamp(0, 100).toInt();
    return StorePriceComparison(
      twelveMonthlyPaymentsMicros: comparisonMicros,
      monthlyEquivalentMicros: (annual.priceMicros / 12).round(),
      savingsPercent: savingsPercent,
    );
  }
}
