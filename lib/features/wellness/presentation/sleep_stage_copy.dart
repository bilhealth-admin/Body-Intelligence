import 'package:flutter/widgets.dart';

import '../../../app/localization/bil_locale_policy.dart';

/// Presentation only: HealthKit's raw stage keys and measured duration remain
/// unchanged. Unknown provider keys are not converted into a known sleep stage.
String wellnessSleepStageLabel(BuildContext context, String stage) {
  final tag = BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
  final copy = _sleepStages[tag] ?? _sleepStages['en']!;
  return switch (stage) {
    'asleepUnspecified' => copy.unspecified,
    'core' => copy.core,
    'deep' => copy.deep,
    'rem' => copy.rem,
    _ => copy.unavailable,
  };
}

String wellnessSleepMeasuredByLabel(BuildContext context) {
  final tag = BilLocalePolicy.canonicalTag(Localizations.localeOf(context));
  return _measuredBy[tag] ?? _measuredBy['en']!;
}

const _measuredBy = <String, String>{
  'en': 'Measured by',
  'ar': 'مقاس بواسطة',
  'fr': 'Mesuré par',
  'es': 'Medido por',
  'tr': 'Ölçüm kaynağı',
  'de': 'Gemessen von',
  'it': 'Misurato da',
  'pt-BR': 'Medido por',
  'pt-PT': 'Medido por',
  'ur': 'پیمائش کا ذریعہ',
  'fa': 'اندازه‌گیری توسط',
  'hi': 'मापन का स्रोत',
  'id': 'Diukur oleh',
  'ms': 'Diukur oleh',
  'ja': '測定元',
  'ko': '측정 기기',
  'zh-Hans': '测量来源',
  'zh-Hant': '測量來源',
  'ru': 'Источник измерения',
  'bn': 'পরিমাপের উৎস',
  'vi': 'Được đo bởi',
  'th': 'วัดโดย',
  'pl': 'Źródło pomiaru',
  'nl': 'Gemeten door',
  'uk': 'Джерело вимірювання',
};

typedef _SleepStageLabels = ({
  String unspecified,
  String core,
  String deep,
  String rem,
  String unavailable,
});

