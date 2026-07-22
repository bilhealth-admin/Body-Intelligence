import 'package:flutter/foundation.dart';

@immutable
class BilCityOption {
  const BilCityOption({
    required this.nameEn,
    required this.nameAr,
    required this.timezone,
  });

  final String nameEn;
  final String nameAr;
  final String timezone;

  String label(bool arabic) => arabic ? nameAr : nameEn;
}

/// Offline-first city suggestions for high-usage markets.
///
/// Country selection itself remains complete through `country_picker`.
/// Users can always enter any city manually, so the catalog never blocks an
/// unsupported city or creates a false claim of global completeness.
const Map<String, List<BilCityOption>> bilCityCatalog = {
  'EG': [
    BilCityOption(nameEn: 'Cairo', nameAr: 'القاهرة', timezone: 'Africa/Cairo'),
    BilCityOption(
      nameEn: 'Alexandria',
      nameAr: 'الإسكندرية',
      timezone: 'Africa/Cairo',
    ),
    BilCityOption(nameEn: 'Giza', nameAr: 'الجيزة', timezone: 'Africa/Cairo'),
    BilCityOption(
      nameEn: 'Mansoura',
      nameAr: 'المنصورة',
      timezone: 'Africa/Cairo',
    ),
    BilCityOption(
      nameEn: 'Hurghada',
      nameAr: 'الغردقة',
      timezone: 'Africa/Cairo',
    ),
    BilCityOption(
      nameEn: 'Sharm El Sheikh',
      nameAr: 'شرم الشيخ',
      timezone: 'Africa/Cairo',
    ),
  ],
  'JO': [
    BilCityOption(nameEn: 'Amman', nameAr: 'عمّان', timezone: 'Asia/Amman'),
    BilCityOption(nameEn: 'Irbid', nameAr: 'إربد', timezone: 'Asia/Amman'),
    BilCityOption(nameEn: 'Zarqa', nameAr: 'الزرقاء', timezone: 'Asia/Amman'),
    BilCityOption(nameEn: 'Aqaba', nameAr: 'العقبة', timezone: 'Asia/Amman'),
  ],
  'SA': [
    BilCityOption(nameEn: 'Riyadh', nameAr: 'الرياض', timezone: 'Asia/Riyadh'),
    BilCityOption(nameEn: 'Jeddah', nameAr: 'جدة', timezone: 'Asia/Riyadh'),
    BilCityOption(nameEn: 'Mecca', nameAr: 'مكة', timezone: 'Asia/Riyadh'),
    BilCityOption(
      nameEn: 'Medina',
      nameAr: 'المدينة المنورة',
      timezone: 'Asia/Riyadh',
    ),
    BilCityOption(nameEn: 'Dammam', nameAr: 'الدمام', timezone: 'Asia/Riyadh'),
  ],
  'AE': [
    BilCityOption(nameEn: 'Dubai', nameAr: 'دبي', timezone: 'Asia/Dubai'),
    BilCityOption(
      nameEn: 'Abu Dhabi',
      nameAr: 'أبوظبي',
      timezone: 'Asia/Dubai',
    ),
    BilCityOption(nameEn: 'Sharjah', nameAr: 'الشارقة', timezone: 'Asia/Dubai'),
    BilCityOption(nameEn: 'Al Ain', nameAr: 'العين', timezone: 'Asia/Dubai'),
  ],
  'KW': [
    BilCityOption(
      nameEn: 'Kuwait City',
      nameAr: 'مدينة الكويت',
      timezone: 'Asia/Kuwait',
    ),
  ],
  'QA': [
    BilCityOption(nameEn: 'Doha', nameAr: 'الدوحة', timezone: 'Asia/Qatar'),
  ],
  'BH': [
    BilCityOption(
      nameEn: 'Manama',
      nameAr: 'المنامة',
      timezone: 'Asia/Bahrain',
    ),
  ],
  'OM': [
    BilCityOption(nameEn: 'Muscat', nameAr: 'مسقط', timezone: 'Asia/Muscat'),
    BilCityOption(nameEn: 'Salalah', nameAr: 'صلالة', timezone: 'Asia/Muscat'),
  ],
  'LB': [
    BilCityOption(nameEn: 'Beirut', nameAr: 'بيروت', timezone: 'Asia/Beirut'),
    BilCityOption(nameEn: 'Tripoli', nameAr: 'طرابلس', timezone: 'Asia/Beirut'),
  ],
  'IQ': [
    BilCityOption(nameEn: 'Baghdad', nameAr: 'بغداد', timezone: 'Asia/Baghdad'),
    BilCityOption(nameEn: 'Basra', nameAr: 'البصرة', timezone: 'Asia/Baghdad'),
    BilCityOption(nameEn: 'Erbil', nameAr: 'أربيل', timezone: 'Asia/Baghdad'),
  ],
  'SY': [
    BilCityOption(
      nameEn: 'Damascus',
      nameAr: 'دمشق',
      timezone: 'Asia/Damascus',
    ),
    BilCityOption(nameEn: 'Aleppo', nameAr: 'حلب', timezone: 'Asia/Damascus'),
  ],
  'PS': [
    BilCityOption(
      nameEn: 'Jerusalem',
      nameAr: 'القدس',
      timezone: 'Asia/Hebron',
    ),
    BilCityOption(
      nameEn: 'Ramallah',
      nameAr: 'رام الله',
      timezone: 'Asia/Hebron',
    ),
    BilCityOption(nameEn: 'Gaza', nameAr: 'غزة', timezone: 'Asia/Gaza'),
  ],
  'TR': [
    BilCityOption(
      nameEn: 'Istanbul',
      nameAr: 'إسطنبول',
      timezone: 'Europe/Istanbul',
    ),
    BilCityOption(
      nameEn: 'Ankara',
      nameAr: 'أنقرة',
      timezone: 'Europe/Istanbul',
    ),
    BilCityOption(
      nameEn: 'Izmir',
      nameAr: 'إزمير',
      timezone: 'Europe/Istanbul',
    ),
    BilCityOption(
      nameEn: 'Antalya',
      nameAr: 'أنطاليا',
      timezone: 'Europe/Istanbul',
    ),
  ],
  'US': [
    BilCityOption(
      nameEn: 'New York',
      nameAr: 'نيويورك',
      timezone: 'America/New_York',
    ),
    BilCityOption(
      nameEn: 'Chicago',
      nameAr: 'شيكاغو',
      timezone: 'America/Chicago',
    ),
    BilCityOption(nameEn: 'Denver', nameAr: 'دنفر', timezone: 'America/Denver'),
    BilCityOption(
      nameEn: 'Los Angeles',
      nameAr: 'لوس أنجلوس',
      timezone: 'America/Los_Angeles',
    ),
  ],
  'CA': [
    BilCityOption(
      nameEn: 'Toronto',
      nameAr: 'تورونتو',
      timezone: 'America/Toronto',
    ),
    BilCityOption(
      nameEn: 'Vancouver',
      nameAr: 'فانكوفر',
      timezone: 'America/Vancouver',
    ),
    BilCityOption(
      nameEn: 'Montreal',
      nameAr: 'مونتريال',
      timezone: 'America/Toronto',
    ),
  ],
  'GB': [
    BilCityOption(nameEn: 'London', nameAr: 'لندن', timezone: 'Europe/London'),
    BilCityOption(
      nameEn: 'Manchester',
      nameAr: 'مانشستر',
      timezone: 'Europe/London',
    ),
  ],
  'DE': [
    BilCityOption(nameEn: 'Berlin', nameAr: 'برلين', timezone: 'Europe/Berlin'),
    BilCityOption(nameEn: 'Munich', nameAr: 'ميونخ', timezone: 'Europe/Berlin'),
  ],
  'FR': [
    BilCityOption(nameEn: 'Paris', nameAr: 'باريس', timezone: 'Europe/Paris'),
    BilCityOption(nameEn: 'Lyon', nameAr: 'ليون', timezone: 'Europe/Paris'),
  ],
  'IT': [
    BilCityOption(nameEn: 'Rome', nameAr: 'روما', timezone: 'Europe/Rome'),
    BilCityOption(nameEn: 'Milan', nameAr: 'ميلانو', timezone: 'Europe/Rome'),
  ],
  'ES': [
    BilCityOption(nameEn: 'Madrid', nameAr: 'مدريد', timezone: 'Europe/Madrid'),
    BilCityOption(
      nameEn: 'Barcelona',
      nameAr: 'برشلونة',
      timezone: 'Europe/Madrid',
    ),
  ],
  'AU': [
    BilCityOption(
      nameEn: 'Sydney',
      nameAr: 'سيدني',
      timezone: 'Australia/Sydney',
    ),
    BilCityOption(
      nameEn: 'Melbourne',
      nameAr: 'ملبورن',
      timezone: 'Australia/Melbourne',
    ),
    BilCityOption(nameEn: 'Perth', nameAr: 'بيرث', timezone: 'Australia/Perth'),
  ],
  'IN': [
    BilCityOption(nameEn: 'Delhi', nameAr: 'دلهي', timezone: 'Asia/Kolkata'),
    BilCityOption(nameEn: 'Mumbai', nameAr: 'مومباي', timezone: 'Asia/Kolkata'),
    BilCityOption(
      nameEn: 'Bengaluru',
      nameAr: 'بنغالور',
      timezone: 'Asia/Kolkata',
    ),
  ],
  'PK': [
    BilCityOption(
      nameEn: 'Islamabad',
      nameAr: 'إسلام آباد',
      timezone: 'Asia/Karachi',
    ),
    BilCityOption(
      nameEn: 'Karachi',
      nameAr: 'كراتشي',
      timezone: 'Asia/Karachi',
    ),
    BilCityOption(nameEn: 'Lahore', nameAr: 'لاهور', timezone: 'Asia/Karachi'),
  ],
  'JP': [
    BilCityOption(nameEn: 'Tokyo', nameAr: 'طوكيو', timezone: 'Asia/Tokyo'),
    BilCityOption(nameEn: 'Osaka', nameAr: 'أوساكا', timezone: 'Asia/Tokyo'),
  ],
};

