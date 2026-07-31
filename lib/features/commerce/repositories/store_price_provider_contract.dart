import '../domain/commerce_plan.dart';
import '../domain/regional_price.dart';

abstract interface class StorePriceProviderContract {
  Future<RegionalPrice?> fetchVerifiedPrice({
    required CommercePlan plan,
    required String storeCountryCode,
  });
}
