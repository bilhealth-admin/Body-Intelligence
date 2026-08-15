import 'package:flutter/material.dart';

abstract final class SettingsCopy {
  static const supportedLanguageCodes = {'ar', 'en', 'fr', 'es', 'tr'};

  static String text(BuildContext context, String english) {
    assert(
      catalogsBalanced,
      'Settings translations must stay five-language complete.',
    );
    final languageCode = Localizations.localeOf(context).languageCode;
    final catalog = _catalogs[languageCode] ?? _catalogs['en']!;
    final value = catalog[english];
    assert(
      value != null,
      'Missing settings translation: $languageCode:$english',
    );
    return value ?? _catalogs['en']![english] ?? english;
  }

  static bool get catalogsBalanced {
    final reference = _catalogs['en']!.keys.toSet();
    return _catalogs.keys.toSet().containsAll(supportedLanguageCodes) &&
        supportedLanguageCodes.containsAll(_catalogs.keys) &&
        _catalogs.values.every(
          (catalog) =>
              catalog.keys.toSet().containsAll(reference) &&
              reference.containsAll(catalog.keys) &&
              catalog.values.every((value) => value.trim().isNotEmpty),
        );
  }

  static Map<String, String> catalog(Locale locale) =>
      Map.unmodifiable(_catalogs[locale.languageCode] ?? _catalogs['en']!);

