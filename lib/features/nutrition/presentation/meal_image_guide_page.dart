import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../providers/meal_vision_usage_provider.dart';
import '../services/meal_vision_usage_contract.dart';

part 'meal_image_guide_widgets.dart';

const _mealGuideTranslations = <String, Map<String, String>>{
  'en': {
    'meal_scan': 'Meal Scan',
    'not_now': 'Not now',
    'choose_photo': 'Choose a meal photo',
    'continue': 'Continue',
    'suggestions_disclaimer':
        'Suggestions are not nutrition facts. You stay in control and nothing is logged until you confirm it.',
    'step_progress': 'STEP {current} OF {total}',
    'step_scan_title': 'Scan your entire meal',
    'step_scan_body': 'Keep the full plate in frame and use clear, even light.',
    'step_select_title': 'Select visible foods',
    'step_select_body':
        'Confirm only foods you can see. Remove uncertain suggestions.',
    'step_add_title': 'Add anything we missed',
    'step_add_body':
        'Search the trusted catalog for sauces, drinks, and sides.',
    'step_review_title': 'Review and log your meal',
    'step_review_body':
        'Check portions and nutrition sources before anything is saved.',
    'frame_meal': 'Frame your meal',
    'visible_foods': 'Visible foods',
    'grilled_chicken': 'Grilled chicken',
    'rice': 'Rice',
    'mixed_salad': 'Mixed salad',
    'confirm_visible': 'Confirm only what you see',
    'add_another_food': 'Add another food',
    'search_foods': 'Search foods',
    'tahini_sauce': 'Tahini sauce',
    'sparkling_water': 'Sparkling water',
    'pita_bread': 'Pita bread',
    'review_meal': 'Review meal',
    'chicken': 'Chicken',
    'trusted_source': 'Source: trusted catalog',
    'portion_review': 'Portion needs review',
    'salad': 'Salad',
    'nothing_saved': 'Nothing is saved until you confirm',
    'usage':
        '{remaining} analyses available from weekly allowance and AI Boost',
    'usage_unavailable': 'Analysis allowance is unavailable right now.',
    'usage_signed_out': 'Sign in to check your analysis allowance.',
    'quota_exhausted': 'Weekly allowance and AI Boost balance are exhausted.',
  },
  'ar': {
    'meal_scan': 'مسح الوجبة',
    'not_now': 'ليس الآن',
    'choose_photo': 'اختر صورة للوجبة',
    'continue': 'متابعة',
    'suggestions_disclaimer':
        'الاقتراحات ليست حقائق غذائية. أنت المتحكم، ولن يُسجَّل أي شيء حتى تؤكده.',
    'step_progress': 'الخطوة {current} من {total}',
    'step_scan_title': 'صوّر وجبتك كاملة',
    'step_scan_body':
        'أبقِ الطبق كاملًا داخل الإطار واستخدم إضاءة واضحة ومتوازنة.',
    'step_select_title': 'حدّد الأطعمة الظاهرة',
    'step_select_body':
        'أكّد فقط الأطعمة التي تراها. أزل الاقتراحات غير المؤكدة.',
    'step_add_title': 'أضف ما فاتنا',
    'step_add_body':
        'ابحث في الدليل الموثوق عن الصلصات والمشروبات والأطباق الجانبية.',
    'step_review_title': 'راجع وجبتك وسجّلها',
    'step_review_body':
        'تحقق من الحصص ومصادر المعلومات الغذائية قبل حفظ أي شيء.',
    'frame_meal': 'ضع وجبتك داخل الإطار',
    'visible_foods': 'الأطعمة الظاهرة',
    'grilled_chicken': 'دجاج مشوي',
    'rice': 'أرز',
    'mixed_salad': 'سلطة مشكلة',
    'confirm_visible': 'أكّد فقط ما تراه',
    'add_another_food': 'أضف طعامًا آخر',
    'search_foods': 'ابحث عن الأطعمة',
    'tahini_sauce': 'صلصة طحينة',
    'sparkling_water': 'مياه غازية',
    'pita_bread': 'خبز عربي',
    'review_meal': 'راجع الوجبة',
    'chicken': 'دجاج',
    'trusted_source': 'المصدر: دليل موثوق',
    'portion_review': 'الحصة تحتاج إلى مراجعة',
    'salad': 'سلطة',
    'nothing_saved': 'لن يُحفظ شيء حتى تؤكده',
    'usage': 'يتوفر {remaining} تحليلًا من الحصة الأسبوعية ورصيد AI Boost',
    'usage_unavailable': 'تعذر التحقق من رصيد التحليل الآن.',
    'usage_signed_out': 'سجّل الدخول للتحقق من رصيد التحليل.',
    'quota_exhausted': 'نفدت الحصة الأسبوعية ورصيد AI Boost.',
  },
  'fr': {
    'meal_scan': 'Analyse du repas',
    'not_now': 'Pas maintenant',
    'choose_photo': 'Choisir une photo du repas',
    'continue': 'Continuer',
    'suggestions_disclaimer':
        'Les suggestions ne sont pas des valeurs nutritionnelles. Vous gardez le contrôle et rien n’est enregistré sans votre confirmation.',
    'step_progress': 'ÉTAPE {current} SUR {total}',
    'step_scan_title': 'Photographiez tout votre repas',
    'step_scan_body':
        'Gardez l’assiette entière dans le cadre et utilisez une lumière claire et uniforme.',
    'step_select_title': 'Sélectionnez les aliments visibles',
    'step_select_body':
        'Confirmez uniquement les aliments que vous voyez. Supprimez les suggestions incertaines.',
    'step_add_title': 'Ajoutez ce que nous avons manqué',
    'step_add_body':
        'Recherchez sauces, boissons et accompagnements dans le catalogue vérifié.',
    'step_review_title': 'Vérifiez et enregistrez votre repas',
    'step_review_body':
        'Vérifiez les portions et les sources nutritionnelles avant tout enregistrement.',
    'frame_meal': 'Cadrez votre repas',
    'visible_foods': 'Aliments visibles',
    'grilled_chicken': 'Poulet grillé',
    'rice': 'Riz',
    'mixed_salad': 'Salade composée',
    'confirm_visible': 'Confirmez uniquement ce que vous voyez',
    'add_another_food': 'Ajouter un autre aliment',
    'search_foods': 'Rechercher des aliments',
    'tahini_sauce': 'Sauce tahini',
    'sparkling_water': 'Eau gazeuse',
    'pita_bread': 'Pain pita',
    'review_meal': 'Vérifier le repas',
    'chicken': 'Poulet',
    'trusted_source': 'Source : catalogue vérifié',
    'portion_review': 'Portion à vérifier',
    'salad': 'Salade',
    'nothing_saved': 'Rien n’est enregistré sans votre confirmation',
    'usage':
        '{remaining} analyses disponibles via le quota hebdomadaire et AI Boost',
    'usage_unavailable': 'Le quota d’analyse est indisponible actuellement.',
    'usage_signed_out': 'Connectez-vous pour consulter votre quota d’analyse.',
    'quota_exhausted':
        'Le quota hebdomadaire et le solde AI Boost sont épuisés.',
  },
  'es': {
    'meal_scan': 'Escaneo de comida',
    'not_now': 'Ahora no',
    'choose_photo': 'Elegir una foto de la comida',
    'continue': 'Continuar',
    'suggestions_disclaimer':
        'Las sugerencias no son datos nutricionales. Tú mantienes el control y no se registra nada hasta que lo confirmes.',
    'step_progress': 'PASO {current} DE {total}',
    'step_scan_title': 'Escanea toda tu comida',
    'step_scan_body':
        'Mantén el plato completo dentro del encuadre y usa una luz clara y uniforme.',
    'step_select_title': 'Selecciona los alimentos visibles',
    'step_select_body':
        'Confirma solo los alimentos que ves. Elimina las sugerencias dudosas.',
    'step_add_title': 'Añade lo que falte',
    'step_add_body':
        'Busca salsas, bebidas y acompañamientos en el catálogo verificado.',
    'step_review_title': 'Revisa y registra tu comida',
    'step_review_body':
        'Comprueba las porciones y las fuentes nutricionales antes de guardar nada.',
    'frame_meal': 'Encuadra tu comida',
    'visible_foods': 'Alimentos visibles',
    'grilled_chicken': 'Pollo a la parrilla',
    'rice': 'Arroz',
    'mixed_salad': 'Ensalada mixta',
    'confirm_visible': 'Confirma solo lo que ves',
    'add_another_food': 'Añadir otro alimento',
    'search_foods': 'Buscar alimentos',
    'tahini_sauce': 'Salsa tahini',
    'sparkling_water': 'Agua con gas',
    'pita_bread': 'Pan de pita',
    'review_meal': 'Revisar comida',
    'chicken': 'Pollo',
    'trusted_source': 'Fuente: catálogo verificado',
    'portion_review': 'La porción requiere revisión',
    'salad': 'Ensalada',
    'nothing_saved': 'No se guarda nada hasta que lo confirmes',
    'usage': '{remaining} análisis disponibles del cupo semanal y AI Boost',
    'usage_unavailable': 'El cupo de análisis no está disponible ahora.',
    'usage_signed_out': 'Inicia sesión para consultar tu cupo de análisis.',
    'quota_exhausted': 'Se agotaron el cupo semanal y el saldo de AI Boost.',
  },
  'tr': {
    'meal_scan': 'Öğün Tarama',
    'not_now': 'Şimdi değil',
    'choose_photo': 'Öğün fotoğrafı seç',
    'continue': 'Devam et',
    'suggestions_disclaimer':
        'Öneriler besin değeri değildir. Kontrol sizdedir ve siz onaylayana kadar hiçbir şey kaydedilmez.',
    'step_progress': 'ADIM {current} / {total}',
    'step_scan_title': 'Tüm öğününüzü tarayın',
    'step_scan_body':
        'Tabağın tamamını kadrajda tutun ve net, eşit ışık kullanın.',
    'step_select_title': 'Görünen yiyecekleri seçin',
    'step_select_body':
        'Yalnızca gördüğünüz yiyecekleri onaylayın. Emin olmadığınız önerileri kaldırın.',
    'step_add_title': 'Eksik kalanları ekleyin',
    'step_add_body':
        'Soslar, içecekler ve garnitürler için güvenilir katalogda arama yapın.',
    'step_review_title': 'Öğününüzü gözden geçirip kaydedin',
    'step_review_body':
        'Herhangi bir şey kaydedilmeden önce porsiyonları ve besin kaynaklarını kontrol edin.',
    'frame_meal': 'Öğününüzü kadraja alın',
    'visible_foods': 'Görünen yiyecekler',
    'grilled_chicken': 'Izgara tavuk',
    'rice': 'Pirinç',
    'mixed_salad': 'Karışık salata',
    'confirm_visible': 'Yalnızca gördüklerinizi onaylayın',
    'add_another_food': 'Başka yiyecek ekle',
    'search_foods': 'Yiyecek ara',
    'tahini_sauce': 'Tahin sosu',
    'sparkling_water': 'Maden suyu',
    'pita_bread': 'Pide ekmeği',
    'review_meal': 'Öğünü gözden geçir',
    'chicken': 'Tavuk',
    'trusted_source': 'Kaynak: güvenilir katalog',
    'portion_review': 'Porsiyon gözden geçirilmeli',
    'salad': 'Salata',
    'nothing_saved': 'Siz onaylayana kadar hiçbir şey kaydedilmez',
    'usage':
        'Haftalık haktan ve AI Boost bakiyesinden {remaining} analiz kullanılabilir',
    'usage_unavailable': 'Analiz hakkı şu anda kullanılamıyor.',
    'usage_signed_out': 'Analiz hakkınızı görmek için oturum açın.',
    'quota_exhausted': 'Haftalık hak ve AI Boost bakiyesi tükendi.',
  },
};

