import '../../nutrition/services/food_presentation_localizer.dart';

/// Corrects known untranslated catalog lines at presentation time without
/// modifying the signed source, quantities, source identities or cooking method.
/// Unknown prose is preserved; this is not an automatic translation service.
abstract final class RecipeContentLocalizer {
  static Map<String, dynamic> resolve(
    Map<String, dynamic> source,
    String locale,
  ) => {
    ...source,
    'ingredients': [
      for (final line in (source['ingredients'] as List).cast<String>())
        ingredient(line, locale),
    ],
    'steps': [
      for (final line in (source['steps'] as List).cast<String>())
        step(line, locale),
    ],
  };

  static String ingredient(String line, String locale) {
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(g|kg|ml|oz|lb)\s+(.+)$',
    ).firstMatch(line);
    if (match == null) return line;
    final originalName = match[3]!;
    final name =
        (locale == 'ar' ? _arabicNames[originalName.toLowerCase()] : null) ??
        FoodPresentationLocalizer.foodName(
          name: originalName,
          localeTag: locale,
        );
    return '${match[1]} ${FoodPresentationLocalizer.servingUnit(match[2]!, locale)} $name';
  }

  static String step(String line, String locale) {
    if (locale == 'en') return line;
    final translations = _steps[locale];
    if (translations == null) return line;
    final normalized = line.trim().replaceAll('flavors', 'flavours');
    final index = normalized.startsWith('Measure and prepare: ')
        ? 0
        : switch (normalized) {
            'Simmer gently until the ingredients are tender and the flavours combine.' =>
              1,
            'Bake until cooked through and evenly browned.' => 2,
            'Cook covered, then steam until the grains are tender.' => 3,
            'Cook the components separately, then layer them before serving.' =>
              4,
            'Divide into the stated servings and serve.' => 5,
            _ => -1,
          };
    return index < 0 ? line : translations[index];
  }

  static const _arabicNames = <String, String>{
    'rice': 'أرز',
    'chicken breast': 'صدر الدجاج',
    'eggplant': 'باذنجان',
    'tomato': 'طماطم',
    'chickpeas': 'حمص',
    'lentils': 'عدس',
    'onion': 'بصل',
    'celery': 'كرفس',
    'cod': 'سمك القد',
    'potato': 'بطاطس',
    'bell pepper': 'فلفل حلو',
    'olive oil': 'زيت الزيتون',
    'pita bread': 'خبز البيتا',
    'couscous': 'كسكس',
    'zucchini': 'كوسة',
    'carrot': 'جزر',
    'tomato sauce': 'صلصة الطماطم',
    'yogurt': 'زبادي',
    'fava beans': 'فول',
    'tahini': 'طحينة',
    'lemon juice': 'عصير الليمون',
    'wheat': 'قمح',
    'grape leaves': 'ورق العنب',
    'ground beef': 'لحم بقري مفروم',
    'bulgur': 'برغل',
    'carp': 'سمك الشبوط',
    'peas': 'بازلاء',
    'snapper': 'سمك النهاش',
    'flatbread': 'خبز مسطح',
    'okra': 'بامية',
    'beef': 'لحم بقري',
  };
  static const _steps = <String, List<String>>{
    'ar': [
      'قِس جميع المكونات وجهّزها.',
      'اطهِ على نار هادئة حتى تلين المكونات وتمتزج النكهات.',
      'اخبز حتى ينضج الطعام تمامًا ويتحمّر بالتساوي.',
      'اطهِ مع تغطية القدر، ثم بالبخار حتى تلين الحبوب.',
      'اطهِ المكونات منفصلة، ثم رتّبها في طبقات قبل التقديم.',
      'قسّم إلى الحصص المذكورة وقدّمها.',
    ],
    'en': [
      'Measure and prepare all ingredients.',
      'Simmer gently until the ingredients are tender and the flavours combine.',
      'Bake until cooked through and evenly browned.',
      'Cook covered, then steam until the grains are tender.',
      'Cook the components separately, then layer them before serving.',
      'Divide into the stated servings and serve.',
    ],
    'fr': [
      'Mesurez et préparez tous les ingrédients.',
      'Laissez mijoter doucement jusqu’à ce que les ingrédients soient tendres et les saveurs mélangées.',
      'Faites cuire au four jusqu’à cuisson complète et coloration uniforme.',
      'Faites cuire à couvert, puis à la vapeur jusqu’à ce que les grains soient tendres.',
      'Faites cuire les ingrédients séparément, puis disposez-les en couches avant de servir.',
      'Répartissez en portions indiquées et servez.',
    ],
    'es': [
      'Mide y prepara todos los ingredientes.',
      'Cocina a fuego lento hasta que los ingredientes estén tiernos y se mezclen los sabores.',
      'Hornea hasta que esté bien cocido y dorado de manera uniforme.',
      'Cocina tapado y luego al vapor hasta que los granos estén tiernos.',
      'Cocina los ingredientes por separado y luego colócalos en capas antes de servir.',
      'Divide en las porciones indicadas y sirve.',
    ],
    'tr': [
      'Tüm malzemeleri ölçüp hazırlayın.',
      'Malzemeler yumuşayıp lezzetler birleşene kadar kısık ateşte pişirin.',
      'İçi tamamen pişip eşit şekilde kızarana kadar fırınlayın.',
      'Kapağı kapalı pişirin, ardından taneler yumuşayana kadar buharda pişirin.',
      'Malzemeleri ayrı ayrı pişirin, servis etmeden önce katmanlar halinde yerleştirin.',
      'Belirtilen porsiyonlara bölüp servis edin.',
    ],
    'th': [
      'ตวงและเตรียมส่วนผสมทั้งหมด',
      'เคี่ยวด้วยไฟอ่อนจนส่วนผสมนุ่มและรสชาติเข้ากัน',
      'อบจนสุกทั่วและเป็นสีน้ำตาลอย่างสม่ำเสมอ',
      'ปิดฝาปรุงแล้วนึ่งจนเมล็ดธัญพืชนุ่ม',
      'ปรุงส่วนผสมแยกกัน แล้วจัดเป็นชั้นก่อนเสิร์ฟ',
      'แบ่งเป็นจำนวนที่ระบุแล้วเสิร์ฟ',
    ],
  };
}
