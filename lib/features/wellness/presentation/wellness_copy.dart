import 'package:flutter/widgets.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy_accessibility_wellness.dart';

part 'wellness_copy_catalog_a.dart';
part 'wellness_copy_catalog_b.dart';
part 'wellness_engine_locale_copy.dart';

abstract final class WellnessCopyCatalog {
  static const supportedLanguageCodes = {'ar', 'en', 'fr', 'es', 'tr'};
  static const secondaryLanguageCodes = {'fr', 'es', 'tr'};

  static bool get catalogsBalanced => _wellnessSecondary.values.every(
    (translations) =>
        translations.keys.toSet().containsAll(secondaryLanguageCodes) &&
        secondaryLanguageCodes.containsAll(translations.keys),
  );
}

String wellnessVerifiedWorkoutVideoCount(BuildContext context, int count) {
  return AccessibilityWellnessRuntimeCopy.verifiedWorkoutVideoCount(
    count,
    BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
  );
}

/// Shared destination name used by both discovery and the workout AppBar.
String wellnessWorkoutVideosAndRoutinesTitle(BuildContext context) {
  final tag = BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
  return _workoutVideosAndRoutinesTitles[tag] ??
      _workoutVideosAndRoutinesTitles['en']!;
}

const _workoutVideosAndRoutinesTitles = <String, String>{
  'ar': 'فيديوهات وروتينات التمارين',
  'en': 'Workout Videos & Routines',
  'fr': 'Vidéos et routines d’entraînement',
  'es': 'Vídeos y rutinas de entrenamiento',
  'tr': 'Egzersiz videoları ve rutinleri',
  'de': 'Trainingsvideos & Trainingspläne',
  'it': 'Video e routine di allenamento',
  'pt-BR': 'Vídeos e rotinas de treino',
  'pt-PT': 'Vídeos e rotinas de treino',
  'ur': 'ورزش کی ویڈیوز اور روٹینز',
  'fa': 'ویدیوها و برنامه‌های تمرینی',
  'hi': 'वर्कआउट वीडियो और रूटीन',
  'id': 'Video & rutinitas latihan',
  'ms': 'Video & rutin senaman',
  'ja': 'ワークアウト動画とルーティン',
  'ko': '운동 영상 및 루틴',
  'zh-Hans': '训练视频和训练计划',
  'zh-Hant': '訓練影片與訓練計畫',
  'ru': 'Видео и программы тренировок',
  'bn': 'ওয়ার্কআউট ভিডিও ও রুটিন',
  'vi': 'Video và giáo án tập luyện',
  'th': 'วิดีโอและโปรแกรมออกกำลังกาย',
  'pl': 'Filmy i plany treningowe',
  'nl': "Trainingsvideo's en routines",
  'uk': 'Відео та програми тренувань',
};

/// Compact localized controls for on-demand workout video transfer.
String wellnessWorkoutVideoAction(BuildContext context, String action) {
  final tag = BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
  return _workoutVideoActions[action]?[tag] ??
      _workoutVideoActions[action]?['en'] ??
      action;
}