String _mealGuideText(
  BuildContext context,
  String key, {
  Map<String, String> values = const {},
}) {
  assert(_mealGuideTranslationsAreComplete);
  final locale = Localizations.localeOf(context);
  final languageCode = locale.languageCode;
  final english = _mealGuideTranslations['en']![key]!;
  var text =
      _mealGuideTranslations[languageCode]?[key] ??
      RuntimeCopy.resolve(english, BilLocalePolicy.canonicalTag(locale)) ??
      english;
  for (final entry in values.entries) {
    text = text.replaceAll('{${entry.key}}', entry.value);
  }
  return text;
}

bool get _mealGuideTranslationsAreComplete {
  final englishKeys = _mealGuideTranslations['en']!.keys.toSet();
  return _mealGuideTranslations.length == 5 &&
      _mealGuideTranslations.values.every(
        (catalog) =>
            catalog.keys.toSet().containsAll(englishKeys) &&
            englishKeys.containsAll(catalog.keys) &&
            catalog.values.every((value) => value.trim().isNotEmpty),
      );
}

String _mealGuideNumber(BuildContext context, int value) {
  final text = '$value';
  if (Localizations.localeOf(context).languageCode != 'ar') return text;
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  return text.split('').map((digit) => arabicDigits[int.parse(digit)]).join();
}

/// The production education boundary shown before a meal image leaves the
/// device. It explains the four-step review flow without implying that image
/// analysis is configured or that nutrition values can be inferred directly.
