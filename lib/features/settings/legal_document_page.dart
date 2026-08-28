import 'package:flutter/material.dart';

import '../../app/localization/runtime_copy.dart';

enum BilLegalDocument { terms, privacy, healthDisclaimer }

const bilLegalPolicyId = 'BIL-LEGAL';
const bilLegalPolicyRevision = '2026-08-27';
const bilLegalEntity = 'BIL Health';
const bilLegalPublicationStatus = 'PUBLISHED';

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.document});

  final BilLegalDocument document;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(
      context,
    ).toLanguageTag().toLowerCase();
    final copy = _legalPageCopy[locale] ?? _extendedLegalCopy(locale);
    final title = copy.titles[document]!;
    final heading = copy.headings[document]!;
    final sections = <(String, String)>[
      ...copy.sections[document]!,
      if (document == BilLegalDocument.privacy)
        _facebookLoginPrivacySection(locale),
    ];
    // The legal entity is rendered from the immutable metadata line below.
    // Translation services must never localize or rename it.
    final effectiveStatus = copy.effective.split(' • ').take(2).join(' • ');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 48),
          children: [
            Text(
              heading,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(effectiveStatus, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              '$bilLegalPolicyId • $bilLegalPolicyRevision • $bilLegalEntity',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 22),
            for (final section in sections) ...[
              Text(
                section.$1,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(section.$2, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 20),
            ],
            const Divider(),
            const SizedBox(height: 12),
            Text(copy.contact),
          ],
        ),
      ),
    );
  }
}

(String, String) _facebookLoginPrivacySection(String locale) {
  const english = (
    '7. Optional Facebook Login',
    'If Facebook Login is available and you choose it, Meta may provide BIL and its authentication processor, Supabase, with an app-scoped Facebook user identifier and public-profile information returned by Meta, such as your name and profile picture. Your email is received only when you grant the email permission and Meta makes it available. BIL requests only public_profile and email for this flow and uses the result only to create, sign in to, secure, or link your BIL account. BIL does not post to Facebook or use Facebook account data to personalize health, nutrition, AI, or advertising. You can disconnect the provider where available or delete your BIL account and eligible associated data.',
  );
  const localized = <String, (String, String)>{
    'ar': (
      '7. تسجيل الدخول الاختياري عبر Facebook',
      'إذا كان تسجيل الدخول عبر Facebook متاحًا واخترت استخدامه، فقد تزود Meta تطبيق BIL ومعالج المصادقة لديه Supabase بمعرّف Facebook خاص بالتطبيق ومعلومات الملف العام التي تعيدها Meta، مثل الاسم وصورة الملف. لا يصل البريد الإلكتروني إلا إذا منحت إذن email وكان متاحًا لدى Meta. يطلب BIL فقط public_profile وemail لهذا المسار، ويستخدم النتيجة فقط لإنشاء حساب BIL أو تسجيل الدخول إليه أو حمايته أو ربطه. لا ينشر BIL على Facebook ولا يستخدم بيانات Facebook لتخصيص الصحة أو التغذية أو الذكاء الاصطناعي أو الإعلانات. يمكنك فصل المزود حيث تتوفر هذه الإمكانية أو حذف حساب BIL وبياناته المؤهلة المرتبطة.',
    ),
    'fr': (
      '7. Connexion Facebook facultative',
      'Si la connexion Facebook est disponible et que vous la choisissez, Meta peut fournir à BIL et à son prestataire d’authentification Supabase un identifiant Facebook propre à l’application et les informations de profil public renvoyées par Meta, comme le nom et la photo. L’adresse e-mail n’est reçue que si vous accordez l’autorisation email et si Meta la rend disponible. BIL demande uniquement public_profile et email pour créer, connecter, sécuriser ou lier votre compte BIL. BIL ne publie rien sur Facebook et n’utilise pas ces données pour personnaliser la santé, la nutrition, l’IA ou la publicité. Vous pouvez déconnecter le fournisseur lorsqu’il est disponible ou supprimer votre compte BIL et les données associées éligibles.',
    ),
    'es': (
      '7. Inicio de sesión opcional con Facebook',
      'Si el inicio de sesión con Facebook está disponible y decides usarlo, Meta puede proporcionar a BIL y a su procesador de autenticación Supabase un identificador de Facebook específico de la aplicación y la información de perfil público que Meta devuelva, como el nombre y la foto. El correo solo se recibe si concedes el permiso email y Meta lo facilita. BIL solicita únicamente public_profile y email para crear, iniciar, proteger o vincular tu cuenta BIL. BIL no publica en Facebook ni usa estos datos para personalizar salud, nutrición, IA o publicidad. Puedes desconectar el proveedor cuando esté disponible o eliminar tu cuenta BIL y los datos asociados que correspondan.',
    ),
    'tr': (
      '7. İsteğe bağlı Facebook ile giriş',
      'Facebook ile giriş kullanılabiliyorsa ve bunu seçerseniz Meta, BIL’e ve kimlik doğrulama işlemcisi Supabase’e uygulamaya özel bir Facebook kullanıcı kimliği ile adınız ve profil fotoğrafınız gibi Meta tarafından döndürülen herkese açık profil bilgilerini sağlayabilir. E-posta yalnızca email iznini verdiğinizde ve Meta bunu sunduğunda alınır. BIL bu akışta yalnızca public_profile ve email ister; sonucu sadece BIL hesabınızı oluşturmak, açmak, korumak veya bağlamak için kullanır. BIL Facebook’ta paylaşım yapmaz ve bu verileri sağlık, beslenme, yapay zekâ veya reklam kişiselleştirmesi için kullanmaz. Mümkün olduğunda sağlayıcının bağlantısını kesebilir veya BIL hesabınızı ve uygun ilişkili verileri silebilirsiniz.',
    ),
  };

  final languageCode = locale.split(RegExp('[-_]')).first;
  final direct = localized[languageCode];
  if (direct != null) return direct;
  return (
    RuntimeCopy.resolve(english.$1, locale) ?? english.$1,
    RuntimeCopy.resolve(english.$2, locale) ?? english.$2,
  );
}

