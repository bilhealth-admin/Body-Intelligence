import 'food_search_normalizer.dart';
import 'food_multilingual_lexicon.dart';

class FoodSearchAssistance {
  const FoodSearchAssistance();

  static const Map<String, List<String>> _queryExpansions =
      <String, List<String>>{
        "دجاج": <String>["chicken", "poultry"],
        "دجاجة": <String>["chicken"],
        "فروج": <String>["chicken"],
        "فراخ": <String>["chicken"],
        "شيكن": <String>["chicken"],
        "تشيكن": <String>["chicken"],
        "دجاح": <String>["chicken"],
        "دجاد": <String>["chicken"],
        "صدر": <String>["breast"],
        "صدور": <String>["breast"],
        "فخذ": <String>["thigh"],
        "أفخاذ": <String>["thigh"],
        "افخاذ": <String>["thigh"],
        "ورك": <String>["thigh", "leg"],
        "أوراك": <String>["thigh", "leg"],
        "اوراك": <String>["thigh", "leg"],
        "ساق": <String>["leg"],
        "جناح": <String>["wing"],
        "مفروم": <String>["ground", "minced"],
        "فيليه": <String>["fillet"],
        "نيء": <String>["raw"],
        "ني": <String>["raw"],
        "مطبوخ": <String>["cooked"],
        "مطهو": <String>["cooked"],
        "مسلوق": <String>["boiled"],
        "مشوي": <String>["grilled", "roasted"],
        "مقلي": <String>["fried"],
        "مخبوز": <String>["baked"],
        "بدون جلد": <String>["skinless"],
        "جلد": <String>["skin"],
        "لحم": <String>["meat"],
        "لحمة": <String>["meat"],
        "بقري": <String>["beef"],
        "غنم": <String>["lamb", "mutton"],
        "خروف": <String>["lamb"],
        "ديك رومي": <String>["turkey"],
        "حبش": <String>["turkey"],
        "بط": <String>["duck"],
        "كبد": <String>["liver"],
        "نقانق": <String>["sausage"],
        "سجق": <String>["sausage"],
        "برغر": <String>["burger"],
        "بيض": <String>["egg", "eggs"],
        "بيضة": <String>["egg"],
        "صفار": <String>["egg yolk"],
        "بياض": <String>["egg white"],
        "حليب": <String>["milk"],
        "لبن": <String>["milk", "yogurt"],
        "زبادي": <String>["yogurt"],
        "جبن": <String>["cheese"],
        "جبنة": <String>["cheese"],
        "قريش": <String>["cottage cheese"],
        "شيدر": <String>["cheddar"],
        "موزاريلا": <String>["mozzarella"],
        "زبدة": <String>["butter"],
        "قشطة": <String>["cream"],
        "سمن": <String>["ghee"],
        "خالي الدسم": <String>["skim", "nonfat"],
        "قليل الدسم": <String>["low fat"],
        "كامل الدسم": <String>["whole milk", "full fat"],
        "رز": <String>["rice"],
        "أرز": <String>["rice"],
        "ارز": <String>["rice"],
        "بسمتي": <String>["basmati"],
        "شوفان": <String>["oat", "oats", "oatmeal"],
        "قمح": <String>["wheat"],
        "شعير": <String>["barley"],
        "ذرة": <String>["corn"],
        "دقيق": <String>["flour"],
        "طحين": <String>["flour"],
        "خبز": <String>["bread"],
        "توست": <String>["toast"],
        "مكرونة": <String>["pasta"],
        "معكرونة": <String>["pasta"],
        "بطاطا": <String>["potato", "sweet potato"],
        "بطاطس": <String>["potato"],
        "عدس": <String>["lentil"],
        "حمص": <String>["chickpea", "hummus"],
        "فول": <String>["fava bean"],
        "فاصوليا": <String>["bean", "beans"],
        "بازلاء": <String>["peas"],
        "صويا": <String>["soy", "soybean"],
        "سمك": <String>["fish"],
        "تونة": <String>["tuna"],
        "سلمون": <String>["salmon"],
        "سردين": <String>["sardine"],
        "ماكريل": <String>["mackerel"],
        "بلطي": <String>["tilapia"],
        "جمبري": <String>["shrimp"],
        "روبيان": <String>["shrimp"],
        "طماطم": <String>["tomato"],
        "بندورة": <String>["tomato"],
        "خيار": <String>["cucumber"],
        "خس": <String>["lettuce"],
        "جرجير": <String>["arugula"],
        "سبانخ": <String>["spinach"],
        "ملوخية": <String>["jute leaves", "molokhia"],
        "بامية": <String>["okra"],
        "كوسا": <String>["zucchini"],
        "باذنجان": <String>["eggplant"],
        "فلفل": <String>["pepper"],
        "بروكلي": <String>["broccoli"],
        "قرنبيط": <String>["cauliflower"],
        "جزر": <String>["carrot"],
        "بصل": <String>["onion"],
        "ثوم": <String>["garlic"],
        "فطر": <String>["mushroom"],
        "مشروم": <String>["mushroom"],
        "أفوكادو": <String>["avocado"],
        "افوكادو": <String>["avocado"],
        "تفاح": <String>["apple", "apples"],
        "تفاحة": <String>["apple"],
        "تفح": <String>["apple"],
        "موز": <String>["banana"],
        "برتقال": <String>["orange"],
        "عنب": <String>["grape"],
        "فراولة": <String>["strawberry"],
        "مانجو": <String>["mango"],
        "أناناس": <String>["pineapple"],
        "خوخ": <String>["peach"],
        "كمثرى": <String>["pear"],
        "رمان": <String>["pomegranate"],
        "بطيخ": <String>["watermelon"],
        "شمام": <String>["melon"],
        "تمر": <String>["dates"],
        "لوز": <String>["almond"],
        "جوز": <String>["walnut"],
        "عين جمل": <String>["walnut"],
        "فستق": <String>["pistachio"],
        "كاجو": <String>["cashew"],
        "فول سوداني": <String>["peanut"],
        "سمسم": <String>["sesame"],
        "طحينة": <String>["tahini"],
        "زيت زيتون": <String>["olive oil"],
        "دونات": <String>["donut", "doughnut"],
        "بيتزا": <String>["pizza"],
        "شاورما": <String>["shawarma"],
        "فلافل": <String>["falafel"],
        "طعمية": <String>["falafel"],
        "شوربة": <String>["soup"],
        "سلطة": <String>["salad"],
        "ساندويتش": <String>["sandwich"],
        "بسكويت": <String>["cookie", "biscuit"],
        "كيك": <String>["cake"],
        "شوكولاتة": <String>["chocolate"],
        "آيس كريم": <String>["ice cream"],
        "سكر": <String>["sugar"],
        "عسل": <String>["honey"],
        "مربى": <String>["jam"],
        "دبس": <String>["molasses"],
        "ماء": <String>["water"],
        "قهوة": <String>["coffee"],
        "شاي": <String>["tea"],
        "عصير": <String>["juice"],
        "كولا": <String>["cola"],
        "chek": <String>["chicken"],
        "chik": <String>["chicken"],
        "chiken": <String>["chicken"],
        "chikn": <String>["chicken"],
        "aple": <String>["apple"],
        "appel": <String>["apple"],
        "bnana": <String>["banana"],
        "rise": <String>["rice"],
        "oet": <String>["oat"],
        "yogort": <String>["yogurt"],
        "potatoe": <String>["potato"],
      };

