import 'package:flutter/material.dart';

import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy_admin_notifications.dart';
import '../../../app/localization/runtime_copy_extended.dart';
import '../services/ai_coach_admin_service.dart';

/// A reviewed notification choice shown to an authorized administrator.
///
/// The two service-managed presets deliberately submit a null message so the
/// server can select copy in every recipient's locale. The remaining presets
/// use the existing 25-locale runtime catalog and are sent as editable custom
/// text exactly as reviewed by the administrator.
final class AdminNotificationPreset {
  const AdminNotificationPreset({
    required this.id,
    required this.kind,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.serverLocalized = false,
  });

  final String id;
  final AiCoachAdminNotificationKind kind;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool serverLocalized;
}

abstract final class AdminNotificationPresetCatalog {
  static const readyCount = 10;

  static List<AdminNotificationPreset> ready(Locale locale) {
    final localeTag = BilLocalePolicy.canonicalTag(locale);
    return <AdminNotificationPreset>[
      AdminNotificationPreset(
        id: 'compensation',
        kind: AiCoachAdminNotificationKind.compensation,
        icon: Icons.favorite_rounded,
        color: const Color(0xFF1C6E8C),
        title: AdminNotificationRuntimeCopy.resolve(
          'Compensation message',
          localeTag,
        ),
        body: serverBody(AiCoachAdminNotificationKind.compensation, localeTag),
        serverLocalized: true,
      ),
      AdminNotificationPreset(
        id: 'gift',
        kind: AiCoachAdminNotificationKind.gift,
        icon: Icons.card_giftcard_rounded,
        color: const Color(0xFF8A5A00),
        title: AdminNotificationRuntimeCopy.resolve('Gift message', localeTag),
        body: serverBody(AiCoachAdminNotificationKind.gift, localeTag),
        serverLocalized: true,
      ),
      _custom(
        locale,
        id: 'welcome',
        icon: Icons.waving_hand_rounded,
        color: const Color(0xFF006C67),
        title: 'Welcome to BIL',
        body: 'Your private starting point is ready',
      ),
      _custom(
        locale,
        id: 'progress',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF1B5E9E),
        title: 'Progress',
        body: 'Keep logging each day for a clearer progress picture.',
      ),
      _custom(
        locale,
        id: 'weekly-report',
        icon: Icons.insights_rounded,
        color: const Color(0xFF5D3A9B),
        title: 'Weekly report',
        body:
            'See the patterns behind your meals, weight, hydration, and progress in one report.',
      ),
      _custom(
        locale,
        id: 'connected-health',
        icon: Icons.monitor_heart_rounded,
        color: const Color(0xFF00796B),
        title: 'Connected health',
        body: 'Open connected-health sources and permissions.',
      ),
      _custom(
        locale,
        id: 'community',
        icon: Icons.groups_rounded,
        color: const Color(0xFF7B4B00),
        title: 'Community',
        body: 'Posts, messages, and a moderated community food library.',
      ),
      _custom(
        locale,
        id: 'ai-coach',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF094B66),
        title: 'AI Coach',
        body:
            'Personal health intelligence that understands your data and turns it into clear next steps.',
      ),
      _custom(
        locale,
        id: 'privacy',
        icon: Icons.shield_rounded,
        color: const Color(0xFF455A64),
        title: 'Privacy',
        body: 'Your health data stays under your control',
      ),
      _custom(
        locale,
        id: 'update',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF2E7D32),
        title: 'Update',
        body: 'Today is up to date.',
      ),
    ];
  }

  static AdminNotificationPreset blankCustom(Locale locale) {
    final localeTag = BilLocalePolicy.canonicalTag(locale);
    return AdminNotificationPreset(
      id: 'custom',
      kind: AiCoachAdminNotificationKind.custom,
      icon: Icons.edit_notifications_rounded,
      color: const Color(0xFF1565C0),
      title: AdminNotificationRuntimeCopy.resolve(
        'Write a custom message',
        localeTag,
      ),
      body: AdminNotificationRuntimeCopy.resolve(
        'Writing the message is required before sending is enabled.',
        localeTag,
      ),
    );
  }

  static AdminNotificationPreset _custom(
    Locale locale, {
    required String id,
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) => AdminNotificationPreset(
    id: id,
    kind: AiCoachAdminNotificationKind.custom,
    icon: icon,
    color: color,
    title: _localized(title, locale),
    body: _localized(body, locale),
  );

  static String _localized(String english, Locale locale) {
    final tag = BilLocalePolicy.canonicalTag(locale);
    return _baseCopy[english]?[tag] ??
        ExtendedRuntimeCopy.values[english]?[tag] ??
        english;
  }

  static const _baseCopy = <String, Map<String, String>>{
    'Welcome to BIL': {
      'ar': 'مرحبًا بك في BIL',
      'fr': 'Bienvenue sur BIL',
      'es': 'Te damos la bienvenida a BIL',
      'tr': "BIL'e hoş geldiniz",
    },
    'Your private starting point is ready': {
      'ar': 'نقطة بدايتك الخاصة جاهزة',
      'fr': 'Votre point de départ privé est prêt',
      'es': 'Tu punto de partida privado está listo',
      'tr': 'Özel başlangıç noktanız hazır',
    },
    'Progress': {
      'ar': 'التقدم',
      'fr': 'Progression',
      'es': 'Progreso',
      'tr': 'İlerleme',
    },
    'Keep logging each day for a clearer progress picture.': {
      'ar': 'واصل التسجيل كل يوم للحصول على صورة أوضح لتقدمك.',
      'fr': 'Continuez à enregistrer chaque jour pour mieux voir vos progrès.',
      'es': 'Sigue registrando cada día para ver mejor tu progreso.',
      'tr': 'İlerlemenizi daha net görmek için her gün kayıt tutun.',
    },
    'Weekly report': {
      'ar': 'التقرير الأسبوعي',
      'fr': 'Rapport hebdomadaire',
      'es': 'Informe semanal',
      'tr': 'Haftalık rapor',
    },
    'See the patterns behind your meals, weight, hydration, and progress in one report.': {
      'ar': 'شاهد أنماط وجباتك ووزنك وترطيبك وتقدمك في تقرير واحد.',
      'fr':
          'Découvrez les tendances de vos repas, poids, hydratation et progrès dans un seul rapport.',
      'es':
          'Descubre los patrones de tus comidas, peso, hidratación y progreso en un solo informe.',
      'tr': 'Öğün, kilo, sıvı ve ilerleme örüntülerinizi tek raporda görün.',
    },
    'Connected health': {
      'ar': 'الصحة المتصلة',
      'fr': 'Santé connectée',
      'es': 'Salud conectada',
      'tr': 'Bağlı sağlık',
    },
    'Open connected-health sources and permissions.': {
      'ar': 'افتح مصادر الصحة المتصلة وأذوناتها.',
      'fr': 'Ouvrez les sources de santé connectée et leurs autorisations.',
      'es': 'Abre las fuentes de salud conectada y sus permisos.',
      'tr': 'Bağlı sağlık kaynaklarını ve izinlerini açın.',
    },
    'Community': {
      'ar': 'المجتمع',
      'fr': 'Communauté',
      'es': 'Comunidad',
      'tr': 'Topluluk',
    },
    'Posts, messages, and a moderated community food library.': {
      'ar': 'منشورات ورسائل ومكتبة أطعمة مجتمعية خاضعة للإشراف.',
      'fr':
          'Publications, messages et bibliothèque alimentaire communautaire modérée.',
      'es':
          'Publicaciones, mensajes y una biblioteca comunitaria de alimentos moderada.',
      'tr':
          'Gönderiler, mesajlar ve denetlenen bir topluluk yiyecek kitaplığı.',
    },
    'AI Coach': {
      'ar': 'AI Coach',
      'fr': 'AI Coach',
      'es': 'AI Coach',
      'tr': 'AI Coach',
    },
    'Personal health intelligence that understands your data and turns it into clear next steps.': {
      'ar': 'ذكاء صحي شخصي يفهم بياناتك ويحوّلها إلى خطوات تالية واضحة.',
      'fr':
          'Une intelligence santé personnelle qui comprend vos données et les transforme en prochaines étapes claires.',
      'es':
          'Inteligencia de salud personal que entiende tus datos y los convierte en próximos pasos claros.',
      'tr':
          'Verilerinizi anlayıp net sonraki adımlara dönüştüren kişisel sağlık zekâsı.',
    },
    'Privacy': {
      'ar': 'الخصوصية',
      'fr': 'Confidentialité',
      'es': 'Privacidad',
      'tr': 'Gizlilik',
    },
    'Your health data stays under your control': {
      'ar': 'تبقى بياناتك الصحية تحت سيطرتك',
      'fr': 'Vos données de santé restent sous votre contrôle',
      'es': 'Tus datos de salud permanecen bajo tu control',
      'tr': 'Sağlık verileriniz sizin kontrolünüzde kalır',
    },
    'Update': {
      'ar': 'تحديث',
      'fr': 'Mise à jour',
      'es': 'Actualización',
      'tr': 'Güncelleme',
    },
    'Today is up to date.': {
      'ar': 'بيانات اليوم محدّثة.',
      'fr': 'Les données d’aujourd’hui sont à jour.',
      'es': 'Los datos de hoy están actualizados.',
      'tr': 'Bugünün verileri güncel.',
    },
  };

  /// Mirrors `private.bil_admin_notification_body` for a faithful preview.
  /// Delivery remains server-owned; this string is never submitted unless an
  /// administrator explicitly replaces it in the composer.
  static String serverBody(
    AiCoachAdminNotificationKind kind,
    String localeTag,
  ) {
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag) ?? 'en';
    final values = switch (kind) {
      AiCoachAdminNotificationKind.compensation => _compensationBodies,
      AiCoachAdminNotificationKind.gift => _giftBodies,
      AiCoachAdminNotificationKind.custom => throw ArgumentError.value(
        kind,
        'kind',
        'Custom notifications do not have a server-managed body.',
      ),
    };
    return values[tag] ?? values['en']!;
  }

  static const _compensationBodies = <String, String>{
    'ar':
        'تعويض من BIL 💛 نعتذر عن الإزعاج ونقدّر ثقتك بنا. شكرًا لمنحنا فرصة تحسين تجربتك.',
    'en':
        'A courtesy from BIL 💛 We’re sorry for the inconvenience and truly value your trust. Thank you for giving us the chance to improve your experience.',
    'fr':
        'Un geste de BIL 💛 Nous sommes désolés pour le désagrément et apprécions votre confiance. Merci de nous permettre d’améliorer votre expérience.',
    'es':
        'Una atención de BIL 💛 Lamentamos las molestias y valoramos tu confianza. Gracias por permitirnos mejorar tu experiencia.',
    'tr':
        'BIL’den bir telafi 💛 Yaşanan aksaklık için üzgünüz ve güveninize değer veriyoruz. Deneyiminizi iyileştirme fırsatı verdiğiniz için teşekkürler.',
    'de':
        'Eine Kulanz von BIL 💛 Wir entschuldigen uns für die Unannehmlichkeiten und schätzen dein Vertrauen. Danke für die Chance, dein Erlebnis zu verbessern.',
    'it':
        'Un gesto da BIL 💛 Ci scusiamo per il disagio e apprezziamo la tua fiducia. Grazie per l’opportunità di migliorare la tua esperienza.',
    'pt-BR':
        'Uma cortesia da BIL 💛 Lamentamos o inconveniente e valorizamos sua confiança. Obrigado pela oportunidade de melhorar sua experiência.',
    'pt-PT':
        'Uma cortesia da BIL 💛 Lamentamos o incómodo e valorizamos a sua confiança. Obrigado pela oportunidade de melhorar a sua experiência.',
    'ur':
        'BIL کی جانب سے تلافی 💛 تکلیف کے لیے معذرت، ہم آپ کے اعتماد کی قدر کرتے ہیں۔ ہمیں آپ کا تجربہ بہتر بنانے کا موقع دینے کا شکریہ۔',
    'fa':
        'جبران از طرف BIL 💛 بابت ناراحتی پیش‌آمده متأسفیم و از اعتماد شما سپاسگزاریم. ممنون که فرصت بهبود تجربه‌تان را به ما دادید.',
    'hi':
        'BIL की ओर से क्षतिपूर्ति 💛 असुविधा के लिए हमें खेद है और हम आपके भरोसे की कद्र करते हैं। अनुभव बेहतर करने का अवसर देने के लिए धन्यवाद।',
    'id':
        'Kompensasi dari BIL 💛 Kami mohon maaf atas ketidaknyamanan ini dan menghargai kepercayaan Anda. Terima kasih atas kesempatan untuk memperbaiki pengalaman Anda.',
    'ms':
        'Pampasan daripada BIL 💛 Kami memohon maaf atas kesulitan dan menghargai kepercayaan anda. Terima kasih atas peluang untuk menambah baik pengalaman anda.',
    'ja': 'BILからのお詫びです💛 ご不便をおかけし申し訳ありません。信頼に感謝し、より良い体験へ改善する機会をいただきありがとうございます。',
    'ko':
        'BIL의 보상 안내입니다 💛 불편을 드려 죄송하며 보내주신 신뢰에 감사드립니다. 더 나은 경험으로 개선할 기회를 주셔서 감사합니다.',
    'zh-Hans': '来自 BIL 的补偿 💛 对给你带来的不便我们深表歉意，也感谢你的信任。谢谢你给予我们改善体验的机会。',
    'zh-Hant': '來自 BIL 的補償 💛 對造成的不便我們深感抱歉，也感謝你的信任。謝謝你給予我們改善體驗的機會。',
    'ru':
        'Компенсация от BIL 💛 Приносим извинения за неудобство и ценим ваше доверие. Спасибо за возможность улучшить ваш опыт.',
    'bn':
        'BIL-এর পক্ষ থেকে ক্ষতিপূরণ 💛 অসুবিধার জন্য আমরা দুঃখিত এবং আপনার আস্থাকে মূল্য দিই। অভিজ্ঞতা উন্নত করার সুযোগ দেওয়ার জন্য ধন্যবাদ।',
    'vi':
        'Một lời bù đắp từ BIL 💛 Chúng tôi xin lỗi vì sự bất tiện và trân trọng niềm tin của bạn. Cảm ơn bạn đã cho chúng tôi cơ hội cải thiện trải nghiệm.',
    'th':
        'การชดเชยจาก BIL 💛 เราขออภัยในความไม่สะดวกและขอบคุณที่ไว้วางใจ ขอบคุณที่ให้โอกาสเราปรับปรุงประสบการณ์ของคุณ',
    'pl':
        'Rekompensata od BIL 💛 Przepraszamy za niedogodność i cenimy Twoje zaufanie. Dziękujemy za szansę ulepszenia Twoich doświadczeń.',
    'nl':
        'Een tegemoetkoming van BIL 💛 Excuses voor het ongemak; we waarderen je vertrouwen. Bedankt voor de kans om je ervaring te verbeteren.',
    'uk':
        'Компенсація від BIL 💛 Перепрошуємо за незручності й цінуємо вашу довіру. Дякуємо за можливість покращити ваш досвід.',
  };

  static const _giftBodies = <String, String>{
    'ar':
        'هدية من BIL 🎁 شكرًا لكونك جزءًا من BIL. هذه اللفتة الخاصة تعبير عن تقديرنا لك.',
    'en':
        'A gift from BIL 🎁 Thank you for being part of BIL. This special message is our way of showing how much we value you.',
    'fr':
        'Un cadeau de BIL 🎁 Merci de faire partie de BIL. Cette attention spéciale exprime toute notre reconnaissance.',
    'es':
        'Un regalo de BIL 🎁 Gracias por formar parte de BIL. Este detalle especial expresa cuánto te valoramos.',
    'tr':
        'BIL’den bir hediye 🎁 BIL’in bir parçası olduğunuz için teşekkürler. Bu özel jest, size verdiğimiz değerin bir ifadesidir.',
    'de':
        'Ein Geschenk von BIL 🎁 Danke, dass du Teil von BIL bist. Diese besondere Geste zeigt unsere Wertschätzung.',
    'it':
        'Un regalo da BIL 🎁 Grazie per essere parte di BIL. Questo gesto speciale esprime quanto ti apprezziamo.',
    'pt-BR':
        'Um presente da BIL 🎁 Obrigado por fazer parte da BIL. Este gesto especial mostra o quanto valorizamos você.',
    'pt-PT':
        'Um presente da BIL 🎁 Obrigado por fazer parte da BIL. Este gesto especial mostra o quanto o valorizamos.',
    'ur':
        'BIL کی طرف سے تحفہ 🎁 BIL کا حصہ بننے کا شکریہ۔ یہ خصوصی پیغام آپ کے لیے ہماری قدر کا اظہار ہے۔',
    'fa':
        'هدیه‌ای از BIL 🎁 از اینکه بخشی از BIL هستید سپاسگزاریم. این توجه ویژه نشانه قدردانی ما از شماست.',
    'hi':
        'BIL की ओर से उपहार 🎁 BIL का हिस्सा बनने के लिए धन्यवाद। यह खास संदेश आपके प्रति हमारी सराहना का प्रतीक है।',
    'id':
        'Hadiah dari BIL 🎁 Terima kasih telah menjadi bagian dari BIL. Perhatian istimewa ini adalah bentuk penghargaan kami kepada Anda.',
    'ms':
        'Hadiah daripada BIL 🎁 Terima kasih kerana menjadi sebahagian daripada BIL. Tanda istimewa ini melambangkan penghargaan kami kepada anda.',
    'ja': 'BILからのプレゼントです🎁 BILをご利用いただきありがとうございます。この特別なメッセージに感謝の気持ちを込めました。',
    'ko': 'BIL의 선물입니다 🎁 BIL과 함께해 주셔서 감사합니다. 이 특별한 메시지에 감사의 마음을 담았습니다.',
    'zh-Hans': '来自 BIL 的礼物 🎁 感谢你成为 BIL 的一员。这份特别心意代表我们对你的珍视。',
    'zh-Hant': '來自 BIL 的禮物 🎁 感謝你成為 BIL 的一員。這份特別心意代表我們對你的珍視。',
    'ru':
        'Подарок от BIL 🎁 Спасибо, что вы с BIL. Этот особый знак выражает нашу признательность вам.',
    'bn':
        'BIL-এর পক্ষ থেকে উপহার 🎁 BIL-এর অংশ হওয়ার জন্য ধন্যবাদ। এই বিশেষ বার্তাটি আপনার প্রতি আমাদের কৃতজ্ঞতার প্রকাশ।',
    'vi':
        'Quà tặng từ BIL 🎁 Cảm ơn bạn đã đồng hành cùng BIL. Lời nhắn đặc biệt này thể hiện sự trân trọng của chúng tôi dành cho bạn.',
    'th':
        'ของขวัญจาก BIL 🎁 ขอบคุณที่เป็นส่วนหนึ่งของ BIL ข้อความพิเศษนี้แทนคำขอบคุณและความใส่ใจจากเรา',
    'pl':
        'Prezent od BIL 🎁 Dziękujemy, że jesteś częścią BIL. Ten wyjątkowy gest wyraża nasze uznanie dla Ciebie.',
    'nl':
        'Een cadeau van BIL 🎁 Bedankt dat je deel uitmaakt van BIL. Met dit bijzondere gebaar tonen we onze waardering.',
    'uk':
        'Подарунок від BIL 🎁 Дякуємо, що ви з BIL. Цей особливий знак виражає нашу вдячність вам.',
  };
}