_LegalPageCopy _extendedLegalCopy(String locale) {
  String direct(String value) {
    final override = _legalTranslationOverrides[locale]?[value];
    if (override != null) return override;
    final translated = RuntimeCopy.resolve(value, locale);
    if (translated == null || translated.trim().isEmpty) {
      throw StateError('Missing legal copy for $locale: $value');
    }
    return translated;
  }

  List<(String, String)> sections(List<(String, String)> source) => source
      .map((section) => (direct(section.$1), direct(section.$2)))
      .toList(growable: false);

  final english = _legalPageCopy['en']!;
  return _LegalPageCopy(
    titles: {
      for (final entry in english.titles.entries)
        entry.key: direct(entry.value),
    },
    headings: {
      for (final entry in english.headings.entries)
        entry.key: direct(entry.value),
    },
    sections: {
      for (final entry in english.sections.entries)
        entry.key: sections(entry.value),
    },
    effective: direct(english.effective),
    contact: direct(english.contact),
  );
}

const _legalTranslationOverrides = <String, Map<String, String>>{
  'it': {
    'Community content requires an authenticated account. Server rules limit access, support report and block controls, and retain auditable moderation events. Private health records are not community profile fields.':
        'I contenuti della community richiedono un account autenticato. Le regole del server limitano l’accesso, supportano i controlli di segnalazione e blocco e conservano eventi di moderazione verificabili. I dati sanitari privati non sono campi del profilo della community.',
  },
};

class _LegalPageCopy {
  const _LegalPageCopy({
    required this.titles,
    required this.headings,
    required this.sections,
    required this.effective,
    required this.contact,
  });
  final Map<BilLegalDocument, String> titles;
  final Map<BilLegalDocument, String> headings;
  final Map<BilLegalDocument, List<(String, String)>> sections;
  final String effective;
  final String contact;
}

const _privacySectionsAr = <(String, String)>[
  (
    '1. البيانات المحلية أولًا',
    'يحفظ BIL بيانات الملف والوجبات والماء والوزن والنشاط والتفضيلات على جهازك افتراضيًا. لا يُستخدم الحساب السحابي أو مصدر الصحة المتصل إلا بعد إجراء صريح وموافقتك.',
  ),
  (
    '2. البيانات التي نعالجها',
    'نعالج فقط البيانات اللازمة للميزة التي تختارها، وتظل المصادر موضحة كإدخال يدوي أو Health Connect أو HealthKit أو BLE أو سحابة. لا يبيع BIL معلوماتك الصحية ولا يستخدمها لإعلانات مخصصة.',
  ),
  (
    '3. الصور والصوت والخدمات المتصلة',
    'لا تُرسل صور الوجبات أو المقاطع الصوتية إلا إذا كانت بوابة الخادم الآمنة مهيأة واخترت استخدامها. ويمكنك سحب أذونات الجهاز من إعدادات النظام.',
  ),
  (
    '4. المجتمع والسلامة',
    'يتطلب محتوى المجتمع حسابًا موثقًا. تحد سياسات الخادم الوصول وتدعم الإبلاغ والحظر والتدقيق، ولا تُعد السجلات الصحية الخاصة حقولًا عامة في الملف.',
  ),
  (
    '5. أدوات التحكم',
    'يمكنك تصدير البيانات المحلية وسحب الأذونات وفصل الأجهزة وحذف السجلات المحلية وطلب حذف بيانات الحساب السحابي. قد تحتفظ المتاجر أو جهات الدفع بسجلات معاملات يفرضها القانون.',
  ),
  (
    '6. الأمان والاحتفاظ',
    'يستخدم BIL تخزين المنصة وأمن النقل وسياسات وصول الخادم وأقل قدر من الأذونات. لا ترسل كلمات المرور أو رموز الاستعادة إلى الدعم.',
  ),
];