const _workoutVideoActions = <String, Map<String, String>>{
  'Play video': {
    'ar': 'تشغيل الفيديو',
    'en': 'Play video',
    'fr': 'Lire la vidéo',
    'es': 'Reproducir vídeo',
    'tr': 'Videoyu oynat',
    'de': 'Video abspielen',
    'it': 'Riproduci video',
    'pt-BR': 'Reproduzir vídeo',
    'pt-PT': 'Reproduzir vídeo',
    'ur': 'ویڈیو چلائیں',
    'fa': 'پخش ویدیو',
    'hi': 'वीडियो चलाएँ',
    'id': 'Putar video',
    'ms': 'Mainkan video',
    'ja': '動画を再生',
    'ko': '동영상 재생',
    'zh-Hans': '播放视频',
    'zh-Hant': '播放影片',
    'ru': 'Воспроизвести видео',
    'bn': 'ভিডিও চালান',
    'vi': 'Phát video',
    'th': 'เล่นวิดีโอ',
    'pl': 'Odtwórz film',
    'nl': 'Video afspelen',
    'uk': 'Відтворити відео',
  },
  'Pause video': {
    'ar': 'إيقاف الفيديو مؤقتًا',
    'en': 'Pause video',
    'fr': 'Mettre la vidéo en pause',
    'es': 'Pausar vídeo',
    'tr': 'Videoyu duraklat',
    'de': 'Video pausieren',
    'it': 'Metti in pausa',
    'pt-BR': 'Pausar vídeo',
    'pt-PT': 'Pausar vídeo',
    'ur': 'ویڈیو روکیں',
    'fa': 'مکث ویدیو',
    'hi': 'वीडियो रोकें',
    'id': 'Jeda video',
    'ms': 'Jeda video',
    'ja': '動画を一時停止',
    'ko': '동영상 일시중지',
    'zh-Hans': '暂停视频',
    'zh-Hant': '暫停影片',
    'ru': 'Приостановить видео',
    'bn': 'ভিডিও বিরতি দিন',
    'vi': 'Tạm dừng video',
    'th': 'หยุดวิดีโอชั่วคราว',
    'pl': 'Wstrzymaj film',
    'nl': 'Video pauzeren',
    'uk': 'Призупинити відео',
  },
  'Download': {
    'ar': 'تنزيل',
    'en': 'Download',
    'fr': 'Télécharger',
    'es': 'Descargar',
    'tr': 'İndir',
    'de': 'Herunterladen',
    'it': 'Scarica',
    'pt-BR': 'Baixar',
    'pt-PT': 'Transferir',
    'ur': 'ڈاؤن لوڈ کریں',
    'fa': 'دانلود',
    'hi': 'डाउनलोड करें',
    'id': 'Unduh',
    'ms': 'Muat turun',
    'ja': 'ダウンロード',
    'ko': '다운로드',
    'zh-Hans': '下载',
    'zh-Hant': '下載',
    'ru': 'Скачать',
    'bn': 'ডাউনলোড',
    'vi': 'Tải xuống',
    'th': 'ดาวน์โหลด',
    'pl': 'Pobierz',
    'nl': 'Downloaden',
    'uk': 'Завантажити',
  },
  'Remove download': {
    'ar': 'إزالة التنزيل',
    'en': 'Remove download',
    'fr': 'Supprimer le téléchargement',
    'es': 'Eliminar descarga',
    'tr': 'İndirmeyi sil',
    'de': 'Download entfernen',
    'it': 'Rimuovi download',
    'pt-BR': 'Remover download',
    'pt-PT': 'Remover transferência',
    'ur': 'ڈاؤن لوڈ ہٹائیں',
    'fa': 'حذف دانلود',
    'hi': 'डाउनलोड हटाएँ',
    'id': 'Hapus unduhan',
    'ms': 'Padam muat turun',
    'ja': 'ダウンロードを削除',
    'ko': '다운로드 삭제',
    'zh-Hans': '删除下载',
    'zh-Hant': '刪除下載',
    'ru': 'Удалить загрузку',
    'bn': 'ডাউনলোড মুছুন',
    'vi': 'Xóa bản tải xuống',
    'th': 'ลบการดาวน์โหลด',
    'pl': 'Usuń pobrany plik',
    'nl': 'Download verwijderen',
    'uk': 'Видалити завантаження',
  },
};