  static const Map<String, String> _englishToArabic = <String, String>{
    "chicken": "دجاج",
    "poultry": "دواجن",
    "breast": "صدر",
    "thigh": "فخذ",
    "leg": "ساق",
    "wing": "جناح",
    "ground": "مفروم",
    "minced": "مفروم",
    "raw": "نيّئ",
    "peel": "بقشره",
    "peeled": "مقشّر",
    "pickle": "مخلل",
    "pickles": "مخلل",
    "dill": "شبت",
    "kosher": "كوشير",
    "sour": "حامض",
    "cooked": "مطهو",
    "roasted": "مشوي",
    "grilled": "مشوي",
    "fried": "مقلي",
    "boiled": "مسلوق",
    "baked": "مخبوز",
    "skinless": "بدون جلد",
    "skin": "جلد",
    "meat": "لحم",
    "beef": "لحم بقري",
    "lamb": "لحم غنم",
    "mutton": "لحم غنم",
    "turkey": "ديك رومي",
    "duck": "بط",
    "liver": "كبد",
    "sausage": "نقانق",
    "egg": "بيض",
    "eggs": "بيض",
    "milk": "حليب",
    "yogurt": "زبادي",
    "cheese": "جبن",
    "butter": "زبدة",
    "cream": "كريمة",
    "rice": "أرز",
    "oat": "شوفان",
    "oats": "شوفان",
    "oatmeal": "شوفان",
    "wheat": "قمح",
    "barley": "شعير",
    "corn": "ذرة",
    "flour": "دقيق",
    "bread": "خبز",
    "toast": "توست",
    "pasta": "معكرونة",
    "potato": "بطاطا",
    "lentil": "عدس",
    "chickpea": "حمص",
    "beans": "فاصوليا",
    "bean": "فاصوليا",
    "fish": "سمك",
    "tuna": "تونة",
    "salmon": "سلمون",
    "shrimp": "روبيان",
    "tomato": "طماطم",
    "cucumber": "خيار",
    "lettuce": "خس",
    "spinach": "سبانخ",
    "okra": "بامية",
    "zucchini": "كوسا",
    "eggplant": "باذنجان",
    "pepper": "فلفل",
    "broccoli": "بروكلي",
    "cauliflower": "قرنبيط",
    "carrot": "جزر",
    "onion": "بصل",
    "garlic": "ثوم",
    "mushroom": "فطر",
    "avocado": "أفوكادو",
    "apple": "تفاح",
    "apples": "تفاح",
    "banana": "موز",
    "orange": "برتقال",
    "grape": "عنب",
    "strawberry": "فراولة",
    "mango": "مانجو",
    "pineapple": "أناناس",
    "peach": "خوخ",
    "pear": "كمثرى",
    "watermelon": "بطيخ",
    "dates": "تمر",
    "almond": "لوز",
    "walnut": "جوز",
    "pistachio": "فستق",
    "cashew": "كاجو",
    "peanut": "فول سوداني",
    "sesame": "سمسم",
    "oil": "زيت",
    "olive": "زيتون",
    "donut": "دونات",
    "doughnut": "دونات",
    "pizza": "بيتزا",
    "soup": "شوربة",
    "salad": "سلطة",
    "sandwich": "ساندويتش",
    "cookie": "بسكويت",
    "cake": "كيك",
    "chocolate": "شوكولاتة",
    "sugar": "سكر",
    "honey": "عسل",
    "water": "ماء",
    "coffee": "قهوة",
    "tea": "شاي",
    "juice": "عصير",
    "white": "أبيض",
    "brown": "بني",
    "fresh": "طازج",
    "frozen": "مجمد",
    "canned": "معلب",
    "dried": "مجفف",
    "not": "غير",
    "only": "فقط",
    "whole": "كامل",
    "eaten": "مأكول",
    "boneless": "بدون عظم",
    "bone": "عظم",
    "prepared": "محضر",
    "fuji": "فوجي",
    "gala": "جالا",
    "basmati": "بسمتي",
  };