const _termsSectionsAr = <(String, String)>[
  (
    '1. الغرض',
    'BIL أداة شخصية للتسجيل والعافية القابلة للتفسير، وليس جهازًا طبيًا أو تشخيصًا أو خدمة طوارئ أو بديلًا لمختص مؤهل.',
  ),
  (
    '2. حسابك وسجلاتك',
    'أنت مسؤول عن دقة المدخلات وحماية حسابك وجهازك. لا يخترع التطبيق أيامًا أو قياسات أو قيمًا غذائية أو قراءات أجهزة مفقودة.',
  ),
  (
    '3. التوصيات',
    'الرؤى تفسيرات حذرة للملاحظات المسجلة، وتُعرض الثقة والأدلة الناقصة والمصادر عند الحاجة. استشر مختصًا للأسئلة الطبية أو الأعراض العاجلة.',
  ),
  (
    '4. محتوى المجتمع',
    'لا تنشر محتوى غير قانوني أو مسيئًا أو خطرًا أو مضللًا أو منتهكًا للحقوق. قد تُستخدم البلاغات والحظر والإشراف وحدود الاستخدام وقيود الحساب لحماية المستخدمين.',
  ),
  (
    '5. المشتريات',
    'تُشترى الاشتراكات وتُستعاد عبر متجر التطبيق المعني، ولا يُمنح الوصول إلا بعد تحقق المتجر والخادم. تخضع الأسعار والضرائب والتجديد والإلغاء والاسترداد لشروط المتجر.',
  ),
  (
    '6. التوفر والتغييرات',
    'تعتمد بعض الميزات على أجهزة مدعومة أو خدمات المنصة أو الشبكة أو مزودين مهيئين. يعرض BIL حالة عدم التوفر بدل الادعاء بالنجاح عند غياب المتطلبات.',
  ),
];

const _healthDisclaimerSectionsAr = <(String, String)>[
  (
    '1. معلومات عافية وليست رعاية طبية',
    'BIL أداة شخصية لتسجيل العافية والتثقيف، وليس جهازًا طبيًا أو طبيبًا أو تشخيصًا أو خطة علاج أو خدمة طوارئ.',
  ),
  (
    '2. البيانات المسجلة والتقديرات',
    'تعتمد الإرشادات على المعلومات التي تسجلها أو تربطها صراحة. حسابات الطاقة والاتجاهات تقديرية وقد لا تعكس احتياجاتك الطبية الفردية.',
  ),
  (
    '3. المشورة المهنية',
    'استشر مختصًا صحيًا مؤهلًا قبل تغيير التغذية أو التمارين أو الصيام أو الأدوية أو المكملات إذا كانت لديك حالة صحية أو حمل أو أعراض مقلقة.',
  ),
  (
    '4. الطوارئ',
    'لا تستخدم BIL لاتخاذ قرارات عاجلة أو طارئة. اتصل بخدمات الطوارئ المحلية فورًا عند وجود أعراض شديدة أو مفاجئة أو مهددة للحياة.',
  ),
  (
    '5. مسؤوليتك',
    'استخدم تقديرك وحافظ على دقة السجلات وأوقف أي نشاط يبدو غير آمن واطلب الرعاية المناسبة. لا تتجاوز رؤى التطبيق تعليمات طبيبك.',
  ),
];

const _privacySections = <(String, String)>[
  (
    '1. Local-first data',
    'BIL stores profile, meal, water, weight, activity, and preference records on your device by default. A cloud account or connected-health source is used only after an explicit action and consent.',
  ),
  (
    '2. Data we process',
    'We process only the data needed for the feature you choose. Sources remain labelled as manual, Health Connect, HealthKit, BLE, or cloud. BIL does not sell health information or use it for personalized advertising.',
  ),
  (
    '3. Images, voice, and connected services',
    'Meal images and voice are not sent unless the relevant secure server gateway is configured and you choose to use it. The app shows an unavailable state when the gateway is absent. Device permissions can be withdrawn in system settings.',
  ),
  (
    '4. Community and safety',
    'Community content requires an authenticated account. Server rules limit access, support report and block controls, and retain auditable moderation events. Private health records are not community profile fields.',
  ),
  (
    '5. Your controls',
    'You can export local data, revoke permissions, disconnect devices, delete local records, and request deletion of cloud account data. Some legally required transaction records may be retained by the stores or payment processors.',
  ),
  (
    '6. Security and retention',
    'BIL uses platform storage, transport security, server access policies, and least-privilege permissions. Data is retained only for the feature and legal purpose described. Never send passwords or recovery codes to support.',
  ),
];

