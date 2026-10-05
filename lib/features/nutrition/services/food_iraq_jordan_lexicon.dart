import 'food_search_normalizer.dart';

/// Regional search names, not interchangeable recipes or nutrient evidence.
/// Source references and scope are recorded in docs/foods/GLOBAL_COVERAGE_2026-10-05.md.
abstract final class FoodIraqJordanLexicon {
  static const aliases = <String, List<String>>{
    'rice': ['تمن', 'تمّن', 'التمن', 'timman', 'tumman'],
    'tomato': ['طماطة', 'طماطه', 'طماطم عراقية'],
    'eggplant': ['باذنجان عراقي', 'باذنجان عراقى'],
    'masgouf': ['مسكوف', 'مسگوف', 'المسكوف', 'سمك مسكوف', 'masguf'],
    'quzi': ['قوزي', 'قوزى', 'گوزي', 'القوزي', 'qoozi'],
    'iraqi dolma': ['دولمة عراقية', 'دولمه عراقيه', 'دولمة', 'دولمه', 'الدولمة'],
    'bagilla bil dihin': ['باقلاء بالدهن', 'باقلة بالدهن', 'باگلاء بالدهن', 'باجلا بالدهن', 'bagilla bil dehen'],
    'thareed bagilla': ['تشريب باقلاء', 'ثريد باقلاء', 'تشريب باجلا', 'ثريد باجلا'],
    'kubba halab': ['كبة حلب', 'كبه حلب', 'كبة حلب عراقية', 'kubbat halab'],
    'kubba mosul': ['كبة موصل', 'كبة موصلية', 'كبه موصليه', 'كبة الموصل', 'kubba mosel'],
    'kubba hamouth': ['كبة حامض', 'كبه حامض', 'كبة حامض شلغم', 'kubba hamud'],
    'kubba yachni': ['كبة يخني', 'كبه يخني', 'شوربة كبة يخني'],
    'iraqi pacha': ['باجة', 'باجه', 'پاچه', 'پاچة', 'الباجة'],
    'iraqi qeema': ['قيمة عراقية', 'قيمة نجفية', 'قيمه نجفيه', 'qeema najafiya'],
    'tepsi baytinijan': ['تبسي باذنجان', 'تبسى باذنجان', 'تبسي بيتنجان'],
    'timman bagilla': ['تمن باقلاء', 'تمن باگلاء', 'تمن باجلا', 'تمن باقلاء وشبنت'],
    'timman jizar': ['تمن جزر', 'تمن بالجزر'],
    'iraqi biryani': ['برياني عراقي', 'بريانى عراقى'],
    'parda plau': ['بردة بلاو', 'برده بلاو', 'پردة پلاو'],
    'makhlama': ['مخلمة', 'مخلمه', 'مخلمة بغدادية'],
    'kleicha': ['كليجة', 'كليجه', 'كليچة', 'كليچه', 'كليجة عراقية'],
    'dahina': ['دهينة', 'دهينه', 'دهين نجفي', 'دهينة نجفية'],
    'geemar': ['قيمر', 'گيمر', 'قيمر عراقي', 'قيمق بغداد', 'gaimar'],
    'kahi': ['كاهي', 'كاهى', 'الكاهي'],
    'dibis wa rashi': ['دبس وراشي', 'دبس و راشي', 'دبس وراشى'],
    'samoon': ['صمون', 'الصمون', 'صمون عراقي'],
    'khubz tannour': ['خبز تنور', 'خبز التنور', 'خبز تنور عراقي'],
    'iraqi white bean stew': ['مرقة فاصوليا', 'مرگة فاصوليا', 'مرقة فاصوليا يابسة'],
    'rashouf': ['رشوف', 'الرشوف', 'رشوف أردني', 'رشوف اردني', 'rashoof'],
    'makmoura': ['مكمورة', 'مكموره', 'المكمورة', 'مكمورة إربد', 'makmoora'],
    'rushtayeh': ['رشتاية', 'رشتايه', 'رشْتاية', 'رشتا'],
    'lazagiyat': ['لزاقيات', 'لزّاقيات', 'لزاقية', 'لزاقيه'],
    'jaajil': ['جعاجيل', 'جعاجيل أردنية', 'جعاجيل اردنيه'],
    'shrak bread': ['خبز شراك', 'خبز الشراك', 'شراك'],
    'galyet bandora': ['قلاية بندورة', 'قلاية بندوره', 'قلايه بندوره', 'galayet bandora'],
    'zarb': ['زرب', 'الزرب', 'زرب أردني', 'زرب اردني'],
    'jameed karaki': ['جميد كركي', 'جميد كركى', 'جميد الكرك'],
    'qurs al nar': ['قرص النار', 'قرصة النار'],
    'teeba': ['طيبة ألبان', 'طيبة البان', 'ألبان طيبة', 'البان طيبة'],
    'hammoudeh': ['حمودة', 'حموده', 'حمودة ألبان', 'ألبان حمودة'],
    'kasih': ['الكسيح', 'كسيح'],
    'al kasih': ['مصانع الكسيح'],
  };
  static final Map<String, String> _index = {
    for (final entry in aliases.entries)
      for (final alias in [entry.key, ...entry.value])
        FoodSearchNormalizer.normalize(alias): entry.key,
  };

  static List<String> expand(String query) {
    final normalized = FoodSearchNormalizer.normalize(query);
    if (normalized.isEmpty) return const [];
    final words = normalized.split(' ');
    final output = <String>[];
    var changed = false;
    for (var i = 0; i < words.length;) {
      String? match;
      var consumed = 1;
      for (var length = 5; length > 0; length--) {
        if (i + length > words.length) continue;
        final phrase = words.sublist(i, i + length).join(' ');
        match = _index[phrase];
        if (match != null) {
          consumed = length;
          changed |= match != phrase;
          break;
        }
      }
      output.add(match ?? words[i]);
      i += consumed;
    }
    return changed ? [normalized, output.join(' ')] : [normalized];
  }
}