  List<String> expand(String query) {
    final normalized = FoodSearchNormalizer.normalize(query);
    if (normalized.isEmpty) {
      return const <String>[];
    }
    final expanded = <String>{...FoodMultilingualLexicon.expand(normalized)};
    final exact = _queryExpansions[normalized];
    if (exact != null) {
      expanded.addAll(exact);
    }
    final translated = <String>[];
    var changed = false;
    for (final token in normalized.split(RegExp(r'\s+'))) {
      final values = _queryExpansions[token];
      if (values == null || values.isEmpty) {
        translated.add(token);
      } else {
        translated.add(values.first);
        changed = true;
      }
    }
    if (changed) {
      expanded.add(translated.join(' '));
    }
    final correction = correctionFor(normalized);
    if (correction != null) {
      expanded.add(correction);
    }
    return expanded.toList(growable: false);
  }

  String? correctionFor(String query) {
    final normalized = FoodSearchNormalizer.normalize(query);
    if (normalized.isEmpty) {
      return null;
    }
    final exact = _queryExpansions[normalized];
    if (exact != null && exact.isNotEmpty && exact.first != normalized) {
      return exact.first;
    }
    String? best;
    var bestDistance = 99;
    for (final key in _queryExpansions.keys) {
      if ((key.length - normalized.length).abs() > 3) continue;
      final distance = _levenshtein(normalized, key);
      final threshold = normalized.length <= 4 ? 1 : 2;
      if (distance <= threshold && distance < bestDistance) {
        best = key;
        bestDistance = distance;
      }
    }
    if (best == null) {
      return null;
    }
    final values = _queryExpansions[best];
    return values == null || values.isEmpty ? best : values.first;
  }