const _termsSections = <(String, String)>[
  (
    '1. Purpose',
    'BIL is a personal logging and explainable wellness tool. It is not a medical device, diagnosis, emergency service, or substitute for a qualified clinician.',
  ),
  (
    '2. Your account and records',
    'You are responsible for accurate entries and for protecting your account and device. The app does not invent missing days, measurements, nutrition values, or device readings.',
  ),
  (
    '3. Recommendations',
    'Insights are cautious interpretations of recorded observations. Confidence, missing evidence, and sources are shown where relevant. Seek professional care for medical questions or urgent symptoms.',
  ),
  (
    '4. Community content',
    'Do not publish unlawful, abusive, dangerous, deceptive, or rights-infringing content. Reports, blocks, moderation, rate limits, and account restrictions may be used to protect people and the service.',
  ),
  (
    '5. Purchases',
    'Subscriptions are purchased and restored through the applicable app store. Access is granted only after store and server verification. Prices, taxes, renewal, cancellation, and refunds follow the store terms shown before purchase.',
  ),
  (
    '6. Availability and changes',
    'Some features depend on supported hardware, platform services, network access, or configured providers. BIL presents an unavailable state rather than claiming success when those requirements are missing.',
  ),
];

const _healthDisclaimerSections = <(String, String)>[
  (
    '1. Wellness information, not medical care',
    'BIL is a personal wellness logging and education tool. It is not a medical device, clinician, diagnosis, treatment plan, or emergency service.',
  ),
  (
    '2. Recorded data and estimates',
    'Guidance depends on the information you record or explicitly connect. Calculations such as energy needs and trends are estimates and may not reflect your individual medical needs.',
  ),
  (
    '3. Professional advice',
    'Consult a qualified health professional before changing nutrition, exercise, fasting, medication, supplements, or care when you have a health condition, are pregnant, or have symptoms that concern you.',
  ),
  (
    '4. Emergencies',
    'Do not use BIL for urgent or emergency decisions. Contact local emergency services immediately for severe, sudden, or life-threatening symptoms.',
  ),
  (
    '5. Your responsibility',
    'Use your judgment, keep records accurate, stop an activity that feels unsafe, and seek professional care when appropriate. App insights do not override instructions from your clinician.',
  ),
];