const List<String> bilTimezoneChoices = [
  'Africa/Cairo',
  'Africa/Casablanca',
  'Africa/Tunis',
  'Africa/Algiers',
  'Asia/Amman',
  'Asia/Riyadh',
  'Asia/Dubai',
  'Asia/Kuwait',
  'Asia/Qatar',
  'Asia/Bahrain',
  'Asia/Muscat',
  'Asia/Beirut',
  'Asia/Baghdad',
  'Asia/Damascus',
  'Asia/Gaza',
  'Asia/Hebron',
  'Europe/Istanbul',
  'Europe/London',
  'Europe/Berlin',
  'Europe/Paris',
  'Europe/Rome',
  'Europe/Madrid',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Toronto',
  'America/Vancouver',
  'Australia/Sydney',
  'Australia/Melbourne',
  'Australia/Perth',
  'Asia/Kolkata',
  'Asia/Karachi',
  'Asia/Tokyo',
  'UTC',
];

String? inferTimezoneFromDeviceName(String name) {
  final normalized = name.trim().toUpperCase();
  const aliases = {
    'EET': 'Africa/Cairo',
    'EEST': 'Africa/Cairo',
    'AST': 'Asia/Riyadh',
    'GST': 'Asia/Dubai',
    'TRT': 'Europe/Istanbul',
    'GMT': 'Europe/London',
    'BST': 'Europe/London',
    'CET': 'Europe/Berlin',
    'CEST': 'Europe/Berlin',
    'EST': 'America/New_York',
    'EDT': 'America/New_York',
    'CST': 'America/Chicago',
    'CDT': 'America/Chicago',
    'MST': 'America/Denver',
    'MDT': 'America/Denver',
    'PST': 'America/Los_Angeles',
    'PDT': 'America/Los_Angeles',
    'IST': 'Asia/Kolkata',
    'JST': 'Asia/Tokyo',
    'UTC': 'UTC',
  };
  return aliases[normalized];
}