  /// Returns only an authored correction/translation for the exact query.
  ///
  /// Meal search uses this conservative boundary for an empty result state.
  /// Fuzzy dictionary neighbours are useful for ranking, but presenting them
  /// as user-facing alternatives can suggest unrelated food names.
  String? explicitCorrectionFor(String query) {
    final normalized = FoodSearchNormalizer.normalize(query);
    if (normalized.isEmpty) return null;
    final values = _queryExpansions[normalized];
    if (values == null || values.isEmpty) return null;
    final correction = values.first.trim();
    return correction.isEmpty || correction == normalized ? null : correction;
  }

  List<String> suggestionsFor(String query, {int limit = 6}) {
    final normalized = FoodSearchNormalizer.normalize(query);
    if (normalized.isEmpty) {
      return const <String>[];
    }
    final matches = _queryExpansions.keys.where((key) {
      if (key.startsWith(normalized) || key.contains(normalized)) {
        return true;
      }
      return _levenshtein(normalized, key) <= 2;
    }).toList()..sort((a, b) => a.length.compareTo(b.length));
    return matches.take(limit).toList(growable: false);
  }

  String? arabicNameFor(String description) {
    final normalized = FoodSearchNormalizer.normalize(description);
    final result = <String>[];
    var meaningfulTokens = 0;
    var translatedTokens = 0;
    for (final token in normalized.split(RegExp(r'\s+'))) {
      final clean = token.replaceAll(RegExp(r'[^a-z]'), '');
      if (clean.isEmpty || _englishStopWords.contains(clean)) continue;
      meaningfulTokens += 1;
      final translated = _englishToArabic[clean];
      if (translated != null && !result.contains(translated)) {
        result.add(translated);
        translatedTokens += 1;
      }
    }
    if (meaningfulTokens == 0 || result.isEmpty) return null;

    // A partial label is worse than no translation: it collapses distinct USDA
    // records into misleading names such as dozens of unrelated rows all shown
    // as just "بط". Only expose a generated Arabic display name when most of
    // the source meaning survived; otherwise the authoritative source name is
    // displayed intact.
    final coverage = translatedTokens / meaningfulTokens;
    if (coverage < 0.75) return null;
    return result.join(' ');
  }

  static const Set<String> _englishStopWords = <String>{
    'a',
    'an',
    'and',
    'as',
    'at',
    'by',
    'for',
    'from',
    'in',
    'of',
    'or',
    'the',
    'to',
    'with',
  };

  int _levenshtein(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final values = <int>[
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ];
        current[j + 1] = values.reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous.last;
  }
}