const _privacySectionsFr = <(String, String)>[
  (
    '1. Données locales par défaut',
    'BIL conserve par défaut sur votre appareil le profil, les repas, l’eau, le poids, l’activité et les préférences. Un compte cloud ou une source de santé connectée n’est utilisé qu’après une action explicite et votre consentement.',
  ),
  (
    '2. Données traitées',
    'Nous traitons uniquement les données nécessaires à la fonction choisie. Les sources restent identifiées comme saisie manuelle, Health Connect, HealthKit, BLE ou cloud. BIL ne vend pas les données de santé et ne les utilise pas pour la publicité personnalisée.',
  ),
  (
    '3. Images, voix et services connectés',
    'Les images de repas et la voix ne sont envoyées que si la passerelle serveur sécurisée correspondante est configurée et que vous choisissez de l’utiliser. En son absence, l’application indique que la fonction est indisponible. Les autorisations peuvent être retirées dans les réglages système.',
  ),
  (
    '4. Communauté et sécurité',
    'Le contenu communautaire exige un compte authentifié. Les règles serveur limitent l’accès, permettent le signalement et le blocage et conservent des événements de modération vérifiables. Les dossiers de santé privés ne figurent pas dans le profil communautaire.',
  ),
  (
    '5. Vos contrôles',
    'Vous pouvez exporter les données locales, retirer les autorisations, déconnecter les appareils, supprimer les enregistrements locaux et demander la suppression des données du compte cloud. Les boutiques ou prestataires de paiement peuvent conserver certains justificatifs imposés par la loi.',
  ),
  (
    '6. Sécurité et conservation',
    'BIL utilise le stockage de la plateforme, la sécurité du transport, des politiques d’accès serveur et le principe du moindre privilège. Les données ne sont conservées que pour la fonction et la finalité légale décrites. N’envoyez jamais de mot de passe ou de code de récupération au support.',
  ),
];
const _termsSectionsFr = <(String, String)>[
  (
    '1. Objet',
    'BIL est un outil personnel de suivi et de bien-être explicable. Ce n’est ni un dispositif médical, ni un diagnostic, ni un service d’urgence, ni un substitut à un professionnel qualifié.',
  ),
  (
    '2. Votre compte et vos données',
    'Vous êtes responsable de l’exactitude des saisies et de la protection de votre compte et de votre appareil. L’application n’invente pas les jours, mesures, valeurs nutritionnelles ou relevés d’appareil manquants.',
  ),
  (
    '3. Recommandations',
    'Les analyses sont des interprétations prudentes des observations enregistrées. La confiance, les preuves manquantes et les sources sont indiquées lorsque cela est pertinent. Consultez un professionnel pour toute question médicale ou tout symptôme urgent.',
  ),
  (
    '4. Contenu communautaire',
    'Ne publiez aucun contenu illégal, abusif, dangereux, trompeur ou portant atteinte aux droits. Signalements, blocages, modération, limites de fréquence et restrictions de compte peuvent protéger les personnes et le service.',
  ),
  (
    '5. Achats',
    'Les abonnements sont achetés et restaurés via la boutique d’applications concernée. L’accès n’est accordé qu’après vérification par la boutique et le serveur. Prix, taxes, renouvellement, résiliation et remboursements suivent les conditions affichées avant l’achat.',
  ),
  (
    '6. Disponibilité et modifications',
    'Certaines fonctions dépendent de matériel compatible, des services de la plateforme, du réseau ou de fournisseurs configurés. BIL indique leur indisponibilité au lieu de prétendre qu’une opération a réussi lorsque ces conditions manquent.',
  ),
];
const _healthDisclaimerSectionsFr = <(String, String)>[
  (
    '1. Informations de bien-être, pas soins médicaux',
    'BIL est un outil personnel de suivi et d’éducation au bien-être. Ce n’est ni un dispositif médical, ni un professionnel de santé, ni un diagnostic, ni un traitement, ni un service d’urgence.',
  ),
  (
    '2. Données enregistrées et estimations',
    'Les conseils dépendent des informations que vous enregistrez ou connectez explicitement. Les besoins énergétiques et tendances sont des estimations qui peuvent ne pas refléter vos besoins médicaux individuels.',
  ),
  (
    '3. Avis professionnel',
    'Consultez un professionnel de santé qualifié avant de modifier alimentation, exercice, jeûne, médicaments, compléments ou soins si vous avez un problème de santé, êtes enceinte ou présentez des symptômes préoccupants.',
  ),
  (
    '4. Urgences',
    'N’utilisez pas BIL pour prendre une décision urgente. Contactez immédiatement les services d’urgence locaux en cas de symptômes graves, soudains ou potentiellement mortels.',
  ),
  (
    '5. Votre responsabilité',
    'Faites preuve de discernement, tenez vos données à jour, arrêtez toute activité dangereuse et consultez lorsque nécessaire. Les analyses de l’application ne remplacent pas les instructions de votre professionnel de santé.',
  ),
];

