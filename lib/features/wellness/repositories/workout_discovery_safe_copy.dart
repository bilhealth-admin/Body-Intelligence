/// Small reviewed copy surface for localized workout discovery metadata.
///
/// Exercise names are deliberately not translated here. The owner-approved
/// name policy lives in [WorkoutDiscoveryLocalizer]: canonical English in all
/// locales, plus a phonetic Arabic line for Arabic.
final class WorkoutDiscoverySafeCopy {
  const WorkoutDiscoverySafeCopy({
    required this.descriptionPattern,
    required this.noEquipment,
    required this.equipmentCountPattern,
  });

  final String descriptionPattern;
  final String noEquipment;
  final String equipmentCountPattern;

  String description(String groupTitle) =>
      descriptionPattern.replaceFirst('{section}', groupTitle);

  String equipmentCount(int count) =>
      equipmentCountPattern.replaceFirst('{count}', '$count');

  static WorkoutDiscoverySafeCopy forTag(String tag) =>
      _byTag[tag] ??
      (throw StateError('Missing safe workout discovery copy for $tag.'));

  static Set<String> get supportedTags => _byTag.keys.toSet();

  static const _byTag = <String, WorkoutDiscoverySafeCopy>{
    'ar': WorkoutDiscoverySafeCopy(
      descriptionPattern: 'فيديو تمرين مُراجع ضمن قسم {section}.',
      noEquipment: 'دون معدات',
      equipmentCountPattern: 'عدد عناصر المعدات: {count}',
    ),
    'fr': WorkoutDiscoverySafeCopy(
      descriptionPattern:
          'Vidéo d’entraînement vérifiée dans la section {section}.',
      noEquipment: 'Sans matériel',
      equipmentCountPattern: 'Nombre d’éléments : {count}',
    ),
    'es': WorkoutDiscoverySafeCopy(
      descriptionPattern:
          'Vídeo de entrenamiento revisado de la sección {section}.',
      noEquipment: 'Sin equipo',
      equipmentCountPattern: 'Número de elementos: {count}',
    ),
    'tr': WorkoutDiscoverySafeCopy(
      descriptionPattern: '{section} bölümünde incelenmiş antrenman videosu.',
      noEquipment: 'Ekipman gerekmez',
      equipmentCountPattern: 'Ekipman sayısı: {count}',
    ),
    'de': WorkoutDiscoverySafeCopy(
      descriptionPattern: 'Geprüftes Trainingsvideo im Bereich {section}.',
      noEquipment: 'Keine Ausrüstung',
      equipmentCountPattern: 'Anzahl der Teile: {count}',
    ),
    'it': WorkoutDiscoverySafeCopy(
      descriptionPattern:
          'Video di allenamento verificato nella sezione {section}.',
      noEquipment: 'Nessuna attrezzatura',
      equipmentCountPattern: 'Numero di elementi: {count}',
    ),
    'pt-BR': WorkoutDiscoverySafeCopy(
      descriptionPattern: 'Vídeo de treino revisado na seção {section}.',
      noEquipment: 'Sem equipamento',
      equipmentCountPattern: 'Quantidade de itens: {count}',
    ),
    'pt-PT': WorkoutDiscoverySafeCopy(
      descriptionPattern: 'Vídeo de treino revisto na secção {section}.',
      noEquipment: 'Sem equipamento',
      equipmentCountPattern: 'Número de itens: {count}',
    ),
    'ur': WorkoutDiscoverySafeCopy(
      descriptionPattern: '{section} حصے میں جائزہ شدہ ورزش کی ویڈیو۔',
      noEquipment: 'کسی سامان کی ضرورت نہیں',
      equipmentCountPattern: 'سامان کی تعداد: {count}',
    ),
    'fa': WorkoutDiscoverySafeCopy(
      descriptionPattern: 'ویدیوی تمرین بررسی‌شده در بخش {section}.',
      noEquipment: 'بدون تجهیزات',
      equipmentCountPattern: 'تعداد وسایل: {count}',
    ),
    'hi': WorkoutDiscoverySafeCopy(
      descriptionPattern: '{section} अनुभाग में समीक्षित वर्कआउट वीडियो।',
      noEquipment: 'किसी उपकरण की आवश्यकता नहीं',
      equipmentCountPattern: 'उपकरणों की संख्या: {count}',
    ),
    'id': WorkoutDiscoverySafeCopy(
      descriptionPattern: 'Video latihan yang ditinjau di bagian {section}.',
      noEquipment: 'Tanpa peralatan',
      equipmentCountPattern: 'Jumlah perlengkapan: {count}',
    ),
    'ms': WorkoutDiscoverySafeCopy(
      descriptionPattern:
          'Video senaman yang disemak dalam bahagian {section}.',
      noEquipment: 'Tanpa peralatan',
      equipmentCountPattern: 'Bilangan peralatan: {count}',
    ),
    'ja': WorkoutDiscoverySafeCopy(
      descriptionPattern: '{section}の審査済みワークアウト動画です。',
      noEquipment: '器具なし',
      equipmentCountPattern: '器具の数：{count}',
    ),
    'ko': WorkoutDiscoverySafeCopy(
      descriptionPattern: '{section} 섹션의 검토된 운동 영상입니다.',
      noEquipment: '기구 없음',
      equipmentCountPattern: '기구 수: {count}',
    ),
    'zh-Hans': WorkoutDiscoverySafeCopy(
      descriptionPattern: '{section}分类中的已审核训练视频。',
      noEquipment: '无需器材',
      equipmentCountPattern: '器材数量：{count}',
    ),
    'zh-Hant': WorkoutDiscoverySafeCopy(
      descriptionPattern: '{section}分類中的已審核訓練影片。',
      noEquipment: '無需器材',
      equipmentCountPattern: '器材數量：{count}',
    ),
    'ru': WorkoutDiscoverySafeCopy(
      descriptionPattern: 'Проверенное видео тренировки в разделе «{section}».',
      noEquipment: 'Без оборудования',
      equipmentCountPattern: 'Количество предметов: {count}',
    ),
    'bn': WorkoutDiscoverySafeCopy(
      descriptionPattern: '{section} বিভাগে পর্যালোচিত ওয়ার্কআউট ভিডিও।',
      noEquipment: 'কোনো সরঞ্জাম লাগবে না',
      equipmentCountPattern: 'সরঞ্জামের সংখ্যা: {count}',
    ),
    'vi': WorkoutDiscoverySafeCopy(
      descriptionPattern: 'Video tập luyện đã được duyệt trong mục {section}.',
      noEquipment: 'Không cần dụng cụ',
      equipmentCountPattern: 'Số dụng cụ: {count}',
    ),
    'th': WorkoutDiscoverySafeCopy(
      descriptionPattern: 'วิดีโอออกกำลังกายที่ผ่านการตรวจสอบในหมวด {section}',
      noEquipment: 'ไม่ใช้อุปกรณ์',
      equipmentCountPattern: 'จำนวนอุปกรณ์: {count}',
    ),
    'pl': WorkoutDiscoverySafeCopy(
      descriptionPattern: 'Sprawdzony film treningowy w sekcji „{section}”.',
      noEquipment: 'Bez sprzętu',
      equipmentCountPattern: 'Liczba elementów: {count}',
    ),
    'nl': WorkoutDiscoverySafeCopy(
      descriptionPattern:
          'Gecontroleerde trainingsvideo in de sectie {section}.',
      noEquipment: 'Geen apparatuur',
      equipmentCountPattern: 'Aantal onderdelen: {count}',
    ),
    'uk': WorkoutDiscoverySafeCopy(
      descriptionPattern: 'Перевірене відео тренування в розділі «{section}».',
      noEquipment: 'Без обладнання',
      equipmentCountPattern: 'Кількість предметів: {count}',
    ),
  };
}