const _sleepStages = <String, _SleepStageLabels>{
  'en': (
    unspecified: 'Sleep (stage unspecified)',
    core: 'Core sleep',
    deep: 'Deep sleep',
    rem: 'REM sleep',
    unavailable: 'Sleep stage unavailable',
  ),
  'ar': (
    unspecified: 'نوم (المرحلة غير محددة)',
    core: 'النوم الأساسي',
    deep: 'النوم العميق',
    rem: 'نوم حركة العين السريعة',
    unavailable: 'مرحلة النوم غير متاحة',
  ),
  'fr': (
    unspecified: 'Sommeil (phase non précisée)',
    core: 'Sommeil de base',
    deep: 'Sommeil profond',
    rem: 'Sommeil paradoxal',
    unavailable: 'Phase de sommeil indisponible',
  ),
  'es': (
    unspecified: 'Sueño (fase no especificada)',
    core: 'Sueño esencial',
    deep: 'Sueño profundo',
    rem: 'Sueño REM',
    unavailable: 'Fase de sueño no disponible',
  ),
  'tr': (
    unspecified: 'Uyku (evre belirtilmemiş)',
    core: 'Temel uyku',
    deep: 'Derin uyku',
    rem: 'REM uykusu',
    unavailable: 'Uyku evresi mevcut değil',
  ),
  'de': (
    unspecified: 'Schlaf (Phase nicht angegeben)',
    core: 'Kernschlaf',
    deep: 'Tiefschlaf',
    rem: 'REM-Schlaf',
    unavailable: 'Schlafphase nicht verfügbar',
  ),
  'it': (
    unspecified: 'Sonno (fase non specificata)',
    core: 'Sonno di base',
    deep: 'Sonno profondo',
    rem: 'Sonno REM',
    unavailable: 'Fase del sonno non disponibile',
  ),
  'pt-BR': (
    unspecified: 'Sono (fase não especificada)',
    core: 'Sono essencial',
    deep: 'Sono profundo',
    rem: 'Sono REM',
    unavailable: 'Fase do sono indisponível',
  ),
  'pt-PT': (
    unspecified: 'Sono (fase não especificada)',
    core: 'Sono essencial',
    deep: 'Sono profundo',
    rem: 'Sono REM',
    unavailable: 'Fase do sono indisponível',
  ),
  'ur': (
    unspecified: 'نیند (مرحلہ غیر متعین)',
    core: 'بنیادی نیند',
    deep: 'گہری نیند',
    rem: 'تیز حرکتِ چشم کی نیند',
    unavailable: 'نیند کا مرحلہ دستیاب نہیں',
  ),
  'fa': (
    unspecified: 'خواب (مرحله نامشخص)',
    core: 'خواب پایه',
    deep: 'خواب عمیق',
    rem: 'خواب با حرکت سریع چشم',
    unavailable: 'مرحله خواب در دسترس نیست',
  ),
  'hi': (
    unspecified: 'नींद (चरण निर्दिष्ट नहीं)',
    core: 'मूल नींद',
    deep: 'गहरी नींद',
    rem: 'तेज़ नेत्र गति वाली नींद',
    unavailable: 'नींद का चरण उपलब्ध नहीं',
  ),
  'id': (
    unspecified: 'Tidur (tahap tidak ditentukan)',
    core: 'Tidur inti',
    deep: 'Tidur dalam',
    rem: 'Tidur REM',
    unavailable: 'Tahap tidur tidak tersedia',
  ),
  'ms': (
    unspecified: 'Tidur (peringkat tidak dinyatakan)',
    core: 'Tidur teras',
    deep: 'Tidur nyenyak',
    rem: 'Tidur REM',
    unavailable: 'Peringkat tidur tidak tersedia',
  ),
  'ja': (
    unspecified: '睡眠（段階の指定なし）',
    core: 'コア睡眠',
    deep: '深い睡眠',
    rem: 'レム睡眠',
    unavailable: '睡眠段階を確認できません',
  ),
  'ko': (
    unspecified: '수면 (단계 미지정)',
    core: '코어 수면',
    deep: '깊은 수면',
    rem: '렘수면',
    unavailable: '수면 단계 정보 없음',
  ),
  'zh-Hans': (
    unspecified: '睡眠（阶段未指定）',
    core: '核心睡眠',
    deep: '深度睡眠',
    rem: '快速眼动睡眠',
    unavailable: '睡眠阶段不可用',
  ),
  'zh-Hant': (
    unspecified: '睡眠（階段未指定）',
    core: '核心睡眠',
    deep: '深度睡眠',
    rem: '快速動眼睡眠',
    unavailable: '睡眠階段無法取得',
  ),
  'ru': (
    unspecified: 'Сон (стадия не указана)',
    core: 'Базовый сон',
    deep: 'Глубокий сон',
    rem: 'Сон с быстрыми движениями глаз',
    unavailable: 'Стадия сна недоступна',
  ),
  'bn': (
    unspecified: 'ঘুম (পর্যায় অনির্দিষ্ট)',
    core: 'মূল ঘুম',
    deep: 'গভীর ঘুম',
    rem: 'দ্রুত চোখের নড়াচড়ার ঘুম',
    unavailable: 'ঘুমের পর্যায় উপলব্ধ নয়',
  ),
  'vi': (
    unspecified: 'Ngủ (chưa xác định giai đoạn)',
    core: 'Giấc ngủ cơ bản',
    deep: 'Giấc ngủ sâu',
    rem: 'Giấc ngủ chuyển động mắt nhanh',
    unavailable: 'Không có thông tin giai đoạn ngủ',
  ),
  'th': (
    unspecified: 'การนอนหลับ (ไม่ระบุระยะ)',
    core: 'การนอนหลับระยะหลัก',
    deep: 'การหลับลึก',
    rem: 'การนอนหลับระยะกลอกตาเร็ว',
    unavailable: 'ไม่มีข้อมูลระยะการนอนหลับ',
  ),
  'pl': (
    unspecified: 'Sen (faza nieokreślona)',
    core: 'Sen podstawowy',
    deep: 'Sen głęboki',
    rem: 'Sen REM',
    unavailable: 'Faza snu niedostępna',
  ),
  'nl': (
    unspecified: 'Slaap (fase niet gespecificeerd)',
    core: 'Kernslaap',
    deep: 'Diepe slaap',
    rem: 'Remslaap',
    unavailable: 'Slaapfase niet beschikbaar',
  ),
  'uk': (
    unspecified: 'Сон (стадію не вказано)',
    core: 'Базовий сон',
    deep: 'Глибокий сон',
    rem: 'Сон зі швидкими рухами очей',
    unavailable: 'Стадія сну недоступна',
  ),
};