const _privacySectionsEs = <(String, String)>[
  (
    '1. Datos locales primero',
    'BIL guarda de forma predeterminada en tu dispositivo el perfil, las comidas, el agua, el peso, la actividad y las preferencias. Una cuenta en la nube o una fuente de salud conectada solo se usa tras una acción explícita y tu consentimiento.',
  ),
  (
    '2. Datos que tratamos',
    'Tratamos únicamente los datos necesarios para la función elegida. Las fuentes se identifican como manuales, Health Connect, HealthKit, BLE o nube. BIL no vende información de salud ni la usa para publicidad personalizada.',
  ),
  (
    '3. Imágenes, voz y servicios conectados',
    'Las imágenes de comidas y la voz solo se envían si la pasarela segura correspondiente está configurada y decides usarla. Si no está disponible, la aplicación lo indica. Puedes retirar los permisos en los ajustes del sistema.',
  ),
  (
    '4. Comunidad y seguridad',
    'El contenido de la comunidad requiere una cuenta autenticada. Las reglas del servidor limitan el acceso, permiten denunciar y bloquear y conservan eventos de moderación auditables. Los registros privados de salud no forman parte del perfil comunitario.',
  ),
  (
    '5. Tus controles',
    'Puedes exportar datos locales, revocar permisos, desconectar dispositivos, borrar registros locales y solicitar la eliminación de los datos de la cuenta en la nube. Las tiendas o procesadores de pagos pueden conservar registros exigidos por ley.',
  ),
  (
    '6. Seguridad y conservación',
    'BIL usa el almacenamiento de la plataforma, seguridad en tránsito, políticas de acceso al servidor y permisos mínimos. Los datos solo se conservan para la función y finalidad legal descritas. Nunca envíes contraseñas ni códigos de recuperación al soporte.',
  ),
];
const _termsSectionsEs = <(String, String)>[
  (
    '1. Finalidad',
    'BIL es una herramienta personal de registro y bienestar explicable. No es un dispositivo médico, un diagnóstico, un servicio de emergencias ni sustituye a un profesional cualificado.',
  ),
  (
    '2. Tu cuenta y registros',
    'Eres responsable de la exactitud de las entradas y de proteger tu cuenta y dispositivo. La aplicación no inventa días, medidas, valores nutricionales ni lecturas de dispositivos que falten.',
  ),
  (
    '3. Recomendaciones',
    'Las conclusiones son interpretaciones prudentes de observaciones registradas. Cuando corresponde, se muestran la confianza, las pruebas que faltan y las fuentes. Busca atención profesional para cuestiones médicas o síntomas urgentes.',
  ),
  (
    '4. Contenido de la comunidad',
    'No publiques contenido ilegal, abusivo, peligroso, engañoso o que vulnere derechos. Se pueden usar denuncias, bloqueos, moderación, límites de uso y restricciones de cuenta para proteger a las personas y al servicio.',
  ),
  (
    '5. Compras',
    'Las suscripciones se compran y restauran mediante la tienda de aplicaciones correspondiente. El acceso solo se concede tras la verificación de la tienda y el servidor. Precios, impuestos, renovación, cancelación y reembolsos siguen las condiciones mostradas antes de comprar.',
  ),
  (
    '6. Disponibilidad y cambios',
    'Algunas funciones dependen de hardware compatible, servicios de la plataforma, acceso a internet o proveedores configurados. BIL muestra que no están disponibles en lugar de afirmar que funcionaron cuando faltan esos requisitos.',
  ),
];
const _healthDisclaimerSectionsEs = <(String, String)>[
  (
    '1. Información de bienestar, no atención médica',
    'BIL es una herramienta personal de registro y educación sobre bienestar. No es un dispositivo médico, profesional sanitario, diagnóstico, tratamiento ni servicio de emergencias.',
  ),
  (
    '2. Datos registrados y estimaciones',
    'La orientación depende de la información que registres o conectes de forma explícita. Los cálculos de energía y tendencias son estimaciones y quizá no reflejen tus necesidades médicas individuales.',
  ),
  (
    '3. Asesoramiento profesional',
    'Consulta a un profesional sanitario cualificado antes de cambiar alimentación, ejercicio, ayuno, medicación, suplementos o cuidados si tienes una afección, estás embarazada o presentas síntomas preocupantes.',
  ),
  (
    '4. Emergencias',
    'No uses BIL para tomar decisiones urgentes o de emergencia. Contacta inmediatamente con los servicios de emergencia locales ante síntomas graves, repentinos o potencialmente mortales.',
  ),
  (
    '5. Tu responsabilidad',
    'Usa tu criterio, mantén registros exactos, detén cualquier actividad insegura y busca atención cuando corresponda. Las conclusiones de la aplicación no sustituyen las instrucciones de tu profesional sanitario.',
  ),
];

