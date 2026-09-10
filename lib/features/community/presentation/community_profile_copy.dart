part of 'community_profile_page.dart';

class _CommunityProfileCopy {
  const _CommunityProfileCopy({
    required this.languageCode,
    required this.title,
    required this.displayName,
    required this.bio,
    required this.discoverable,
    required this.discoverableHelp,
    required this.save,
    required this.saved,
    required this.invalidName,
    required this.loadFailed,
    required this.saveFailed,
    required this.privacy,
  });

  factory _CommunityProfileCopy.of(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return switch (language) {
      'ar' => const _CommunityProfileCopy(
        languageCode: 'ar',
        title: 'ملف المجتمع',
        displayName: 'الاسم الظاهر',
        bio: 'نبذة',
        discoverable: 'السماح بالعثور عليّ',
        discoverableHelp: 'يمكن للأعضاء العثور عليك وإرسال طلب صداقة.',
        save: 'حفظ الملف',
        saved: 'تم حفظ ملف المجتمع.',
        invalidName: 'اكتب اسمًا من حرفين على الأقل.',
        loadFailed: 'تعذر تحميل ملف المجتمع بأمان.',
        saveFailed: 'تعذر حفظ الملف الآن. حاول مجددًا.',
        privacy: 'لا تظهر قياساتك أو يومياتك الصحية في ملف المجتمع.',
      ),
      'fr' => const _CommunityProfileCopy(
        languageCode: 'fr',
        title: 'Profil communautaire',
        displayName: 'Nom affiché',
        bio: 'Bio',
        discoverable: 'Autoriser la découverte',
        discoverableHelp: 'Les membres peuvent vous trouver et vous inviter.',
        save: 'Enregistrer',
        saved: 'Profil enregistré.',
        invalidName: 'Saisissez au moins deux caractères.',
        loadFailed: 'Impossible de charger le profil.',
        saveFailed: 'Impossible d’enregistrer maintenant.',
        privacy: 'Vos mesures et journaux de santé restent privés.',
      ),
      'es' => const _CommunityProfileCopy(
        languageCode: 'es',
        title: 'Perfil de comunidad',
        displayName: 'Nombre visible',
        bio: 'Biografía',
        discoverable: 'Permitir que me encuentren',
        discoverableHelp:
            'Los miembros pueden encontrarte y enviarte solicitudes.',
        save: 'Guardar',
        saved: 'Perfil guardado.',
        invalidName: 'Escribe al menos dos caracteres.',
        loadFailed: 'No se pudo cargar el perfil.',
        saveFailed: 'No se pudo guardar ahora.',
        privacy: 'Tus medidas y registros de salud siguen siendo privados.',
      ),
      'tr' => const _CommunityProfileCopy(
        languageCode: 'tr',
        title: 'Topluluk profili',
        displayName: 'Görünen ad',
        bio: 'Hakkında',
        discoverable: 'Bulunmama izin ver',
        discoverableHelp: 'Üyeler sizi bulabilir ve istek gönderebilir.',
        save: 'Kaydet',
        saved: 'Profil kaydedildi.',
        invalidName: 'En az iki karakter yazın.',
        loadFailed: 'Profil yüklenemedi.',
        saveFailed: 'Profil şu anda kaydedilemedi.',
        privacy: 'Sağlık ölçümleriniz ve günlükleriniz gizli kalır.',
      ),
      _ => _CommunityProfileCopy.extended(context),
    };
  }

  factory _CommunityProfileCopy.extended(BuildContext context) {
    String t(String value) => AppLocalizations.of(context).text(value);
    return _CommunityProfileCopy(
      languageCode: BilLocalePolicy.canonicalTag(
        Localizations.localeOf(context),
      ),
      title: t('Community profile'),
      displayName: t('Display name'),
      bio: t('Bio'),
      discoverable: t('Let people find me'),
      discoverableHelp: t('Members can find you and send a friend request.'),
      save: t('Save profile'),
      saved: t('Community profile saved.'),
      invalidName: t('Enter at least two characters.'),
      loadFailed: t('Could not load your community profile safely.'),
      saveFailed: t('Could not save your profile now. Try again.'),
      privacy: t('Your measurements and health logs stay private.'),
    );
  }