String wellnessCopy(BuildContext context, String english, String arabic) {
  final code = Localizations.localeOf(context).languageCode.toLowerCase();
  if (code == 'ar') return arabic;
  if (code == 'en') return english;

  final engineCopy =
      _wellnessEngineCorePatch[english]?[code] ??
      _wellnessEngineExtended[english]?[code];
  if (engineCopy != null) return engineCopy;

  final recipeCount = RegExp(r'^(\d+) of (\d+) recipes$').firstMatch(english);
  if (recipeCount != null) {
    return context.strings
        .text('{visible} of {total} recipes')
        .replaceFirst('{visible}', recipeCount.group(1)!)
        .replaceFirst('{total}', recipeCount.group(2)!);
  }
  final minutesOnly = RegExp(r'^(\d+) min$').firstMatch(english);
  if (minutesOnly != null) {
    return context.strings
        .text('{count} min')
        .replaceFirst('{count}', minutesOnly.group(1)!);
  }
  final originalLanguage = RegExp(
    r'^Original · ([A-Z-]+)$',
  ).firstMatch(english);
  if (originalLanguage != null) {
    return context.strings
        .text('Original · {language}')
        .replaceFirst('{language}', originalLanguage.group(1)!);
  }

  String dynamicCopy(String prefix, String suffix) => switch (code) {
    'fr' => '$prefix$suffix',
    'es' => '$prefix$suffix',
    'tr' => '$prefix$suffix',
    _ => english,
  };

  if (english.startsWith('Recorded today: ')) {
    final value = english.substring('Recorded today: '.length);
    if (!WellnessCopyCatalog.supportedLanguageCodes.contains(code)) {
      return context.strings
          .text('Recorded today: {value}')
          .replaceFirst('{value}', value);
    }
    return dynamicCopy(switch (code) {
      'fr' => "Enregistré aujourd’hui : ",
      'es' => 'Registrado hoy: ',
      'tr' => 'Bugün kaydedilen: ',
      _ => '',
    }, value);
  }
  if (english.startsWith('Duration: ')) {
    final value = english.substring('Duration: '.length);
    if (!WellnessCopyCatalog.supportedLanguageCodes.contains(code)) {
      return context.strings
          .text('Duration: {value}')
          .replaceFirst('{value}', value);
    }
    return dynamicCopy(switch (code) {
      'fr' => 'Durée : ',
      'es' => 'Duración: ',
      'tr' => 'Süre: ',
      _ => '',
    }, value);
  }
  if (english.startsWith('of ') && english.endsWith(' hours')) {
    final value = english.substring(3, english.length - 6);
    return switch (code) {
      'fr' => 'sur $value heures',
      'es' => 'de $value horas',
      'tr' => '$value saatin',
      _ =>
        context.strings.text('of {value} hours').replaceFirst('{value}', value),
    };
  }
  if (english.contains(' recorded nights · ') &&
      english.endsWith(' h average')) {
    final parts = english.split(' recorded nights · ');
    final average = parts[1].replaceFirst(' h average', '');
    return switch (code) {
      'fr' => '${parts[0]} nuits enregistrées · moyenne $average h',
      'es' => '${parts[0]} noches registradas · media de $average h',
      'tr' => '${parts[0]} kayıtlı gece · ortalama $average sa',
      _ =>
        context.strings
            .text('{count} recorded nights · {average} h average')
            .replaceFirst('{count}', parts[0])
            .replaceFirst('{average}', average),
    };
  }
  final recipeSummary = RegExp(
    r'^(\d+) min • (\d+) ingredients$',
  ).firstMatch(english);
  if (recipeSummary != null) {
    final minutes = recipeSummary.group(1);
    final count = recipeSummary.group(2);
    return switch (code) {
      'fr' => '$minutes min • $count ingrédients',
      'es' => '$minutes min • $count ingredientes',
      'tr' => '$minutes dk • $count malzeme',
      _ =>
        context.strings
            .text('{minutes} min • {count} ingredients')
            .replaceFirst('{minutes}', minutes!)
            .replaceFirst('{count}', count!),
    };
  }
  final guidance = RegExp(
    r'^(\d+) minutes • guidance quantities$',
  ).firstMatch(english);
  if (guidance != null) {
    final minutes = guidance.group(1);
    return switch (code) {
      'fr' => '$minutes minutes • quantités indicatives',
      'es' => '$minutes minutos • cantidades orientativas',
      'tr' => '$minutes dakika • rehber miktarlar',
      _ =>
        context.strings
            .text('{minutes} minutes • guidance quantities')
            .replaceFirst('{minutes}', minutes!),
    };
  }

  return _wellnessSecondary[english]?[code] ?? context.strings.text(english);
}

const _wellnessSecondary = <String, Map<String, String>>{
  ..._wellnessSecondaryA,
  ..._wellnessSecondaryB,
};