const _privacySectionsTr = <(String, String)>[
  (
    '1. Önce yerel veri',
    'BIL profil, öğün, su, kilo, aktivite ve tercih kayıtlarını varsayılan olarak cihazınızda saklar. Bulut hesabı veya bağlı sağlık kaynağı yalnızca açık bir işlem ve onayınızdan sonra kullanılır.',
  ),
  (
    '2. İşlediğimiz veriler',
    'Yalnızca seçtiğiniz özellik için gereken verileri işleriz. Kaynaklar manuel, Health Connect, HealthKit, BLE veya bulut olarak etiketlenir. BIL sağlık bilgilerini satmaz ve kişiselleştirilmiş reklamlar için kullanmaz.',
  ),
  (
    '3. Görüntü, ses ve bağlı hizmetler',
    'Öğün görüntüleri ve ses yalnızca ilgili güvenli sunucu geçidi yapılandırılmışsa ve kullanmayı seçerseniz gönderilir. Geçit yoksa uygulama özelliği kullanılamaz gösterir. Cihaz izinlerini sistem ayarlarından kaldırabilirsiniz.',
  ),
  (
    '4. Topluluk ve güvenlik',
    'Topluluk içeriği kimliği doğrulanmış hesap gerektirir. Sunucu kuralları erişimi sınırlar, bildirme ve engellemeyi destekler ve denetlenebilir moderasyon olaylarını saklar. Özel sağlık kayıtları topluluk profili alanı değildir.',
  ),
  (
    '5. Denetimleriniz',
    'Yerel verileri dışa aktarabilir, izinleri kaldırabilir, cihaz bağlantısını kesebilir, yerel kayıtları silebilir ve bulut hesabı verilerinin silinmesini isteyebilirsiniz. Mağazalar veya ödeme kuruluşları yasaların gerektirdiği işlem kayıtlarını tutabilir.',
  ),
  (
    '6. Güvenlik ve saklama',
    'BIL platform depolaması, aktarım güvenliği, sunucu erişim politikaları ve en az yetki ilkesini kullanır. Veriler yalnızca açıklanan özellik ve yasal amaç için saklanır. Destek ekibine asla parola veya kurtarma kodu göndermeyin.',
  ),
];
const _termsSectionsTr = <(String, String)>[
  (
    '1. Amaç',
    'BIL kişisel kayıt ve açıklanabilir sağlıklı yaşam aracıdır. Tıbbi cihaz, teşhis, acil durum hizmeti veya yetkili bir uzmanın yerine geçen bir hizmet değildir.',
  ),
  (
    '2. Hesabınız ve kayıtlarınız',
    'Girişlerin doğruluğundan ve hesabınızla cihazınızı korumaktan siz sorumlusunuz. Uygulama eksik günleri, ölçümleri, besin değerlerini veya cihaz okumalarını uydurmaz.',
  ),
  (
    '3. Öneriler',
    'İçgörüler kaydedilmiş gözlemlerin ihtiyatlı yorumlarıdır. Uygun olduğunda güven düzeyi, eksik kanıtlar ve kaynaklar gösterilir. Tıbbi sorular veya acil belirtiler için profesyonel yardım alın.',
  ),
  (
    '4. Topluluk içeriği',
    'Yasa dışı, taciz edici, tehlikeli, aldatıcı veya hak ihlal eden içerik yayımlamayın. Kişileri ve hizmeti korumak için bildirim, engelleme, moderasyon, hız sınırı ve hesap kısıtlamaları uygulanabilir.',
  ),
  (
    '5. Satın almalar',
    'Abonelikler ilgili uygulama mağazasından satın alınır ve geri yüklenir. Erişim yalnızca mağaza ve sunucu doğrulamasından sonra verilir. Fiyat, vergi, yenileme, iptal ve iadeler satın alma öncesi gösterilen mağaza koşullarına tabidir.',
  ),
  (
    '6. Kullanılabilirlik ve değişiklikler',
    'Bazı özellikler desteklenen donanım, platform hizmetleri, ağ erişimi veya yapılandırılmış sağlayıcılara bağlıdır. Gereksinimler yoksa BIL başarı iddia etmek yerine özelliğin kullanılamadığını gösterir.',
  ),
];
const _healthDisclaimerSectionsTr = <(String, String)>[
  (
    '1. Sağlıklı yaşam bilgisi, tıbbi bakım değil',
    'BIL kişisel sağlıklı yaşam kaydı ve eğitim aracıdır. Tıbbi cihaz, klinisyen, teşhis, tedavi planı veya acil durum hizmeti değildir.',
  ),
  (
    '2. Kaydedilen veriler ve tahminler',
    'Rehberlik, kaydettiğiniz veya açıkça bağladığınız bilgilere dayanır. Enerji ihtiyacı ve eğilim hesapları tahmindir ve kişisel tıbbi ihtiyaçlarınızı yansıtmayabilir.',
  ),
  (
    '3. Profesyonel tavsiye',
    'Bir sağlık sorununuz varsa, hamileyseniz veya endişe verici belirtiler yaşıyorsanız beslenme, egzersiz, oruç, ilaç, takviye veya bakımınızı değiştirmeden önce yetkili bir sağlık uzmanına danışın.',
  ),
  (
    '4. Acil durumlar',
    'Acil kararlar için BIL kullanmayın. Şiddetli, ani veya yaşamı tehdit eden belirtilerde derhal yerel acil servislerle iletişime geçin.',
  ),
  (
    '5. Sorumluluğunuz',
    'Kendi muhakemenizi kullanın, kayıtları doğru tutun, güvenli gelmeyen etkinliği durdurun ve gerektiğinde profesyonel yardım alın. Uygulama içgörüleri hekiminizin talimatlarının yerine geçmez.',
  ),
];

