import 'package:flutter/widgets.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';

class MealVisionUiCopy {
  const MealVisionUiCopy(this.values);
  final Map<String, String> values;
  String text(String key) => values[key] ?? _all['en']!.values[key] ?? key;
  static MealVisionUiCopy of(String language) => _all[language] ?? _all['en']!;

  static MealVisionUiCopy ofLocale(Locale locale) {
    final primary = _all[locale.languageCode];
    if (primary != null) return primary;
    final english = _all['en']!.values;
    final tag = BilLocalePolicy.canonicalTag(locale);
    return MealVisionUiCopy({
      for (final entry in english.entries)
        entry.key: RuntimeCopy.resolve(entry.value, tag) ?? entry.value,
    });
  }

  static const _all = <String, MealVisionUiCopy>{
    'en': MealVisionUiCopy({
      'unavailable': 'Image analysis unavailable',
      'ok': 'OK',
      'take': 'Take a photo',
      'choose': 'Choose from device',
      'camera_failed':
          'Camera or photo access failed. Check permission and try again.',
      'none':
          'No reliable food was visible. Nothing was added; use food search instead.',
      'review': 'Review image suggestions',
      'no_match':
          'No trusted nutrition record matched this suggestion. Nothing was added.',
      'confirmed_added':
          'Only the foods you reviewed and confirmed were added.',
      'select_match': 'Select the verified food match',
      'select_notice':
          'Review the serving and source. Nothing is logged until you choose.',
      'unit_mismatch': 'The amount unit must match the trusted serving unit',
      'cancel': 'Cancel',
    }),
    'ar': MealVisionUiCopy({
      'unavailable': 'تحليل الصورة غير متاح',
      'ok': 'حسنًا',
      'take': 'التقط صورة',
      'choose': 'اختر من الجهاز',
      'camera_failed':
          'تعذر فتح الكاميرا أو مكتبة الصور. تحقق من الإذن ثم حاول مجددًا.',
      'none':
          'لم يظهر طعام موثوق. لم تتم إضافة أي شيء؛ استخدم البحث عن الطعام.',
      'review': 'راجع اقتراحات الصورة',
      'no_match': 'لا يوجد سجل غذائي موثوق يطابق هذا الاقتراح. لم تتم إضافته.',
      'confirmed_added': 'تمت إضافة الأطعمة التي راجعتها وأكدتها فقط.',
      'select_match': 'اختر سجل الطعام الموثّق',
      'select_notice': 'راجع الحصة والمصدر. لن يُسجّل شيء حتى تختار.',
      'unit_mismatch': 'يجب أن تطابق وحدة الكمية وحدة الحصة الموثوقة',
      'cancel': 'إلغاء',
    }),
    'fr': MealVisionUiCopy({
      'unavailable': 'Analyse d’image indisponible',
      'ok': 'OK',
      'take': 'Prendre une photo',
      'choose': 'Choisir sur l’appareil',
      'camera_failed':
          'Impossible d’ouvrir l’appareil photo ou la photothèque. Vérifiez l’autorisation et réessayez.',
      'none':
          'Aucun aliment fiable n’est visible. Rien n’a été ajouté ; utilisez la recherche.',
      'review': 'Vérifier les suggestions de l’image',
      'no_match':
          'Aucune fiche nutritionnelle fiable ne correspond. Rien n’a été ajouté.',
      'confirmed_added':
          'Seuls les aliments vérifiés et confirmés ont été ajoutés.',
      'select_match': 'Sélectionner l’aliment vérifié',
      'select_notice':
          'Vérifiez la portion et la source. Rien n’est enregistré avant votre choix.',
      'unit_mismatch': 'L’unité doit correspondre à l’unité de portion fiable',
      'cancel': 'Annuler',
    }),
    'es': MealVisionUiCopy({
      'unavailable': 'Análisis de imagen no disponible',
      'ok': 'Aceptar',
      'take': 'Tomar una foto',
      'choose': 'Elegir del dispositivo',
      'camera_failed':
          'No se pudo abrir la cámara o la galería. Comprueba el permiso e inténtalo de nuevo.',
      'none':
          'No se detectó comida fiable. No se añadió nada; usa la búsqueda de alimentos.',
      'review': 'Revisar sugerencias de la imagen',
      'no_match':
          'No coincide con ningún registro nutricional fiable. No se añadió.',
      'confirmed_added':
          'Solo se añadieron los alimentos revisados y confirmados.',
      'select_match': 'Seleccionar el alimento verificado',
      'select_notice':
          'Revisa la porción y la fuente. No se registra nada hasta que elijas.',
      'unit_mismatch':
          'La unidad debe coincidir con la unidad de porción fiable',
      'cancel': 'Cancelar',
    }),
    'tr': MealVisionUiCopy({
      'unavailable': 'Görsel analizi kullanılamıyor',
      'ok': 'Tamam',
      'take': 'Fotoğraf çek',
      'choose': 'Cihazdan seç',
      'camera_failed':
          'Kamera veya fotoğraf kitaplığı açılamadı. İzni kontrol edip yeniden deneyin.',
      'none':
          'Güvenilir yiyecek görünmedi. Hiçbir şey eklenmedi; yiyecek aramasını kullanın.',
      'review': 'Görsel önerilerini incele',
      'no_match': 'Güvenilir bir besin kaydı eşleşmedi. Hiçbir şey eklenmedi.',
      'confirmed_added': 'Yalnızca inceleyip onayladığınız yiyecekler eklendi.',
      'select_match': 'Doğrulanmış yiyeceği seç',
      'select_notice':
          'Porsiyonu ve kaynağı inceleyin. Siz seçene kadar hiçbir şey kaydedilmez.',
      'unit_mismatch': 'Birim güvenilir porsiyon birimiyle eşleşmelidir',
      'cancel': 'İptal',
    }),
  };
}
