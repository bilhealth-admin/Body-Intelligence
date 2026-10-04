import 'food_search_normalizer.dart';

/// Search spellings only: these aliases never assert product identity,
/// ingredients, nutrition, a valid barcode, or provider availability.
/// Distinct dishes (for example mansaf/mujaddara) deliberately stay distinct.
class FoodArabicRegionalLexicon {
  const FoodArabicRegionalLexicon._();

  static const Map<String, List<String>> aliases = {
    'kabsa': ['كبسة', 'الكبسة', 'كبسه', 'kabsah'],
    'mandi': ['مندي', 'المندي'],
    'machboos': ['مجبوس', 'مكبوس', 'المجبوس', 'مچبوس', 'majboos', 'makbous'],
    'harees': ['هريس', 'الهريس', 'هريسة قمح', 'harees wheat'],
    'jareesh': ['جريش', 'الجريش', 'جريشة', 'jareesh'],
    'saleeg': ['سليق', 'السليق', 'saleeq'],
    'thareed': ['ثريد', 'الثريد', 'تشريب', 'tashreeb'],
    'balaleet': ['بلاليط', 'البلاليط'],
    'mutabbaq': ['مطبق', 'المطبق'],
    'mansaf': ['منسف', 'المنسف'],
    'maqluba': ['مقلوبة', 'المقلوبة', 'مقلوبه', 'maklouba', 'maqlouba'],
    'musakhan': ['مسخن', 'المسخن', 'مسخّن', 'mosakhan'],
    'mujaddara': ['مجدرة', 'المجدرة', 'مُجَدَّرَة', 'mujadara', 'mejadra'],
    'kibbeh': ['كبة', 'الكبة', 'كبه', 'kibbe', 'kebbeh'],
    'shish barak': ['شيش برك', 'شيشبرك', 'shishbarak'],
    'fattoush': ['فتوش', 'الفتوش', 'fattush'],
    'tabbouleh': ['تبولة', 'التبولة', 'تبوله', 'tabbouli', 'tabouleh'],
    'shawarma': ['شاورما', 'شاورمة', 'الشاورما', 'shawerma'],
    'falafel': ['فلافل', 'الفلافل', 'falafil'],
    'taameya': ['طعمية', 'الطعمية', 'طعميه', 'taamiya'],
    'hummus': ['حمص بالطحينة', 'حمص بطحينة', 'حمص بالطحينه', 'houmous'],
    'baba ghanoush': ['بابا غنوج', 'بابا غنوش', 'baba ghanouj'],
    'mutabbal': ['متبل باذنجان', 'متبل الباذنجان', 'moutabbal'],
    'ful medames': ['فول مدمس', 'الفول المدمس', 'foul medames', 'ful mudammas'],
    'koshari': ['كشري', 'كشرى', 'الكشري', 'كشري مصري', 'kushari', 'koshary'],
    'molokhia': ['ملوخية', 'ملوخيه', 'الملوخية', 'ملوخيّة', 'mulukhiyah', 'molokheya'],
    'bamia': ['بامية باللحم', 'باميا باللحم', 'bamya'],
    'mahshi': ['محشي', 'المحشي', 'محاشي', 'محاشى'],
    'wara enab': ['ورق عنب', 'ورق العنب', 'waraq enab'],
    'yalangi': ['يلنجي', 'يالانجي', 'يالنجي', 'yalanjee'],
    'fattah': ['فتة', 'الفتة', 'فته', 'fatta'],
    'hawawshi': ['حواوشي', 'حواوشى', 'الحواوشي'],
    'feteer meshaltet': ['فطير مشلتت', 'الفطير المشلتت'],
    'sayadieh': ['صيادية', 'صياديه', 'الصيادية', 'sayadiyah'],
    'kofta': ['كفتة', 'كفته', 'الكفتة', 'kafta'],
    'shish tawook': ['شيش طاووق', 'شيش طوق', 'shish taouk'],
    'lahm bi ajin': ['لحم بعجين', 'لحم بالعجين'],
    'manakish': ['مناقيش', 'منقوشة', 'مناكيش', 'manakeesh', 'manaeesh'],
    'sambousek': ['سمبوسك', 'سمبوسة', 'سمبوسه', 'sambousak'],
    'harira': ['حريرة', 'الحريرة', 'حريره'],
    'bissara': ['بصارة', 'البيصارة', 'بيصارة', 'bessara'],
    'couscous': ['كسكس', 'كسكسي', 'كُسْكُس', 'couscous'],
    'rfissa': ['رفيسة', 'الرفيسة', 'رفيسه'],
    'chakhchoukha': ['شخشوخة', 'شخشوخه', 'الشخشوخة'],
    'shakshuka': ['شكشوكة', 'شكشوكه', 'الشكشوكة', 'chakchouka'],
    'brik': ['بريك', 'بريك تونسي'],
    'tajine': ['طاجين', 'طاجن', 'الطاجين', 'tagine'],
    'freekeh': ['فريكة', 'فريكه', 'الفريكة', 'فريك', 'frikeh'],
    'bulgur': ['برغل', 'البرغل', 'burghul', 'bulghur'],
    'labneh': ['لبنة', 'لبنه', 'اللبنة', 'labne', 'labnah'],
    'jameed': ['جميد', 'الجميد'],
    'akkawi': ['عكاوي', 'عكاوى', 'جبنة عكاوي', 'akawi'],
    'nabulsi cheese': ['جبن نابلسي', 'جبنة نابلسية', 'جبنه نابلسيه'],
    'halloumi': ['حلوم', 'حلومي', 'حلومى', 'haloumi'],
    'tahini': ['طحينة', 'طحينه', 'الطحينة', 'tahina'],
    'date molasses': ['دبس تمر', 'دبس التمر'],
    'pomegranate molasses': ['دبس رمان', 'دبس الرمان'],
    'zaatar': ['زعتر', 'الزعتر', 'za atar'],
    'sumac': ['سماق', 'السماق', 'summaq'],
    'dukkah': ['دقة', 'دقه', 'دقة مصرية', 'duqqa'],
    'lupin': ['ترمس', 'الترمس', 'lupini'],
    'carob': ['خروب', 'الخروب'],
    'tamarind': ['تمر هندي', 'تمر هندى', 'التمر الهندي'],
    'hibiscus': ['كركديه', 'كركدية', 'كركدي', 'الكركديه'],
    'basbousa': ['بسبوسة', 'بسبوسه', 'البسبوسة', 'basbusa'],
    'kunafa': ['كنافة', 'كنافه', 'الكنافة', 'knafeh', 'kanafeh'],
    'qatayef': ['قطايف', 'قطائف', 'القطايف'],
    'maamoul': ['معمول', 'المعمول', 'mamoul'],
    'umm ali': ['أم علي', 'ام علي', 'ام على', 'om ali'],
    'muhallabia': ['مهلبية', 'مهلبيه', 'محلبية', 'muhallebi'],
    'juhayna': ['جهينة', 'جهينه', 'juhaina'],
    'almarai': ['المراعي', 'مراعي', 'المراعى', 'al marai'],
    'nadec': ['نادك', 'nadec'],
    'al safi': ['الصافي', 'الصافى', 'alsafi'],
    'al rawabi': ['الروابي', 'الروابى', 'alrawabi'],
    'baladna': ['بلدنا', 'baladna'],
    'dina farms': ['مزارع دينا', 'دينا فارمز'],
    'domty': ['دومتي', 'دومتى'],
    'obour land': ['عبور لاند', 'عبورلاند', 'obourland'],
    'puck': ['بوك', 'جبنة بوك'],
    'kiri': ['كيري', 'كيرى'],
    'president': ['بريزيدن', 'بريزيدنت'],
    'lactel': ['لاكتيل', 'لاكتل'],
    'lamar': ['لمار', 'لامار'],
    'al ain': ['العين', 'alain'],
    'sadia': ['ساديا', 'سادية'],
    'americana': ['أمريكانا', 'امريكانا', 'americana'],
    'halwani': ['حلواني', 'حلوانى', 'حلواني اخوان'],
    'basmati': ['بسمتي', 'بسمتى'],
  };