const _legalPageCopy = <String, _LegalPageCopy>{
  'en': _LegalPageCopy(
    titles: {
      BilLegalDocument.terms: 'Terms of Service',
      BilLegalDocument.privacy: 'Privacy Policy',
      BilLegalDocument.healthDisclaimer: 'Health Disclaimer',
    },
    headings: {
      BilLegalDocument.terms: 'BIL Terms of Service',
      BilLegalDocument.privacy: 'BIL Privacy Policy',
      BilLegalDocument.healthDisclaimer: 'BIL Health Disclaimer',
    },
    sections: {
      BilLegalDocument.terms: _termsSections,
      BilLegalDocument.privacy: _privacySections,
      BilLegalDocument.healthDisclaimer: _healthDisclaimerSections,
    },
    effective: 'Last updated: 22 August 2026 • BIL Health',
    contact:
        'Questions: privacy@bilhealth.com • Support: support@bilhealth.com',
  ),
  'ar': _LegalPageCopy(
    titles: {
      BilLegalDocument.terms: 'شروط الخدمة',
      BilLegalDocument.privacy: 'سياسة الخصوصية',
      BilLegalDocument.healthDisclaimer: 'إخلاء المسؤولية الصحية',
    },
    headings: {
      BilLegalDocument.terms: 'شروط خدمة BIL',
      BilLegalDocument.privacy: 'سياسة خصوصية BIL',
      BilLegalDocument.healthDisclaimer: 'إخلاء المسؤولية الصحية من BIL',
    },
    sections: {
      BilLegalDocument.terms: _termsSectionsAr,
      BilLegalDocument.privacy: _privacySectionsAr,
      BilLegalDocument.healthDisclaimer: _healthDisclaimerSectionsAr,
    },
    effective: 'آخر تحديث: 22 أغسطس 2026 • BIL Health',
    contact: 'الخصوصية: privacy@bilhealth.com • الدعم: support@bilhealth.com',
  ),
  'fr': _LegalPageCopy(
    titles: {
      BilLegalDocument.terms: 'Conditions d’utilisation',
      BilLegalDocument.privacy: 'Politique de confidentialité',
      BilLegalDocument.healthDisclaimer: 'Avertissement santé',
    },
    headings: {
      BilLegalDocument.terms: 'Conditions d’utilisation de BIL',
      BilLegalDocument.privacy: 'Politique de confidentialité de BIL',
      BilLegalDocument.healthDisclaimer: 'Avertissement santé de BIL',
    },
    sections: {
      BilLegalDocument.terms: _termsSectionsFr,
      BilLegalDocument.privacy: _privacySectionsFr,
      BilLegalDocument.healthDisclaimer: _healthDisclaimerSectionsFr,
    },
    effective: 'Dernière mise à jour : 22 août 2026 • BIL Health',
    contact:
        'Confidentialité : privacy@bilhealth.com • Assistance : support@bilhealth.com',
  ),
  'es': _LegalPageCopy(
    titles: {
      BilLegalDocument.terms: 'Términos del servicio',
      BilLegalDocument.privacy: 'Política de privacidad',
      BilLegalDocument.healthDisclaimer: 'Aviso de salud',
    },
    headings: {
      BilLegalDocument.terms: 'Términos del servicio de BIL',
      BilLegalDocument.privacy: 'Política de privacidad de BIL',
      BilLegalDocument.healthDisclaimer: 'Aviso de salud de BIL',
    },
    sections: {
      BilLegalDocument.terms: _termsSectionsEs,
      BilLegalDocument.privacy: _privacySectionsEs,
      BilLegalDocument.healthDisclaimer: _healthDisclaimerSectionsEs,
    },
    effective: 'Última actualización: 22 de agosto de 2026 • BIL Health',
    contact:
        'Privacidad: privacy@bilhealth.com • Soporte: support@bilhealth.com',
  ),
  'tr': _LegalPageCopy(
    titles: {
      BilLegalDocument.terms: 'Hizmet Koşulları',
      BilLegalDocument.privacy: 'Gizlilik Politikası',
      BilLegalDocument.healthDisclaimer: 'Sağlık Uyarısı',
    },
    headings: {
      BilLegalDocument.terms: 'BIL Hizmet Koşulları',
      BilLegalDocument.privacy: 'BIL Gizlilik Politikası',
      BilLegalDocument.healthDisclaimer: 'BIL Sağlık Uyarısı',
    },
    sections: {
      BilLegalDocument.terms: _termsSectionsTr,
      BilLegalDocument.privacy: _privacySectionsTr,
      BilLegalDocument.healthDisclaimer: _healthDisclaimerSectionsTr,
    },
    effective: 'Son güncelleme: 22 Ağustos 2026 • BIL Health',
    contact: 'Gizlilik: privacy@bilhealth.com • Destek: support@bilhealth.com',
  ),
};