  final String languageCode,
      title,
      displayName,
      bio,
      discoverable,
      discoverableHelp;
  final String save, saved, invalidName, loadFailed, saveFailed, privacy;
}

extension _CommunityPrivacyCopy on _CommunityProfileCopy {
  String _t(String en, String ar) =>
      communityTextForLanguage(languageCode, en, ar);
  String get profileVisibility =>
      _t('Who can see my profile', 'من يمكنه رؤية ملفي');
  String get allowFriendRequests =>
      _t('Allow friend requests', 'السماح بطلبات الصداقة');
  String get username =>
      _t('BIL username (optional)', 'اسم مستخدم BIL (اختياري)');
  String get myBilCode => _t('My BIL Code', 'رمز BIL الخاص بي');
  String get usernameHelp => _t(
    'Optional. If left blank, BIL creates a temporary handle for your code. A username can be chosen once later.',
    'اختياري. إذا تركته فارغًا، ينشئ BIL اسمًا مؤقتًا لرمزك. ويمكنك اختيار اسم مستخدم دائم مرة واحدة لاحقًا.',
  );
  String get bilCodeHelp => _t(
    'A BIL Code is created after your profile is saved. It does not require adding a friend first.',
    'يُنشأ رمز BIL بعد حفظ ملفك. ولا يتطلب إضافة صديق أولًا.',
  );
  String get saveProfileAndCreateBilCode =>
      _t('Save profile and create BIL Code', 'احفظ الملف وأنشئ رمز BIL');
  String get usernameLocked => _t(
    'This username is your permanent public Community identity.',
    'اسم المستخدم هذا هو هويتك العامة الدائمة في المجتمع.',
  );
  String get invalidUsername => _t(
    'Use 3–30 lowercase letters, numbers, or underscores, beginning with a letter. Reserved names are unavailable.',
    'استخدم من 3 إلى 30 حرفًا إنجليزيًا صغيرًا أو رقمًا أو شرطة سفلية مع البدء بحرف. الأسماء المحجوزة غير متاحة.',
  );
  String get allowFollows => _t('Allow follows', 'السماح بالمتابعة');
  String get messagePermission => _t('Who can message me', 'من يمكنه مراسلتي');
  String get deleteAccount =>
      _t('Delete account and data', 'حذف الحساب والبيانات');
  String get deleteAccountHelp => _t(
    'Push is disabled immediately and a secure request is queued to permanently delete all account data. This cannot be undone after processing. Deleting BIL does not cancel an App Store or Google Play subscription; cancel it in the device store when needed.',
    'سيتم تعطيل الإشعارات ووضع طلب حذف نهائي وآمن لكل بيانات الحساب. لا يمكن التراجع بعد تنفيذ الطلب. حذف حساب BIL لا يلغي اشتراك App Store أو Google Play؛ ألغِه من متجر الجهاز عند الحاجة.',
  );
  String get cancel => _t('Cancel', 'إلغاء');
  String get requestDeletion => _t('Request deletion', 'طلب الحذف');
  String get deletionQueued =>
      _t('Deletion request queued securely.', 'تم تسجيل طلب الحذف بأمان.');
  String get deletionFailed => _t(
    'Could not request account deletion. Try again.',
    'تعذر طلب حذف الحساب. حاول مجددًا.',
  );
  String get retry => _t('Retry', 'إعادة المحاولة');
  String get signInRequired => _t(
    'Sign in to manage your community profile.',
    'سجّل الدخول لإدارة ملف المجتمع.',
  );
  String visibilityLabel(CommunityProfileVisibility value) => switch (value) {
    CommunityProfileVisibility.public => _t('Public', 'عام'),
    CommunityProfileVisibility.friends => _t('Friends only', 'الأصدقاء فقط'),
    CommunityProfileVisibility.private => _t('Private', 'خاص'),
  };
  String messageLabel(CommunityMessagePermission value) => switch (value) {
    CommunityMessagePermission.friends => _t('Friends only', 'الأصدقاء فقط'),
    CommunityMessagePermission.nobody => _t('Nobody', 'لا أحد'),
  };
}
