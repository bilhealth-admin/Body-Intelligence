import '../../../app/localization/runtime_copy.dart';

abstract final class BilStorePhotoFeaturesCopy {
  static String? text(String locale, String key) {
    if (key == 'premium_benefit_personal_plan') {
      return RuntimeCopy.resolve('Personal plan', locale) ?? 'Personal plan';
    }
    if (key != 'ai_benefit_vision') return null;
    final tag = locale.replaceAll('_', '-').toLowerCase();
    final row = _rows[tag] ?? _rows[tag.split('-').first] ?? _rows['en']!;
    return 'BIL Vision · ${row[const bool.fromEnvironment('BIL_GEMINI_PHOTO_ESTIMATES_V2') ? 1 : 0]}';
  }

  // Old photo-review feature remains truthful while schema2 is default-off.
  static const _rows = <String, List<String>>{
    'en': [
      'Meal-photo review (AI tokens)',
      'Photo nutrition estimates (AI tokens)',
    ],
    'ar': ['مراجعة صور الوجبات (توكن AI)', 'تقديرات غذائية من الصور (توكن AI)'],
    'fr': [
      'Photos de repas (jetons IA)',
      'Estimations nutritionnelles par photo (jetons IA)',
    ],
    'es': [
      'Fotos de comidas (tokens IA)',
      'Estimaciones nutricionales por foto (tokens IA)',
    ],
    'tr': [
      'Öğün fotoğrafı incelemesi (AI tokenları)',
      'Fotoğraftan besin tahminleri (AI tokenları)',
    ],
    'de': [
      'Mahlzeitfotos prüfen (KI-Tokens)',
      'Nährwerte aus Fotos schätzen (KI-Tokens)',
    ],
    'it': [
      'Revisione foto pasti (token IA)',
      'Stime nutrizionali da foto (token IA)',
    ],
    'pt-br': [
      'Revisão de fotos de refeições (tokens IA)',
      'Estimativas nutricionais por foto (tokens IA)',
    ],
    'pt-pt': [
      'Revisão de fotos de refeições (tokens IA)',
      'Estimativas nutricionais por foto (tokens IA)',
    ],
    'ur': [
      'کھانے کی تصویر کا جائزہ (AI ٹوکن)',
      'تصویر سے غذائی تخمینے (AI ٹوکن)',
    ],
    'fa': ['بررسی عکس غذا (توکن AI)', 'برآورد تغذیه از عکس (توکن AI)'],
    'hi': ['भोजन फ़ोटो समीक्षा (AI टोकन)', 'फ़ोटो से पोषण अनुमान (AI टोकन)'],
    'id': [
      'Tinjau foto makanan (token AI)',
      'Perkiraan nutrisi dari foto (token AI)',
    ],
    'ms': [
      'Semakan foto makanan (token AI)',
      'Anggaran nutrisi daripada foto (token AI)',
    ],
    'ja': ['食事写真の確認（AIトークン）', '写真からの栄養推定（AIトークン）'],
    'ko': ['식사 사진 검토 (AI 토큰)', '사진 영양 추정 (AI 토큰)'],
    'zh-hans': ['餐食照片审核（AI代币）', '照片营养估算（AI代币）'],
    'zh-hant': ['餐食照片審閱（AI代幣）', '照片營養估算（AI代幣）'],
    'ru': [
      'Проверка фото еды (токены ИИ)',
      'Оценка питания по фото (токены ИИ)',
    ],
    'bn': [
      'খাবারের ছবি পর্যালোচনা (AI টোকেন)',
      'ছবি থেকে পুষ্টির অনুমান (AI টোকেন)',
    ],
    'vi': [
      'Xem lại ảnh bữa ăn (token AI)',
      'Ước tính dinh dưỡng từ ảnh (token AI)',
    ],
    'th': ['ตรวจสอบรูปอาหาร (โทเคน AI)', 'ประมาณสารอาหารจากรูป (โทเคน AI)'],
    'pl': [
      'Przegląd zdjęć posiłków (tokeny AI)',
      'Szacowanie odżywiania ze zdjęć (tokeny AI)',
    ],
    'nl': [
      'Maaltijdfoto beoordelen (AI-tokens)',
      'Voedingsschattingen uit foto’s (AI-tokens)',
    ],
    'uk': [
      'Перегляд фото їжі (токени ШІ)',
      'Оцінка харчування за фото (токени ШІ)',
    ],
  };
}
