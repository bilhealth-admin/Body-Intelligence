part of 'workout_video_group_copy.dart';

/// Reviewed copy for the metadata-only workout discovery state.
///
/// Every production locale has an authored row. A missing production row is
/// an integration error instead of a silent English fallback.
final class WorkoutRoutinesStateCopy {
  const WorkoutRoutinesStateCopy({
    required this.exploreStyles,
    required this.previewExplanation,
    required this.manageReviewedPacks,
    required this.offlineExplanation,
    required this.metadataPreviewLabel,
  });

  final String exploreStyles;
  final String previewExplanation;
  final String manageReviewedPacks;
  final String offlineExplanation;
  final String metadataPreviewLabel;

  static WorkoutRoutinesStateCopy of(BuildContext context) =>
      forTag(BilLocalePolicy.canonicalTag(Localizations.localeOf(context)));

  static WorkoutRoutinesStateCopy forTag(String localeTag) {
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    if (tag == null) return _all['en']!;
    return _all[tag] ??
        (throw StateError('Missing workout routine state copy for $tag.'));
  }

  static Set<String> get supportedTags => _all.keys.toSet();

  static const _all = <String, WorkoutRoutinesStateCopy>{
    'ar': WorkoutRoutinesStateCopy(
      exploreStyles: 'استكشف أنماط التمارين',
      previewExplanation:
          'معاينات أصلية من BIL. سجّل نشاطًا الآن، أو ثبّت حزمة مراجعة للروتينات الموجّهة. لا يتوفر فيديو من المعاينة.',
      manageReviewedPacks: 'إدارة الحزم المراجعة',
      offlineExplanation:
          'دون اتصال: لا توفر الروتينات الموجّهة إلا الحزم المراجعة المثبتة مسبقًا.',
      metadataPreviewLabel: 'معاينة بيانات؛ لا يوجد فيديو قابل للتشغيل',
    ),
    'en': WorkoutRoutinesStateCopy(
      exploreStyles: 'Explore workout styles',
      previewExplanation:
          'Original BIL previews. Log an activity now, or install a reviewed pack for guided routines. No video is available from a preview.',
      manageReviewedPacks: 'Manage reviewed packs',
      offlineExplanation:
          'Offline: only previously installed reviewed packs can provide guided routines.',
      metadataPreviewLabel: 'Metadata preview; no playable video',
    ),
    'fr': WorkoutRoutinesStateCopy(
      exploreStyles: 'Explorez les styles d’entraînement',
      previewExplanation:
          'Aperçus BIL originaux. Enregistrez une activité maintenant ou installez un pack vérifié pour suivre des routines guidées. Les aperçus ne contiennent aucune vidéo.',
      manageReviewedPacks: 'Gérer les packs vérifiés',
      offlineExplanation:
          'Hors ligne : seuls les packs vérifiés déjà installés peuvent fournir des routines guidées.',
      metadataPreviewLabel: 'Aperçu des métadonnées ; aucune vidéo à lire',
    ),
    'es': WorkoutRoutinesStateCopy(
      exploreStyles: 'Explora estilos de entrenamiento',
      previewExplanation:
          'Vistas previas originales de BIL. Registra una actividad ahora o instala un paquete revisado para acceder a rutinas guiadas. Las vistas previas no incluyen vídeo.',
      manageReviewedPacks: 'Gestionar paquetes revisados',
      offlineExplanation:
          'Sin conexión: solo los paquetes revisados instalados previamente pueden ofrecer rutinas guiadas.',
      metadataPreviewLabel:
          'Vista previa de metadatos; no hay vídeo reproducible',
    ),
    'tr': WorkoutRoutinesStateCopy(
      exploreStyles: 'Antrenman tarzlarını keşfet',
      previewExplanation:
          'Orijinal BIL önizlemeleri. Şimdi bir etkinlik kaydedin veya rehberli rutinler için incelenmiş bir paket yükleyin. Önizlemelerde video bulunmaz.',
      manageReviewedPacks: 'İncelenmiş paketleri yönet',
      offlineExplanation:
          'Çevrimdışı: Yalnızca önceden yüklenmiş, incelenmiş paketler rehberli rutinler sunabilir.',
      metadataPreviewLabel: 'Meta veri önizlemesi; oynatılabilir video yok',
    ),
    'de': WorkoutRoutinesStateCopy(
      exploreStyles: 'Trainingsstile entdecken',
      previewExplanation:
          'Originale BIL-Vorschauen. Protokolliere jetzt eine Aktivität oder installiere ein geprüftes Paket für angeleitete Routinen. Vorschauen enthalten kein Video.',
      manageReviewedPacks: 'Geprüfte Pakete verwalten',
      offlineExplanation:
          'Offline: Nur bereits installierte, geprüfte Pakete können angeleitete Routinen bereitstellen.',
      metadataPreviewLabel: 'Metadatenvorschau; kein abspielbares Video',
    ),
    'it': WorkoutRoutinesStateCopy(
      exploreStyles: 'Esplora gli stili di allenamento',
      previewExplanation:
          'Anteprime originali BIL. Registra subito un’attività oppure installa un pacchetto verificato per le routine guidate. Le anteprime non includono video.',
      manageReviewedPacks: 'Gestisci i pacchetti verificati',
      offlineExplanation:
          'Offline: solo i pacchetti verificati già installati possono fornire routine guidate.',
      metadataPreviewLabel:
          'Anteprima dei metadati; nessun video riproducibile',
    ),
    'pt-BR': WorkoutRoutinesStateCopy(
      exploreStyles: 'Explore estilos de treino',
      previewExplanation:
          'Prévias originais do BIL. Registre uma atividade agora ou instale um pacote revisado para acessar rotinas guiadas. As prévias não incluem vídeo.',
      manageReviewedPacks: 'Gerenciar pacotes revisados',
      offlineExplanation:
          'Offline: somente pacotes revisados instalados anteriormente podem oferecer rotinas guiadas.',
      metadataPreviewLabel:
          'Prévia de metadados; nenhum vídeo disponível para reprodução',
    ),
    'pt-PT': WorkoutRoutinesStateCopy(
      exploreStyles: 'Explorar estilos de treino',
      previewExplanation:
          'Pré-visualizações originais do BIL. Registe uma atividade agora ou instale um pacote revisto para aceder a rotinas guiadas. As pré-visualizações não incluem vídeo.',
      manageReviewedPacks: 'Gerir pacotes revistos',
      offlineExplanation:
          'Offline: apenas os pacotes revistos instalados anteriormente podem fornecer rotinas guiadas.',
      metadataPreviewLabel:
          'Pré-visualização de metadados; sem vídeo reproduzível',
    ),
    'ur': WorkoutRoutinesStateCopy(
      exploreStyles: 'ورزش کے انداز دریافت کریں',
      previewExplanation:
          'BIL کے اصل پیش منظر۔ ابھی کوئی سرگرمی لاگ کریں، یا رہنمائی والے معمولات کے لیے جائزہ شدہ پیک انسٹال کریں۔ پیش منظر میں کوئی ویڈیو دستیاب نہیں۔',
      manageReviewedPacks: 'جائزہ شدہ پیکس کا نظم کریں',
      offlineExplanation:
          'آف لائن: صرف پہلے سے انسٹال شدہ جائزہ شدہ پیکس رہنمائی والے معمولات فراہم کر سکتے ہیں۔',
      metadataPreviewLabel:
          'میٹا ڈیٹا کا پیش منظر؛ چلانے کے لیے کوئی ویڈیو نہیں',
    ),
    'fa': WorkoutRoutinesStateCopy(
      exploreStyles: 'سبک‌های تمرینی را کاوش کنید',
      previewExplanation:
          'پیش‌نمایش‌های اصلی BIL. اکنون یک فعالیت ثبت کنید یا برای برنامه‌های هدایت‌شده، بسته‌ای بررسی‌شده نصب کنید. پیش‌نمایش ویدیوی قابل پخشی ندارد.',
      manageReviewedPacks: 'مدیریت بسته‌های بررسی‌شده',
      offlineExplanation:
          'آفلاین: فقط بسته‌های بررسی‌شده‌ای که از قبل نصب شده‌اند می‌توانند برنامه‌های هدایت‌شده ارائه دهند.',
      metadataPreviewLabel: 'پیش‌نمایش فراداده؛ ویدیویی برای پخش نیست',
    ),
    'hi': WorkoutRoutinesStateCopy(
      exploreStyles: 'वर्कआउट की शैलियाँ देखें',
      previewExplanation:
          'BIL के मूल प्रीव्यू। अभी कोई गतिविधि लॉग करें या निर्देशित रूटीन के लिए समीक्षा किया गया पैक इंस्टॉल करें। प्रीव्यू में कोई वीडियो उपलब्ध नहीं है।',
      manageReviewedPacks: 'समीक्षा किए गए पैक प्रबंधित करें',
      offlineExplanation:
          'ऑफ़लाइन: केवल पहले से इंस्टॉल किए गए समीक्षा प्राप्त पैक ही निर्देशित रूटीन दे सकते हैं।',
      metadataPreviewLabel: 'मेटाडेटा प्रीव्यू; चलाने योग्य वीडियो नहीं',
    ),
    'id': WorkoutRoutinesStateCopy(
      exploreStyles: 'Jelajahi gaya latihan',
      previewExplanation:
          'Pratinjau asli BIL. Catat aktivitas sekarang, atau instal paket yang telah ditinjau untuk rutinitas terpandu. Pratinjau tidak menyediakan video.',
      manageReviewedPacks: 'Kelola paket yang telah ditinjau',
      offlineExplanation:
          'Offline: hanya paket yang telah ditinjau dan sudah terinstal yang dapat menyediakan rutinitas terpandu.',
      metadataPreviewLabel:
          'Pratinjau metadata; tidak ada video yang dapat diputar',
    ),
    'ms': WorkoutRoutinesStateCopy(
      exploreStyles: 'Terokai gaya senaman',
      previewExplanation:
          'Pratonton asal BIL. Log aktiviti sekarang, atau pasang pek yang telah disemak untuk rutin berpandu. Tiada video tersedia dalam pratonton.',
      manageReviewedPacks: 'Urus pek yang telah disemak',
      offlineExplanation:
          'Luar talian: hanya pek disemak yang dipasang sebelum ini boleh menyediakan rutin berpandu.',
      metadataPreviewLabel: 'Pratonton metadata; tiada video boleh dimainkan',
    ),
    'ja': WorkoutRoutinesStateCopy(
      exploreStyles: 'ワークアウトのスタイルを探す',
      previewExplanation:
          'BILオリジナルのプレビューです。今すぐアクティビティを記録するか、審査済みパックをインストールしてガイド付きルーティンを利用できます。プレビューに再生可能な動画はありません。',
      manageReviewedPacks: '審査済みパックを管理',
      offlineExplanation: 'オフライン：以前にインストールした審査済みパックだけがガイド付きルーティンを提供できます。',
      metadataPreviewLabel: 'メタデータのプレビュー（再生可能な動画なし）',
    ),
    'ko': WorkoutRoutinesStateCopy(
      exploreStyles: '운동 스타일 둘러보기',
      previewExplanation:
          'BIL 오리지널 미리보기입니다. 지금 활동을 기록하거나, 검토된 팩을 설치해 가이드 루틴을 이용하세요. 미리보기에는 재생 가능한 동영상이 없습니다.',
      manageReviewedPacks: '검토된 팩 관리',
      offlineExplanation: '오프라인: 이전에 설치한 검토된 팩만 가이드 루틴을 제공할 수 있습니다.',
      metadataPreviewLabel: '메타데이터 미리보기(재생 가능한 동영상 없음)',
    ),
    'zh-Hans': WorkoutRoutinesStateCopy(
      exploreStyles: '探索训练风格',
      previewExplanation: 'BIL 原创预览。立即记录一项活动，或安装已审核的内容包以使用指导式训练。预览不含可播放视频。',
      manageReviewedPacks: '管理已审核的内容包',
      offlineExplanation: '离线：只有之前安装的已审核内容包才能提供指导式训练。',
      metadataPreviewLabel: '元数据预览；无可播放视频',
    ),
    'zh-Hant': WorkoutRoutinesStateCopy(
      exploreStyles: '探索訓練風格',
      previewExplanation: 'BIL 原創預覽。立即記錄一項活動，或安裝已審核的內容包以使用指導式訓練。預覽不含可播放影片。',
      manageReviewedPacks: '管理已審核的內容包',
      offlineExplanation: '離線：只有之前安裝的已審核內容包才能提供指導式訓練。',
      metadataPreviewLabel: '中繼資料預覽；無可播放影片',
    ),
    'ru': WorkoutRoutinesStateCopy(
      exploreStyles: 'Изучите стили тренировок',
      previewExplanation:
          'Оригинальные превью BIL. Запишите активность сейчас или установите проверенный пакет для тренировок с инструкциями. В превью нет доступного для воспроизведения видео.',
      manageReviewedPacks: 'Управление проверенными пакетами',
      offlineExplanation:
          'Без сети: тренировки с инструкциями доступны только из ранее установленных проверенных пакетов.',
      metadataPreviewLabel:
          'Предпросмотр метаданных; видео для воспроизведения нет',
    ),
    'bn': WorkoutRoutinesStateCopy(
      exploreStyles: 'ওয়ার্কআউটের ধরন দেখুন',
      previewExplanation:
          'BIL-এর নিজস্ব প্রিভিউ। এখনই একটি কার্যকলাপ লগ করুন, অথবা নির্দেশিত রুটিনের জন্য পর্যালোচিত প্যাক ইনস্টল করুন। প্রিভিউতে চালানোর মতো ভিডিও নেই।',
      manageReviewedPacks: 'পর্যালোচিত প্যাক পরিচালনা করুন',
      offlineExplanation:
          'অফলাইন: আগে থেকে ইনস্টল করা পর্যালোচিত প্যাকই কেবল নির্দেশিত রুটিন দিতে পারে।',
      metadataPreviewLabel: 'মেটাডেটা প্রিভিউ; চালানোর মতো ভিডিও নেই',
    ),
    'vi': WorkoutRoutinesStateCopy(
      exploreStyles: 'Khám phá các phong cách tập luyện',
      previewExplanation:
          'Bản xem trước gốc của BIL. Ghi lại một hoạt động ngay hoặc cài đặt gói đã được xem xét để dùng các bài tập có hướng dẫn. Bản xem trước không có video để phát.',
      manageReviewedPacks: 'Quản lý các gói đã được xem xét',
      offlineExplanation:
          'Ngoại tuyến: chỉ các gói đã được xem xét và cài đặt trước đó mới có thể cung cấp bài tập có hướng dẫn.',
      metadataPreviewLabel:
          'Bản xem trước siêu dữ liệu; không có video để phát',
    ),
    'th': WorkoutRoutinesStateCopy(
      exploreStyles: 'สำรวจรูปแบบการออกกำลังกาย',
      previewExplanation:
          'ตัวอย่างต้นฉบับจาก BIL บันทึกกิจกรรมตอนนี้ หรือติดตั้งแพ็กที่ผ่านการตรวจสอบเพื่อใช้กิจวัตรแบบมีคำแนะนำ ตัวอย่างไม่มีวิดีโอให้เล่น',
      manageReviewedPacks: 'จัดการแพ็กที่ผ่านการตรวจสอบ',
      offlineExplanation:
          'ออฟไลน์: เฉพาะแพ็กที่ผ่านการตรวจสอบและติดตั้งไว้ก่อนหน้านี้เท่านั้นที่มีกิจวัตรแบบมีคำแนะนำ',
      metadataPreviewLabel: 'ตัวอย่างข้อมูลเมตา ไม่มีวิดีโอให้เล่น',
    ),
    'pl': WorkoutRoutinesStateCopy(
      exploreStyles: 'Poznaj style treningu',
      previewExplanation:
          'Oryginalne podglądy BIL. Zapisz aktywność teraz lub zainstaluj sprawdzony pakiet, aby korzystać z prowadzonych planów. Podgląd nie zawiera filmu do odtworzenia.',
      manageReviewedPacks: 'Zarządzaj sprawdzonymi pakietami',
      offlineExplanation:
          'Offline: tylko wcześniej zainstalowane, sprawdzone pakiety mogą udostępniać prowadzone plany.',
      metadataPreviewLabel: 'Podgląd metadanych; brak filmu do odtworzenia',
    ),
    'nl': WorkoutRoutinesStateCopy(
      exploreStyles: 'Ontdek trainingsstijlen',
      previewExplanation:
          'Originele BIL-voorbeelden. Registreer nu een activiteit of installeer een beoordeeld pakket voor begeleide routines. Een voorbeeld bevat geen afspeelbare video.',
      manageReviewedPacks: 'Beoordeelde pakketten beheren',
      offlineExplanation:
          'Offline: alleen eerder geïnstalleerde, beoordeelde pakketten kunnen begeleide routines bieden.',
      metadataPreviewLabel: 'Voorbeeld van metadata; geen afspeelbare video',
    ),
    'uk': WorkoutRoutinesStateCopy(
      exploreStyles: 'Перегляньте стилі тренувань',
      previewExplanation:
          'Оригінальні попередні перегляди BIL. Запишіть активність зараз або встановіть перевірений пакет для тренувань із супроводом. У попередньому перегляді немає відео для відтворення.',
      manageReviewedPacks: 'Керувати перевіреними пакетами',
      offlineExplanation:
          'Офлайн: тренування із супроводом доступні лише з раніше встановлених перевірених пакетів.',
      metadataPreviewLabel:
          'Попередній перегляд метаданих; немає відео для відтворення',
    ),
  };
}