  static const _catalogs = <String, Map<String, String>>{
    'en': {
      'My profile': 'My profile',
      'Email settings': 'Email settings',
      'Diary settings': 'Diary settings',
      'Calorie and macro goals': 'Calorie and macro goals',
      'System default': 'System default',
      'Account & data': 'Account & data',
      'Account and data': 'Account and data',
      'Manage sign-in or safely restart the account experience.':
          'Manage sign-in or safely restart the account experience.',
      'Sign out and test account again': 'Sign out and test account again',
      'Does not delete weight, meals, or local health data.':
          'Does not delete weight, meals, or local health data.',
      'Erase all my local data': 'Erase all my local data',
      'Deletes the profile and records after creating a recovery snapshot.':
          'Deletes the profile and records after creating a recovery snapshot.',
      'Today dashboard': 'Today dashboard',
      'Customize Today': 'Customize Today',
      'Show or hide macros, activity, quick log, discovery, and intelligence cards.':
          'Show or hide macros, activity, quick log, discovery, and intelligence cards.',
      'BIL services': 'BIL services',
      'BIL plans & memberships': 'BIL plans & memberships',
      'Free, Plus, Pro, Coach, Clinic, and Enterprise with monthly or annual billing.':
          'Free, Plus, Pro, Coach, Clinic, and Enterprise with monthly or annual billing.',
      'Nutrition plans': 'Nutrition plans',
      'Keto, low carb, fat loss, lean mass, pregnancy, and supervised pathways.':
          'Keto, low carb, fat loss, lean mass, pregnancy, and supervised pathways.',
      'Sleep, movement & fasting library': 'Sleep, movement & fasting library',
      'Wellness tools grounded in your real logs and measurements.':
          'Wellness tools grounded in your real logs and measurements.',
      'Offline food libraries': 'Offline food libraries',
      'Manage the core library and optional global packs.':
          'Manage the core library and optional global packs.',
      'Community & friends': 'Community & friends',
      'Posts, messages, and a moderated community food library.':
          'Posts, messages, and a moderated community food library.',
      'Region & units': 'Region & units',
      'Your health profile': 'Your health profile',
      'My profile & plan': 'My profile & plan',
      'Edit body data, goal, and activity without restarting onboarding.':
          'Edit body data, goal, and activity without restarting onboarding.',
      'Sleep': 'Sleep',
      'Log sleep and review your measured trends.':
          'Log sleep and review your measured trends.',
      'Movement & recovery': 'Movement & recovery',
      'Choose a workout and log your actual movement.':
          'Choose a workout and log your actual movement.',
      'Fasting rhythm': 'Intermittent fasting',
      'Track a fasting window with clear health guardrails.':
          'Track a fasting window with clear health guardrails.',
      'Intelligence & privacy': 'Intelligence & privacy',
      'Choose per record whether it may inform local insights, or delete it.':
          'Choose per record whether it may inform local insights, or delete it.',
      'Help & FAQ': 'Help & FAQ',
      'Answers about account, privacy, logging, and health.':
          'Answers about account, privacy, logging, and health.',
      'Local data & app': 'Local data & app',
      'Connected capabilities': 'Connected capabilities',
      'Setup & reset': 'Setup & reset',
      'Review initial setup': 'Review initial setup',
      'Reopen onboarding without deleting your profile or records.':
          'Reopen onboarding without deleting your profile or records.',
      'Location & local time': 'Location & local time',
      'Choose country and city or detect from this device.':
          'Choose country and city or detect from this device.',
    },
    'ar': {
      'My profile': 'ملفي الشخصي',
      'Email settings': 'إعدادات البريد الإلكتروني',
      'Diary settings': 'إعدادات اليوميات',
      'Calorie and macro goals': 'أهداف السعرات والماكروز',
      'System default': 'إعداد النظام',
      'Account & data': 'الحساب والبيانات',
      'Account and data': 'الحساب والبيانات',
      'Manage sign-in or safely restart the account experience.':
          'أدِر تسجيل الدخول أو أعد بدء تجربة الحساب بأمان.',
      'Sign out and test account again': 'تسجيل الخروج وتجربة الحساب مجددًا',
      'Does not delete weight, meals, or local health data.':
          'لا يحذف الوزن أو الوجبات أو بياناتك الصحية المحلية.',
      'Erase all my local data': 'مسح جميع بياناتي المحلية',
      'Deletes the profile and records after creating a recovery snapshot.':
          'يحذف الملف والسجلات بعد إنشاء لقطة استعادة آمنة.',
      'Today dashboard': 'شاشة اليوم',
      'Customize Today': 'تخصيص شاشة اليوم',
      'Show or hide macros, activity, quick log, discovery, and intelligence cards.':
          'أظهر أو أخفِ بطاقات الماكروز والنشاط والتسجيل السريع والاستكشاف والذكاء.',
      'BIL services': 'خدمات BIL',
      'BIL plans & memberships': 'خطط وعضويات BIL',
      'Free, Plus, Pro, Coach, Clinic, and Enterprise with monthly or annual billing.':
          'Free وPlus وPro وCoach وClinic وEnterprise مع دفع شهري أو سنوي.',
      'Nutrition plans': 'خطط التغذية',
      'Keto, low carb, fat loss, lean mass, pregnancy, and supervised pathways.':
          'كيتو وقليل الكربوهيدرات وخسارة الدهون والكتلة العضلية والحمل ومسارات بإشراف مختص.',
      'Sleep, movement & fasting library': 'مكتبة النوم والحركة والصيام',
      'Wellness tools grounded in your real logs and measurements.':
          'أدوات عافية مبنية على سجلاتك وقياساتك الحقيقية.',
      'Offline food libraries': 'مكتبات الطعام دون اتصال',
      'Manage the core library and optional global packs.':
          'أدِر المكتبة الأساسية والحزم العالمية الاختيارية.',
      'Community & friends': 'المجتمع والأصدقاء',
      'Posts, messages, and a moderated community food library.':
          'منشورات ورسائل ومكتبة طعام مجتمعية خاضعة للإشراف.',
      'Region & units': 'المنطقة والوحدات',
      'Your health profile': 'ملفك الصحي',
      'My profile & plan': 'ملفي وخطتي',
      'Edit body data, goal, and activity without restarting onboarding.':
          'عدّل بيانات الجسم والهدف والنشاط دون إعادة الإعداد الأولي.',
      'Sleep': 'النوم',
      'Log sleep and review your measured trends.':
          'سجّل نومك وراجع اتجاهاتك المقاسة.',
      'Movement & recovery': 'الحركة والتعافي',
      'Choose a workout and log your actual movement.':
          'اختر تمرينًا وسجّل حركتك الفعلية.',
      'Fasting rhythm': 'الصيام المتقطع',
      'Track a fasting window with clear health guardrails.':
          'تابع نافذة الصيام ضمن حدود صحية واضحة.',
      'Intelligence & privacy': 'الذكاء والخصوصية',
      'Choose per record whether it may inform local insights, or delete it.':
          'اختر لكل سجل إن كان يمكن استخدامه في الرؤى المحلية أو احذفه.',
      'Help & FAQ': 'المساعدة والأسئلة الشائعة',
      'Answers about account, privacy, logging, and health.':
          'إجابات حول الحساب والخصوصية والتسجيل والصحة.',
      'Local data & app': 'البيانات المحلية والتطبيق',
      'Connected capabilities': 'الخدمات المتصلة',
      'Setup & reset': 'الإعداد وإعادة الضبط',
      'Review initial setup': 'مراجعة الإعداد الأولي',
      'Reopen onboarding without deleting your profile or records.':
          'أعد فتح الإعداد دون حذف ملفك أو سجلاتك.',
      'Location & local time': 'الموقع والوقت المحلي',
      'Choose country and city or detect from this device.':
          'اختر الدولة والمدينة أو اكتشفهما من هذا الجهاز.',
    },
    'fr': {
      'My profile': 'Mon profil',
      'Email settings': 'Paramètres des e-mails',
      'Diary settings': 'Paramètres du journal',
      'Calorie and macro goals': 'Objectifs de calories et macronutriments',
      'System default': 'Paramètre système',
      'Account & data': 'Compte et données',
      'Account and data': 'Compte et données',
      'Manage sign-in or safely restart the account experience.':
          'Gérez la connexion ou relancez l’expérience du compte en toute sécurité.',
      'Sign out and test account again': 'Se déconnecter et retester le compte',
      'Does not delete weight, meals, or local health data.':
          'Ne supprime ni le poids, ni les repas, ni les données de santé locales.',
      'Erase all my local data': 'Effacer toutes mes données locales',
      'Deletes the profile and records after creating a recovery snapshot.':
          'Supprime le profil et les enregistrements après création d’un instantané de récupération.',
      'Today dashboard': 'Tableau Aujourd’hui',
      'Customize Today': 'Personnaliser Aujourd’hui',
      'Show or hide macros, activity, quick log, discovery, and intelligence cards.':
          'Affichez ou masquez les cartes des macros, de l’activité, de la saisie rapide, de la découverte et de l’intelligence.',
      'BIL services': 'Services BIL',
      'BIL plans & memberships': 'Offres et abonnements BIL',
      'Free, Plus, Pro, Coach, Clinic, and Enterprise with monthly or annual billing.':
          'Free, Plus, Pro, Coach, Clinic et Enterprise avec facturation mensuelle ou annuelle.',
      'Nutrition plans': 'Programmes nutritionnels',
      'Keto, low carb, fat loss, lean mass, pregnancy, and supervised pathways.':
          'Kéto, faible en glucides, perte de graisse, masse maigre, grossesse et parcours supervisés.',
      'Sleep, movement & fasting library':
          'Bibliothèque sommeil, mouvement et jeûne',
      'Wellness tools grounded in your real logs and measurements.':
          'Des outils de bien-être fondés sur vos journaux et mesures réels.',
      'Offline food libraries': 'Bibliothèques alimentaires hors ligne',
      'Manage the core library and optional global packs.':
          'Gérez la bibliothèque principale et les packs mondiaux facultatifs.',
      'Community & friends': 'Communauté et amis',
      'Posts, messages, and a moderated community food library.':
          'Publications, messages et bibliothèque alimentaire communautaire modérée.',
      'Region & units': 'Région et unités',
      'Your health profile': 'Votre profil de santé',
      'My profile & plan': 'Mon profil et mon programme',
      'Edit body data, goal, and activity without restarting onboarding.':
          'Modifiez les données corporelles, l’objectif et l’activité sans recommencer la configuration.',
      'Sleep': 'Sommeil',
      'Log sleep and review your measured trends.':
          'Enregistrez votre sommeil et consultez vos tendances mesurées.',
      'Movement & recovery': 'Mouvement et récupération',
      'Choose a workout and log your actual movement.':
          'Choisissez un entraînement et enregistrez votre mouvement réel.',
      'Fasting rhythm': 'Jeûne intermittent',
      'Track a fasting window with clear health guardrails.':
          'Suivez une fenêtre de jeûne avec des limites de santé claires.',
      'Intelligence & privacy': 'Intelligence et confidentialité',
      'Choose per record whether it may inform local insights, or delete it.':
          'Choisissez pour chaque entrée si elle peut alimenter les analyses locales, ou supprimez-la.',
      'Help & FAQ': 'Aide et FAQ',
      'Answers about account, privacy, logging, and health.':
          'Réponses sur le compte, la confidentialité, le suivi et la santé.',
      'Local data & app': 'Données locales et application',
      'Connected capabilities': 'Fonctionnalités connectées',
      'Setup & reset': 'Configuration et réinitialisation',
      'Review initial setup': 'Revoir la configuration initiale',
      'Reopen onboarding without deleting your profile or records.':
          'Rouvrez la configuration sans supprimer votre profil ni vos données.',
      'Location & local time': 'Localisation et heure locale',
      'Choose country and city or detect from this device.':
          'Choisissez le pays et la ville ou détectez-les depuis cet appareil.',
    },
    'es': {
      'My profile': 'Mi perfil',
      'Email settings': 'Ajustes de correo',
      'Diary settings': 'Ajustes del diario',
      'Calorie and macro goals': 'Objetivos de calorías y macros',
      'System default': 'Predeterminado del sistema',
      'Account & data': 'Cuenta y datos',
      'Account and data': 'Cuenta y datos',
      'Manage sign-in or safely restart the account experience.':
          'Gestiona el inicio de sesión o reinicia la experiencia de la cuenta de forma segura.',
      'Sign out and test account again':
          'Cerrar sesión y volver a probar la cuenta',
      'Does not delete weight, meals, or local health data.':
          'No elimina el peso, las comidas ni los datos de salud locales.',
      'Erase all my local data': 'Borrar todos mis datos locales',
      'Deletes the profile and records after creating a recovery snapshot.':
          'Elimina el perfil y los registros después de crear una copia de recuperación.',
      'Today dashboard': 'Panel de Hoy',
      'Customize Today': 'Personalizar Hoy',
      'Show or hide macros, activity, quick log, discovery, and intelligence cards.':
          'Muestra u oculta las tarjetas de macros, actividad, registro rápido, descubrimiento e inteligencia.',
      'BIL services': 'Servicios BIL',
      'BIL plans & memberships': 'Planes y membresías BIL',
      'Free, Plus, Pro, Coach, Clinic, and Enterprise with monthly or annual billing.':
          'Free, Plus, Pro, Coach, Clinic y Enterprise con facturación mensual o anual.',
      'Nutrition plans': 'Planes de nutrición',
      'Keto, low carb, fat loss, lean mass, pregnancy, and supervised pathways.':
          'Keto, bajo en carbohidratos, pérdida de grasa, masa magra, embarazo y programas supervisados.',
      'Sleep, movement & fasting library':
          'Biblioteca de sueño, movimiento y ayuno',
      'Wellness tools grounded in your real logs and measurements.':
          'Herramientas de bienestar basadas en tus registros y mediciones reales.',
      'Offline food libraries': 'Bibliotecas de alimentos sin conexión',
      'Manage the core library and optional global packs.':
          'Gestiona la biblioteca principal y los paquetes globales opcionales.',
      'Community & friends': 'Comunidad y amigos',
      'Posts, messages, and a moderated community food library.':
          'Publicaciones, mensajes y una biblioteca comunitaria de alimentos moderada.',
      'Region & units': 'Región y unidades',
      'Your health profile': 'Tu perfil de salud',
      'My profile & plan': 'Mi perfil y plan',
      'Edit body data, goal, and activity without restarting onboarding.':
          'Edita los datos corporales, el objetivo y la actividad sin reiniciar la configuración.',
      'Sleep': 'Sueño',
      'Log sleep and review your measured trends.':
          'Registra el sueño y revisa tus tendencias medidas.',
      'Movement & recovery': 'Movimiento y recuperación',
      'Choose a workout and log your actual movement.':
          'Elige un entrenamiento y registra tu movimiento real.',
      'Fasting rhythm': 'Ayuno intermitente',
      'Track a fasting window with clear health guardrails.':
          'Sigue una ventana de ayuno con límites de salud claros.',
      'Intelligence & privacy': 'Inteligencia y privacidad',
      'Choose per record whether it may inform local insights, or delete it.':
          'Elige para cada registro si puede aportar información local o elimínalo.',
      'Help & FAQ': 'Ayuda y preguntas frecuentes',
      'Answers about account, privacy, logging, and health.':
          'Respuestas sobre cuenta, privacidad, registro y salud.',
      'Local data & app': 'Datos locales y aplicación',
      'Connected capabilities': 'Funciones conectadas',
      'Setup & reset': 'Configuración y restablecimiento',
      'Review initial setup': 'Revisar configuración inicial',
      'Reopen onboarding without deleting your profile or records.':
          'Vuelve a abrir la configuración sin eliminar tu perfil ni tus registros.',
      'Location & local time': 'Ubicación y hora local',
      'Choose country and city or detect from this device.':
          'Elige país y ciudad o detéctalos desde este dispositivo.',
    },
    'tr': {
      'My profile': 'Profilim',
      'Email settings': 'E-posta ayarları',
      'Diary settings': 'Günlük ayarları',
      'Calorie and macro goals': 'Kalori ve makro hedefleri',
      'System default': 'Sistem varsayılanı',
      'Account & data': 'Hesap ve veriler',
      'Account and data': 'Hesap ve veriler',
      'Manage sign-in or safely restart the account experience.':
          'Oturum açmayı yönetin veya hesap deneyimini güvenle yeniden başlatın.',
      'Sign out and test account again': 'Çıkış yap ve hesabı yeniden dene',
      'Does not delete weight, meals, or local health data.':
          'Kilo, öğün veya yerel sağlık verilerini silmez.',
      'Erase all my local data': 'Tüm yerel verilerimi sil',
      'Deletes the profile and records after creating a recovery snapshot.':
          'Kurtarma anlık görüntüsü oluşturduktan sonra profili ve kayıtları siler.',
      'Today dashboard': 'Bugün paneli',
      'Customize Today': 'Bugün’ü özelleştir',
      'Show or hide macros, activity, quick log, discovery, and intelligence cards.':
          'Makro, aktivite, hızlı kayıt, keşif ve zekâ kartlarını gösterin veya gizleyin.',
      'BIL services': 'BIL hizmetleri',
      'BIL plans & memberships': 'BIL planları ve üyelikleri',
      'Free, Plus, Pro, Coach, Clinic, and Enterprise with monthly or annual billing.':
          'Aylık veya yıllık ödemeli Free, Plus, Pro, Coach, Clinic ve Enterprise.',
      'Nutrition plans': 'Beslenme planları',
      'Keto, low carb, fat loss, lean mass, pregnancy, and supervised pathways.':
          'Keto, düşük karbonhidrat, yağ kaybı, yağsız kütle, gebelik ve gözetimli programlar.',
      'Sleep, movement & fasting library': 'Uyku, hareket ve oruç kitaplığı',
      'Wellness tools grounded in your real logs and measurements.':
          'Gerçek kayıt ve ölçümlerinize dayalı sağlık araçları.',
      'Offline food libraries': 'Çevrimdışı gıda kitaplıkları',
      'Manage the core library and optional global packs.':
          'Temel kitaplığı ve isteğe bağlı küresel paketleri yönetin.',
      'Community & friends': 'Topluluk ve arkadaşlar',
      'Posts, messages, and a moderated community food library.':
          'Gönderiler, mesajlar ve denetlenen topluluk gıda kitaplığı.',
      'Region & units': 'Bölge ve birimler',
      'Your health profile': 'Sağlık profiliniz',
      'My profile & plan': 'Profilim ve planım',
      'Edit body data, goal, and activity without restarting onboarding.':
          'Başlangıç kurulumunu yeniden başlatmadan vücut verilerini, hedefi ve aktiviteyi düzenleyin.',
      'Sleep': 'Uyku',
      'Log sleep and review your measured trends.':
          'Uykunuzu kaydedin ve ölçülen eğilimlerinizi inceleyin.',
      'Movement & recovery': 'Hareket ve toparlanma',
      'Choose a workout and log your actual movement.':
          'Bir antrenman seçin ve gerçek hareketinizi kaydedin.',
      'Fasting rhythm': 'Aralıklı oruç',
      'Track a fasting window with clear health guardrails.':
          'Net sağlık sınırlarıyla oruç aralığını takip edin.',
      'Intelligence & privacy': 'Zekâ ve gizlilik',
      'Choose per record whether it may inform local insights, or delete it.':
          'Her kaydın yerel içgörülerde kullanılıp kullanılmayacağını seçin veya kaydı silin.',
      'Help & FAQ': 'Yardım ve SSS',
      'Answers about account, privacy, logging, and health.':
          'Hesap, gizlilik, kayıt ve sağlık hakkında yanıtlar.',
      'Local data & app': 'Yerel veriler ve uygulama',
      'Connected capabilities': 'Bağlı özellikler',
      'Setup & reset': 'Kurulum ve sıfırlama',
      'Review initial setup': 'İlk kurulumu gözden geçir',
      'Reopen onboarding without deleting your profile or records.':
          'Profilinizi veya kayıtlarınızı silmeden kurulumu yeniden açın.',
      'Location & local time': 'Konum ve yerel saat',
      'Choose country and city or detect from this device.':
          'Ülke ve şehir seçin veya bu cihazdan algılayın.',
    },
  };
}
