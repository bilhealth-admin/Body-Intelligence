import 'commerce_plan.dart';
import 'store_catalog_configuration.dart';

/// Billing-only metadata from the operating-system store API. Never use this
/// as a customer profile, locale, advertising signal, or durable preference.
abstract final class StorefrontMarketPolicy {
  static const policyVersion = '2026-09-05-v4';
  static const premiumCountries = {'EG', 'NG', 'PK', 'TR'};
  static const heldCountries = {'BY', 'CN', 'RU'};
  // Alpha3/alpha2 pairs in the approved v4 migration have matching order.
  static const _alpha3To2 = <String, String>{
    'ARE': 'AE',
    'AFG': 'AF',
    'ATG': 'AG',
    'AIA': 'AI',
    'ALB': 'AL',
    'ARM': 'AM',
    'AGO': 'AO',
    'ARG': 'AR',
    'AUT': 'AT',
    'AUS': 'AU',
    'AZE': 'AZ',
    'BIH': 'BA',
    'BRB': 'BB',
    'BEL': 'BE',
    'BFA': 'BF',
    'BGR': 'BG',
    'BHR': 'BH',
    'BEN': 'BJ',
    'BMU': 'BM',
    'BRN': 'BN',
    'BOL': 'BO',
    'BRA': 'BR',
    'BHS': 'BS',
    'BTN': 'BT',
    'BWA': 'BW',
    'BLZ': 'BZ',
    'CAN': 'CA',
    'COD': 'CD',
    'COG': 'CG',
    'CHE': 'CH',
    'CIV': 'CI',
    'CHL': 'CL',
    'CMR': 'CM',
    'COL': 'CO',
    'CRI': 'CR',
    'CPV': 'CV',
    'CYP': 'CY',
    'CZE': 'CZ',
    'DEU': 'DE',
    'DNK': 'DK',
    'DMA': 'DM',
    'DOM': 'DO',
    'DZA': 'DZ',
    'ECU': 'EC',
    'EST': 'EE',
    'ESP': 'ES',
    'FIN': 'FI',
    'FJI': 'FJ',
    'FSM': 'FM',
    'FRA': 'FR',
    'GAB': 'GA',
    'GBR': 'GB',
    'GRD': 'GD',
    'GEO': 'GE',
    'GHA': 'GH',
    'GMB': 'GM',
    'GRC': 'GR',
    'GTM': 'GT',
    'GNB': 'GW',
    'GUY': 'GY',
    'HKG': 'HK',
    'HND': 'HN',
    'HRV': 'HR',
    'HUN': 'HU',
    'IDN': 'ID',
    'IRL': 'IE',
    'ISR': 'IL',
    'IND': 'IN',
    'IRQ': 'IQ',
    'ISL': 'IS',
    'ITA': 'IT',
    'JAM': 'JM',
    'JOR': 'JO',
    'JPN': 'JP',
    'KEN': 'KE',
    'KGZ': 'KG',
    'KHM': 'KH',
    'KNA': 'KN',
    'KOR': 'KR',
    'KWT': 'KW',
    'CYM': 'KY',
    'KAZ': 'KZ',
    'LAO': 'LA',
    'LBN': 'LB',
    'LCA': 'LC',
    'LKA': 'LK',
    'LBR': 'LR',
    'LTU': 'LT',
    'LUX': 'LU',
    'LVA': 'LV',
    'LBY': 'LY',
    'MAR': 'MA',
    'MDA': 'MD',
    'MNE': 'ME',
    'MDG': 'MG',
    'MKD': 'MK',
    'MLI': 'ML',
    'MMR': 'MM',
    'MNG': 'MN',
    'MAC': 'MO',
    'MRT': 'MR',
    'MSR': 'MS',
    'MLT': 'MT',
    'MUS': 'MU',
    'MDV': 'MV',
    'MWI': 'MW',
    'MEX': 'MX',
    'MYS': 'MY',
    'MOZ': 'MZ',
    'NAM': 'NA',
    'NER': 'NE',
    'NIC': 'NI',
    'NLD': 'NL',
    'NOR': 'NO',
    'NPL': 'NP',
    'NRU': 'NR',
    'NZL': 'NZ',
    'OMN': 'OM',
    'PAN': 'PA',
    'PER': 'PE',
    'PNG': 'PG',
    'PHL': 'PH',
    'POL': 'PL',
    'PRT': 'PT',
    'PLW': 'PW',
    'PRY': 'PY',
    'QAT': 'QA',
    'ROU': 'RO',
    'SRB': 'RS',
    'RWA': 'RW',
    'SAU': 'SA',
    'SLB': 'SB',
    'SYC': 'SC',
    'SWE': 'SE',
    'SGP': 'SG',
    'SVN': 'SI',
    'SVK': 'SK',
    'SLE': 'SL',
    'SEN': 'SN',
    'SUR': 'SR',
    'STP': 'ST',
    'SLV': 'SV',
    'SWZ': 'SZ',
    'TCA': 'TC',
    'TCD': 'TD',
    'THA': 'TH',
    'TJK': 'TJ',
    'TKM': 'TM',
    'TUN': 'TN',
    'TON': 'TO',
    'TTO': 'TT',
    'TWN': 'TW',
    'TZA': 'TZ',
    'UKR': 'UA',
    'UGA': 'UG',
    'USA': 'US',
    'URY': 'UY',
    'UZB': 'UZ',
    'VCT': 'VC',
    'VEN': 'VE',
    'VGB': 'VG',
    'VNM': 'VN',
    'VUT': 'VU',
    'XKS': 'XK',
    'YEM': 'YE',
    'ZAF': 'ZA',
    'ZMB': 'ZM',
    'ZWE': 'ZW',
    'EGY': 'EG',
    'NGA': 'NG',
    'PAK': 'PK',
    'TUR': 'TR',
    'BLR': 'BY',
    'CHN': 'CN',
    'RUS': 'RU',
  };
  static final Set<String> saleCountries = Set.unmodifiable(
    _alpha3To2.values.toSet().difference(heldCountries),
  );

  /// Unknown is not silently promoted to an AI market.
  static String? normalizeCountry(String? raw) {
    final value = raw?.trim().toUpperCase();
    if (value == null || value.isEmpty) return null;
    if (saleCountries.contains(value) || heldCountries.contains(value)) {
      return value;
    }
    return _alpha3To2[value];
  }

  static CommercePlan? planForCountry(String? raw) {
    final country = normalizeCountry(raw);
    if (country == null || heldCountries.contains(country)) return null;
    return premiumCountries.contains(country)
        ? CommercePlan.premium
        : CommercePlan.premiumAiCoach;
  }

  static bool isHeld(String? raw) =>
      heldCountries.contains(normalizeCountry(raw));

  static bool allowsProduct(String id, String? country) {
    if (id == StoreCatalogConfiguration.aiBoost) return true;
    final plan = StoreCatalogConfiguration.bindingForProduct(id)?.plan;
    if (plan == null) return false;
    if (isHeld(country)) return false;
    final target = planForCountry(country);
    return target == null || plan == target;
  }

  static Set<String> productIds(Set<String> ids, String? country) =>
      ids.where((id) => allowsProduct(id, country)).toSet();
}
