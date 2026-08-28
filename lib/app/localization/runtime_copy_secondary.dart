/// Extended reviewed runtime translations. Kept separate to preserve the
/// architecture source-size ceiling.
abstract final class RuntimeCopySecondary {
  static const values = <String, Map<String, String>>{
    'Keep your BIL data safe?': {
      'ar': 'هل تريد الاحتفاظ ببيانات BIL بأمان؟',
      'en': 'Keep your BIL data safe?',
      'fr': 'Protéger vos données BIL ?',
      'es': '¿Quieres proteger tus datos de BIL?',
      'tr': 'BIL verileriniz güvende kalsın mı?',
    },
    'Encrypted backup stores your profile, weight and water so BIL can restore them after reinstalling or changing devices. Nutrition stays on this device.': {
      'ar':
          'تحتفظ النسخة المشفّرة بملفك ووزنك ومياهك ليستعيدها BIL بعد إعادة التثبيت أو تغيير الجهاز. تبقى بيانات التغذية على هذا الجهاز.',
      'en':
          'Encrypted backup stores your profile, weight and water so BIL can restore them after reinstalling or changing devices. Nutrition stays on this device.',
      'fr':
          'La sauvegarde chiffrée conserve votre profil, votre poids et votre eau afin que BIL puisse les restaurer après une réinstallation ou un changement d’appareil. La nutrition reste sur cet appareil.',
      'es':
          'La copia cifrada guarda tu perfil, peso y agua para que BIL pueda restaurarlos tras reinstalar o cambiar de dispositivo. La nutrición permanece en este dispositivo.',
      'tr':
          'Şifreli yedek, yeniden yükleme veya cihaz değişikliğinden sonra BIL’in geri yükleyebilmesi için profil, kilo ve su verilerinizi saklar. Beslenme verileri bu cihazda kalır.',
    },
    'If you later turn sync off, future uploads stop. An existing cloud copy is retained until you delete your account or request data deletion in Privacy.': {
      'ar':
          'إذا أوقفت المزامنة لاحقًا، تتوقف عمليات الرفع الجديدة. تبقى النسخة السحابية الموجودة حتى تحذف حسابك أو تطلب حذف البيانات من الخصوصية.',
      'en':
          'If you later turn sync off, future uploads stop. An existing cloud copy is retained until you delete your account or request data deletion in Privacy.',
      'fr':
          'Si vous désactivez ensuite la synchronisation, les futurs envois s’arrêtent. Une copie cloud existante reste conservée jusqu’à la suppression du compte ou une demande d’effacement dans Confidentialité.',
      'es':
          'Si desactivas la sincronización más adelante, se detendrán las futuras cargas. La copia existente se conservará hasta que elimines tu cuenta o solicites borrar los datos en Privacidad.',
      'tr':
          'Eşitlemeyi daha sonra kapatırsanız yeni yüklemeler durur. Mevcut bulut kopyası, hesabınızı silene veya Gizlilik bölümünden veri silme talebinde bulunana kadar saklanır.',
    },
    'Keep only on this device': {
      'ar': 'الاحتفاظ على هذا الجهاز فقط',
      'en': 'Keep only on this device',
      'fr': 'Conserver sur cet appareil uniquement',
      'es': 'Guardar solo en este dispositivo',
      'tr': 'Yalnızca bu cihazda tut',
    },
    'Enable encrypted backup': {
      'ar': 'تشغيل النسخة المشفّرة',
      'en': 'Enable encrypted backup',
      'fr': 'Activer la sauvegarde chiffrée',
      'es': 'Activar copia cifrada',
      'tr': 'Şifreli yedeklemeyi aç',
    },
    'Cloud sync could not run. Check consent and internet.': {
      'ar': 'تعذر تشغيل المزامنة. تحقق من الموافقة والاتصال بالإنترنت.',
      'en': 'Cloud sync could not run. Check consent and internet.',
      'fr':
          'La synchronisation a échoué. Vérifiez le consentement et la connexion Internet.',
      'es':
          'No se pudo sincronizar. Comprueba el consentimiento y la conexión a Internet.',
      'tr':
          'Bulut eşitleme çalıştırılamadı. Onayı ve internet bağlantısını kontrol edin.',
    },
    'Export local data': {
      'ar': 'تصدير البيانات المحلية',
      'en': 'Export local data',
      'fr': 'Exporter les données locales',
      'es': 'Exportar datos locales',
      'tr': 'Yerel verileri dışa aktar',
    },
    'Cloud sync': {
      'ar': 'المزامنة السحابية',
      'en': 'Cloud sync',
      'fr': 'Synchronisation cloud',
      'es': 'Sincronización en la nube',
      'tr': 'Bulut eşitleme',
    },
    'Units': {
      'ar': 'الوحدات',
      'en': 'Units',
      'fr': 'Unités',
      'es': 'Unidades',
      'tr': 'Birimler',
    },
    'Metric (kg, cm)': {
      'ar': 'متري (كجم، سم)',
      'en': 'Metric (kg, cm)',
      'fr': 'Métrique (kg, cm)',
      'es': 'Métrico (kg, cm)',
      'tr': 'Metrik (kg, cm)',
    },
    'Imperial (lb, in)': {
      'ar': 'إمبراطوري (رطل، بوصة)',
      'en': 'Imperial (lb, in)',
      'fr': 'Impérial (lb, in)',
      'es': 'Imperial (lb, in)',
      'tr': 'İngiliz (lb, in)',
    },
    'Follow device': {
      'ar': 'حسب الجهاز',
      'en': 'Follow device',
      'fr': 'Suivre l’appareil',
      'es': 'Seguir el dispositivo',
      'tr': 'Cihazı izle',
    },
    'Daylight': {
      'ar': 'ضوء النهار',
      'en': 'Daylight',
      'fr': 'Mode clair',
      'es': 'Modo claro',
      'tr': 'Açık mod',
    },
    'Night mode': {
      'ar': 'الوضع الليلي',
      'en': 'Night mode',
      'fr': 'Mode sombre',
      'es': 'Modo oscuro',
      'tr': 'Koyu mod',
    },
    'High contrast': {
      'ar': 'تباين مرتفع',
      'en': 'High contrast',
      'fr': 'Contraste élevé',
      'es': 'Alto contraste',
      'tr': 'Yüksek kontrast',
    },
    'Increase separation between text, controls, and surfaces.': {
      'ar': 'زيادة التمييز بين النصوص وعناصر التحكم والأسطح.',
      'en': 'Increase separation between text, controls, and surfaces.',
      'fr':
          'Augmente la distinction entre les textes, les commandes et les surfaces.',
      'es': 'Aumenta la separación entre textos, controles y superficies.',
      'tr': 'Metin, denetim ve yüzeyler arasındaki ayrımı artırır.',
    },
    'Reduce motion': {
      'ar': 'تقليل الحركة',
      'en': 'Reduce motion',
      'fr': 'Réduire les animations',
      'es': 'Reducir movimiento',
      'tr': 'Hareketi azalt',
    },
    'Minimize nonessential interface animation.': {
      'ar': 'تقليل حركات الواجهة غير الضرورية.',
      'en': 'Minimize nonessential interface animation.',
      'fr': 'Réduit les animations non essentielles.',
      'es': 'Reduce las animaciones no esenciales.',
      'tr': 'Gereksiz arayüz hareketlerini azaltır.',
    },
    'Targets and plan': {
      'ar': 'الأهداف والخطة',
      'en': 'Targets and plan',
      'fr': 'Objectifs et programme',
      'es': 'Objetivos y plan',
      'tr': 'Hedefler ve plan',
    },
    'Compare recommendations, assumptions, and your overrides.': {
      'ar': 'قارن التوصيات والافتراضات وتعديلاتك.',
      'en': 'Compare recommendations, assumptions, and your overrides.',
      'fr': 'Comparez les recommandations, les hypothèses et vos ajustements.',
      'es': 'Compara recomendaciones, supuestos y ajustes.',
      'tr': 'Önerileri, varsayımları ve değişikliklerinizi karşılaştırın.',
    },
    'Decision Memory': {
      'ar': 'ذاكرة القرارات',
      'en': 'Decision Memory',
      'fr': 'Mémoire des décisions',
      'es': 'Memoria de decisiones',
      'tr': 'Karar Hafızası',
    },
    'Review, rate, disable, or delete remembered actions.': {
      'ar': 'راجع الإجراءات المتذكّرة وقيّمها أو عطّلها أو احذفها.',
      'en': 'Review, rate, disable, or delete remembered actions.',
      'fr':
          'Consultez, évaluez, désactivez ou supprimez les actions mémorisées.',
      'es': 'Revisa, valora, desactiva o elimina acciones recordadas.',
      'tr':
          'Hatırlanan eylemleri inceleyin, değerlendirin, kapatın veya silin.',
    },
    'Life context': {
      'ar': 'سياق الحياة',
      'en': 'Life context',
      'fr': 'Contexte de vie',
      'es': 'Contexto de vida',
      'tr': 'Yaşam bağlamı',
    },
    'Personal experiments': {
      'ar': 'التجارب الشخصية',
      'en': 'Personal experiments',
      'fr': 'Expériences personnelles',
      'es': 'Experimentos personales',
      'tr': 'Kişisel deneyler',
    },
    'Test a cautious hypothesis and record limitations.': {
      'ar': 'اختبر فرضية حذرة وسجّل القيود.',
      'en': 'Test a cautious hypothesis and record limitations.',
      'fr': 'Testez une hypothèse prudente et consignez ses limites.',
      'es': 'Prueba una hipótesis prudente y registra sus límites.',
      'tr': 'Temkinli bir varsayımı test edin ve sınırlamaları kaydedin.',
    },
    'Your data remains on this device.': {
      'ar': 'تبقى بياناتك على هذا الجهاز.',
      'en': 'Your data remains on this device.',
      'fr': 'Vos données restent sur cet appareil.',
      'es': 'Tus datos permanecen en este dispositivo.',
      'tr': 'Verileriniz bu cihazda kalır.',
    },
    'Copy a JSON export to the clipboard.': {
      'ar': 'انسخ تصدير JSON إلى الحافظة.',
      'en': 'Copy a JSON export to the clipboard.',
      'fr': 'Copiez une exportation JSON dans le presse-papiers.',
      'es': 'Copia una exportación JSON al portapapeles.',
      'tr': 'JSON dışa aktarımını panoya kopyalayın.',
    },
    'App version': {
      'ar': 'إصدار التطبيق',
      'en': 'App version',
      'fr': 'Version de l’application',
      'es': 'Versión de la aplicación',
      'tr': 'Uygulama sürümü',
    },
    'Account': {
      'ar': 'الحساب',
      'en': 'Account',
      'fr': 'Compte',
      'es': 'Cuenta',
      'tr': 'Hesap',
    },
    'Ask BIL': {
      'ar': 'اسأل BIL',
      'en': 'Ask BIL',
      'fr': 'Demander à BIL',
      'es': 'Preguntar a BIL',
      'tr': 'BIL’e sor',
    },
    'Community': {
      'ar': 'المجتمع',
      'en': 'Community',
      'fr': 'Communauté',
      'es': 'Comunidad',
      'tr': 'Topluluk',
    },
    'Coach platform': {
      'ar': 'منصة المختص',
      'en': 'Coach platform',
      'fr': 'Plateforme du coach',
      'es': 'Plataforma del entrenador',
      'tr': 'Koç platformu',
    },
    'Remote update channel': {
      'ar': 'قناة التحديث البعيد',
      'en': 'Remote update channel',
      'fr': 'Canal de mise à jour à distance',
      'es': 'Canal de actualización remota',
      'tr': 'Uzaktan güncelleme kanalı',
    },
    'Account and data': {
      'ar': 'الحساب والبيانات',
      'en': 'Account and data',
      'fr': 'Compte et données',
      'es': 'Cuenta y datos',
      'tr': 'Hesap ve veriler',
    },
    'Manage sign-in or safely restart the account experience.': {
      'ar': 'إدارة تسجيل الدخول أو بدء تجربة آمنة من جديد.',
      'en': 'Manage sign-in or safely restart the account experience.',
      'fr':
          'Gérez la connexion ou redémarrez l’expérience du compte en toute sécurité.',
      'es':
          'Gestiona el inicio de sesión o reinicia de forma segura la experiencia de la cuenta.',
      'tr':
          'Oturum açmayı yönetin veya hesap deneyimini güvenle yeniden başlatın.',
    },
    'Sign out and test account again': {
      'ar': 'تسجيل الخروج وتجربة الحساب من جديد',
      'en': 'Sign out and test account again',
      'fr': 'Se déconnecter et retester le compte',
      'es': 'Cerrar sesión y volver a probar la cuenta',
      'tr': 'Çıkış yap ve hesabı yeniden dene',
    },
    'Does not delete weight, meals, or local health data.': {
      'ar': 'لا يحذف الوزن أو الوجبات أو بياناتك الصحية المحلية.',
      'en': 'Does not delete weight, meals, or local health data.',
      'fr':
          'Ne supprime ni le poids, ni les repas, ni les données de santé locales.',
      'es': 'No elimina el peso, las comidas ni los datos de salud locales.',
      'tr': 'Kilo, öğün veya yerel sağlık verilerini silmez.',
    },
    'Erase all my local data': {
      'ar': 'مسح جميع بياناتي المحلية',
      'en': 'Erase all my local data',
      'fr': 'Effacer toutes mes données locales',
      'es': 'Borrar todos mis datos locales',
      'tr': 'Tüm yerel verilerimi sil',
    },
    'Deletes the profile and records after creating a recovery snapshot.': {
      'ar': 'يحذف الملف والسجلات بعد إنشاء لقطة استعادة آمنة.',
      'en':
          'Deletes the profile and records after creating a recovery snapshot.',
      'fr':
          'Supprime le profil et les données après la création d’une sauvegarde de récupération.',
      'es':
          'Elimina el perfil y los registros tras crear una copia de recuperación.',
      'tr':
          'Kurtarma anlık görüntüsü oluşturduktan sonra profili ve kayıtları siler.',
    },
    'BIL plans & memberships': {
      'ar': 'خطط وعضويات BIL',
      'en': 'BIL plans & memberships',
      'fr': 'Offres et abonnements BIL',
      'es': 'Planes y membresías BIL',
      'tr': 'BIL planları ve üyelikleri',
    },
    'Free, Plus, Pro, Coach, Clinic, and Enterprise with monthly or annual billing.': {
      'ar':
          'Free وPlus وPro وCoach وClinic وEnterprise، مع اختيار شهري أو سنوي.',
      'en':
          'Free, Plus, Pro, Coach, Clinic, and Enterprise with monthly or annual billing.',
      'fr':
          'Free, Plus, Pro, Coach, Clinic et Enterprise avec facturation mensuelle ou annuelle.',
      'es':
          'Free, Plus, Pro, Coach, Clinic y Enterprise con facturación mensual o anual.',
      'tr':
          'Aylık veya yıllık ödemeli Free, Plus, Pro, Coach, Clinic ve Enterprise.',
    },
    'Nutrition plans': {
      'ar': 'خطط التغذية',
      'en': 'Nutrition plans',
      'fr': 'Programmes nutritionnels',
      'es': 'Planes de nutrición',
      'tr': 'Beslenme planları',
    },
    'Keto, low carb, fat loss, lean mass, pregnancy, and supervised pathways.': {
      'ar': 'كيتو، لو كارب، تنشيف، تضخيم، الحمل، ومسارات بإشراف مختص.',
      'en':
          'Keto, low carb, fat loss, lean mass, pregnancy, and supervised pathways.',
      'fr':
          'Keto, faible en glucides, perte de graisse, masse maigre, grossesse et parcours supervisés.',
      'es':
          'Keto, bajo en carbohidratos, pérdida de grasa, masa magra, embarazo y rutas supervisadas.',
      'tr':
          'Keto, düşük karbonhidrat, yağ kaybı, yağsız kütle, gebelik ve uzman gözetimli yollar.',
    },
    'Sleep, movement & fasting library': {
      'ar': 'مكتبة النوم والحركة والصيام',
      'en': 'Sleep, movement & fasting library',
      'fr': 'Bibliothèque sommeil, mouvement et jeûne',
      'es': 'Biblioteca de sueño, movimiento y ayuno',
      'tr': 'Uyku, hareket ve oruç kitaplığı',
    },
    'Wellness tools grounded in your real logs and measurements.': {
      'ar': 'أدوات العافية المبنية على سجلك وبياناتك الحقيقية.',
      'en': 'Wellness tools grounded in your real logs and measurements.',
      'fr': 'Des outils de bien-être fondés sur vos journaux et mesures réels.',
      'es':
          'Herramientas de bienestar basadas en tus registros y mediciones reales.',
      'tr': 'Gerçek kayıt ve ölçümlerinize dayalı sağlık araçları.',
    },
    'Offline food libraries': {
      'ar': 'مكتبات الغذاء دون إنترنت',
      'en': 'Offline food libraries',
      'fr': 'Bibliothèques alimentaires hors ligne',
      'es': 'Bibliotecas de alimentos sin conexión',
      'tr': 'Çevrimdışı yiyecek kitaplıkları',
    },
    'Manage the core library and optional global packs.': {
      'ar': 'إدارة المكتبة الأساسية والحزم العالمية الاختيارية.',
      'en': 'Manage the core library and optional global packs.',
      'fr':
          'Gérez la bibliothèque principale et les packs mondiaux facultatifs.',
      'es':
          'Gestiona la biblioteca principal y los paquetes globales opcionales.',
      'tr': 'Temel kitaplığı ve isteğe bağlı küresel paketleri yönetin.',
    },
    'Devices & connected health': {
      'ar': 'الأجهزة والصحة المتصلة',
      'en': 'Devices & connected health',
      'fr': 'Appareils et santé connectée',
      'es': 'Dispositivos y salud conectada',
      'tr': 'Cihazlar ve bağlı sağlık',
    },
    'Manage the watch, compatible fitness devices, and supported measurement sources.': {
      'ar': 'إدارة الساعة وأجهزة اللياقة المتوافقة ومصادر القياس المدعومة.',
      'en':
          'Manage the watch, compatible fitness devices, and supported measurement sources.',
      'fr':
          'Gérez la montre, les appareils de fitness compatibles et les sources de mesure prises en charge.',
      'es':
          'Gestiona el reloj, los dispositivos de fitness compatibles y las fuentes de medición admitidas.',
      'tr':
          'Saati, uyumlu fitness cihazlarını ve desteklenen ölçüm kaynaklarını yönetin.',
    },
    'Daily reminders': {
      'ar': 'التنبيهات اليومية',
      'en': 'Daily reminders',
      'fr': 'Rappels quotidiens',
      'es': 'Recordatorios diarios',
      'tr': 'Günlük hatırlatıcılar',
    },
    'Choose weight, meal, water, and weekly-review reminders.': {
      'ar': 'حدد تنبيهات الوزن والوجبات والماء والمراجعة الأسبوعية.',
      'en': 'Choose weight, meal, water, and weekly-review reminders.',
      'fr':
          'Choisissez les rappels de poids, repas, eau et bilan hebdomadaire.',
      'es': 'Elige recordatorios de peso, comidas, agua y revisión semanal.',
      'tr': 'Kilo, öğün, su ve haftalık inceleme hatırlatıcılarını seçin.',
    },
    'Weekly report': {
      'ar': 'التقرير الأسبوعي',
      'en': 'Weekly report',
      'fr': 'Rapport hebdomadaire',
      'es': 'Informe semanal',
      'tr': 'Haftalık rapor',
    },
    'A visual summary based only on your measured and logged data.': {
      'ar': 'ملخص مصور يعتمد فقط على قياساتك وسجلاتك الفعلية.',
      'en': 'A visual summary based only on your measured and logged data.',
      'fr':
          'Un résumé visuel fondé uniquement sur vos mesures et données enregistrées.',
      'es':
          'Un resumen visual basado solo en tus mediciones y datos registrados.',
      'tr': 'Yalnızca ölçülen ve kaydedilen verilerinize dayalı görsel özet.',
    },
    'Community & friends': {
      'ar': 'المجتمع والأصدقاء',
      'en': 'Community & friends',
      'fr': 'Communauté et amis',
      'es': 'Comunidad y amigos',
      'tr': 'Topluluk ve arkadaşlar',
    },
    'Posts, messages, and a moderated community food library.': {
      'ar': 'مشاركات ورسائل ومكتبة غذاء مجتمعية خاضعة للمراجعة.',
      'en': 'Posts, messages, and a moderated community food library.',
      'fr':
          'Publications, messages et bibliothèque alimentaire communautaire modérée.',
      'es':
          'Publicaciones, mensajes y biblioteca comunitaria de alimentos moderada.',
      'tr': 'Gönderiler, mesajlar ve denetlenen topluluk yiyecek kitaplığı.',
    },
    'My profile & plan': {
      'ar': 'ملفي وخطتي',
      'en': 'My profile & plan',
      'fr': 'Mon profil et mon programme',
      'es': 'Mi perfil y plan',
      'tr': 'Profilim ve planım',
    },
    'Edit body data, goal, and activity without restarting onboarding.': {
      'ar': 'عدّل بيانات الجسم والهدف والنشاط دون إعادة شاشة الترحيب.',
      'en': 'Edit body data, goal, and activity without restarting onboarding.',
      'fr':
          'Modifiez les données corporelles, l’objectif et l’activité sans recommencer l’accueil.',
      'es':
          'Edita los datos corporales, el objetivo y la actividad sin reiniciar la bienvenida.',
      'tr':
          'Başlangıç akışını yeniden başlatmadan beden verilerini, hedefi ve etkinliği düzenleyin.',
    },
    'Sleep, movement & rhythm': {
      'ar': 'النوم والحركة والإيقاع',
      'en': 'Sleep, movement & rhythm',
      'fr': 'Sommeil, mouvement et rythme',
      'es': 'Sueño, movimiento y ritmo',
      'tr': 'Uyku, hareket ve ritim',
    },
    'Wellness tools grounded only in your logs and connected sources.': {
      'ar': 'أدوات صحية تعتمد فقط على سجلاتك ومصادرك المتصلة.',
      'en': 'Wellness tools grounded only in your logs and connected sources.',
      'fr':
          'Des outils de bien-être fondés uniquement sur vos journaux et sources connectées.',
      'es':
          'Herramientas de bienestar basadas solo en tus registros y fuentes conectadas.',
      'tr':
          'Yalnızca kayıtlarınıza ve bağlı kaynaklarınıza dayalı sağlık araçları.',
    },
    'Review supported sources, connection state, and real readings.': {
      'ar': 'راجع المصادر المدعومة وحالة الاتصال والقراءات الحقيقية.',
      'en': 'Review supported sources, connection state, and real readings.',
      'fr':
          'Consultez les sources prises en charge, l’état de connexion et les mesures réelles.',
      'es':
          'Revisa las fuentes compatibles, el estado de conexión y las lecturas reales.',
      'tr':
          'Desteklenen kaynakları, bağlantı durumunu ve gerçek okumaları inceleyin.',
    },
    'Choose per record whether it may inform local insights, or delete it.': {
      'ar':
          'اختر لكل سجل ما إذا كان يمكن استخدامه في الاستنتاجات المحلية، أو احذفه.',
      'en':
          'Choose per record whether it may inform local insights, or delete it.',
      'fr':
          'Choisissez pour chaque donnée si elle peut alimenter les analyses locales, ou supprimez-la.',
      'es':
          'Elige por registro si puede contribuir a las conclusiones locales o elimínalo.',
      'tr':
          'Her kaydın yerel içgörülere katkı sağlayıp sağlamayacağını seçin veya kaydı silin.',
    },
    'Review initial setup': {
      'ar': 'مراجعة الإعداد الأولي',
      'en': 'Review initial setup',
      'fr': 'Revoir la configuration initiale',
      'es': 'Revisar configuración inicial',
      'tr': 'İlk kurulumu gözden geçir',
    },
    'Reopen onboarding without deleting your profile or records.': {
      'ar': 'أعد فتح خطوات الإعداد دون حذف السجلات أو الملف الشخصي.',
      'en': 'Reopen onboarding without deleting your profile or records.',
      'fr': 'Rouvrez l’accueil sans supprimer votre profil ni vos données.',
      'es':
          'Vuelve a abrir la bienvenida sin eliminar tu perfil ni tus registros.',
      'tr':
          'Profilinizi veya kayıtlarınızı silmeden başlangıç akışını yeniden açın.',
    },
    'Your usual meals could not be loaded.': {
      'ar': 'تعذر تحميل وجباتك المعتادة.',
      'en': 'Your usual meals could not be loaded.',
      'fr': 'Impossible de charger vos repas habituels.',
      'es': 'No se pudieron cargar tus comidas habituales.',
      'tr': 'Her zamanki öğünleriniz yüklenemedi.',
    },
    'Choose where to save your private export.': {
      'ar': 'اختر مكان حفظ تصديرك الخاص.',
      'en': 'Choose where to save your private export.',
      'fr': 'Choisissez où enregistrer votre exportation privée.',
      'es': 'Elige dónde guardar tu exportación privada.',
      'tr': 'Özel dışa aktarımınızı nereye kaydedeceğinizi seçin.',
    },
    'No observation days yet': {
      'ar': 'لا توجد أيام رصد بعد',
      'en': 'No observation days yet',
      'fr': 'Aucun jour d’observation pour le moment',
      'es': 'Aún no hay días de observación',
      'tr': 'Henüz gözlem günü yok',
    },
    'Add weight, meals, and water to establish a baseline': {
      'ar': 'أضف الوزن والوجبات والماء لإنشاء خط أساس',
      'en': 'Add weight, meals, and water to establish a baseline',
      'fr': 'Ajoutez le poids, les repas et l’eau pour établir une référence',
      'es': 'Añade peso, comidas y agua para establecer una referencia',
      'tr': 'Bir başlangıç düzeyi oluşturmak için kilo, öğün ve su ekleyin',
    },
    'Current measured point': {
      'ar': 'نقطة القياس الحالية',
      'en': 'Current measured point',
      'fr': 'Point mesuré actuel',
      'es': 'Punto medido actual',
      'tr': 'Mevcut ölçüm noktası',
    },
    'Potassium': {
      'ar': 'البوتاسيوم',
      'en': 'Potassium',
      'fr': 'Potassium',
      'es': 'Potasio',
      'tr': 'Potasyum',
    },
    'Magnesium': {
      'ar': 'المغنيسيوم',
      'en': 'Magnesium',
      'fr': 'Magnésium',
      'es': 'Magnesio',
      'tr': 'Magnezyum',
    },
  };
}