  static final Map<String, String> _index = _buildIndex();

  static Map<String, String> _buildIndex() {
    final result = <String, String>{};
    for (final entry in aliases.entries) {
      final canonical = FoodSearchNormalizer.normalize(entry.key);
      for (final spelling in [entry.key, ...entry.value]) {
        final alias = FoodSearchNormalizer.normalize(spelling);
        final previous = result[alias];
        if (previous != null && previous != canonical) {
          throw StateError('Ambiguous regional food alias: $alias');
        }
        result[alias] = canonical;
      }
    }
    return Map.unmodifiable(result);
  }

  /// Longest whole-phrase matching avoids replacing words inside brand names
  /// and keeps grams, preparation and other qualifiers in the full query.
  static List<String> expand(String query) {
    final normalized = FoodSearchNormalizer.normalize(query);
    if (normalized.isEmpty) return const [];
    final words = normalized.split(' ');
    final translated = <String>[];
    var changed = false;
    for (var index = 0; index < words.length;) {
      String? replacement;
      var matchedLength = 1;
      for (var length = 4; length > 0; length--) {
        if (index + length > words.length) continue;
        final phrase = words.sublist(index, index + length).join(' ');
        replacement = _index[phrase];
        if (replacement != null) {
          matchedLength = length;
          changed |= replacement != phrase;
          break;
        }
      }
      translated.add(replacement ?? words[index]);
      index += matchedLength;
    }
    return changed ? [normalized, translated.join(' ')] : [normalized];
  }
}
