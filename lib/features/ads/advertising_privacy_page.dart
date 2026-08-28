import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/runtime_copy.dart';
import 'domain/ad_policy.dart';
import 'providers/ad_providers.dart';
import 'services/admob_ump_consent_gate.dart';

String advertisingPrivacyEntryTitle(String locale) =>
    _AdPrivacyCopy.forLocale(locale).title;

String _advertisingLocaleTag(String locale) {
  final normalized = locale.replaceAll('_', '-').toLowerCase();
  if (normalized == 'pt-br') return 'pt-BR';
  if (normalized == 'pt-pt') return 'pt-PT';
  if (normalized == 'zh-hans') return 'zh-Hans';
  if (normalized == 'zh-hant') return 'zh-Hant';
  return normalized.split('-').first;
}

String advertisingPrivacyEntryStatus(
  String locale, {
  required bool contextualAllowed,
}) {
  final copy = _AdPrivacyCopy.forLocale(locale);
  return contextualAllowed ? copy.entryAllowed : copy.entryBlocked;
}

@visibleForTesting
List<String> advertisingPrivacySurfaceCopy(String locale) {
  final copy = _AdPrivacyCopy.forLocale(locale);
  final ump = _UmpPrivacyCopy.forLocale(locale);
  final eligibility = _eligibilityCopyFor(locale);
  final detail = _eligibilityDetailCopyFor(locale);
  return <String>[
    copy.title,
    copy.boundary,
    copy.unavailableTitle,
    copy.unavailableBody,
    copy.contextualTitle,
    copy.contextualBody,
    copy.entryAllowed,
    copy.entryBlocked,
    copy.retry,
    eligibility.$1,
    eligibility.$2,
    detail.$1,
    detail.$2,
    detail.$3,
    detail.$4,
    detail.$5,
    ump.title,
    ump.body,
    ump.blocked,
  ];
}

String _eligibilityText(String locale, bool eligible) {
  final copy = _eligibilityCopyFor(locale);
  return eligible ? copy.$1 : copy.$2;
}

String _eligibilityDetail(String locale, AdAgeEligibility age) {
  final copy = _eligibilityDetailCopyFor(locale);
  if (age == AdAgeEligibility.unknown) return copy.$1;
  if (age == AdAgeEligibility.under18) return copy.$2;
  return copy.$5;
}

String _adDirect(String locale, String english) =>
    RuntimeCopy.resolve(english, locale) ??
    (throw StateError('Missing advertising copy for $locale: $english'));

(String, String) _eligibilityCopyFor(String locale) {
  final authored = _eligibilityCopy[locale];
  if (authored != null) return authored;
  final english = _eligibilityCopy['en']!;
  return (_adDirect(locale, english.$1), _adDirect(locale, english.$2));
}

(String, String, String, String, String) _eligibilityDetailCopyFor(
  String locale,
) {
  final authored = _eligibilityDetailCopy[locale];
  if (authored != null) return authored;
  final english = _eligibilityDetailCopy['en']!;
  return (
    _adDirect(locale, english.$1),
    _adDirect(locale, english.$2),
    _adDirect(locale, english.$3),
    _adDirect(locale, english.$4),
    _adDirect(locale, english.$5),
  );
}

const _eligibilityCopy = <String, (String, String)>{
  'en': ('Eligible for contextual ads', 'Advertising remains blocked'),
  'ar': ('مؤهل للإعلانات السياقية', 'ستظل الإعلانات محظورة'),
  'fr': ('Éligible aux publicités contextuelles', 'La publicité reste bloquée'),
  'es': ('Apto para anuncios contextuales', 'La publicidad sigue bloqueada'),
  'tr': ('Bağlamsal reklamlar için uygun', 'Reklamlar engelli kalır'),
};

final class _UmpPrivacyCopy {
  const _UmpPrivacyCopy({
    required this.title,
    required this.body,
    required this.blocked,
  });

  final String title;
  final String body;
  final String blocked;

  static _UmpPrivacyCopy forLocale(String locale) {
    final normalized = locale.replaceAll('_', '-').toLowerCase();
    for (final entry in _umpPrivacyCopy.entries) {
      if (entry.key.toLowerCase() == normalized) return entry.value;
    }
    final language = normalized.split('-').first;
    if (language == 'pt') return _umpPrivacyCopy['pt-PT']!;
    if (language == 'zh') return _umpPrivacyCopy['zh-Hans']!;
    return _umpPrivacyCopy[language] ?? _umpPrivacyCopy['en']!;
  }
}

const _umpPrivacyCopy = <String, _UmpPrivacyCopy>{
  'en': _UmpPrivacyCopy(
    title: 'Google advertising privacy',
    body:
        'Review or change the consent choices managed by Google’s consent platform.',
    blocked: 'Google consent could not be confirmed. Ads remain blocked.',
  ),
  'ar': _UmpPrivacyCopy(
    title: 'خصوصية إعلانات Google',
    body: 'راجع أو غيّر خيارات الموافقة التي تديرها منصة موافقة Google.',
    blocked: 'تعذر تأكيد موافقة Google. ستظل الإعلانات محظورة.',
  ),
  'fr': _UmpPrivacyCopy(
    title: 'Confidentialité publicitaire Google',
    body:
        'Consultez ou modifiez les choix gérés par la plate-forme de consentement Google.',
    blocked:
        'Le consentement Google n’a pas pu être confirmé. Les publicités restent bloquées.',
  ),
  'es': _UmpPrivacyCopy(
    title: 'Privacidad publicitaria de Google',
    body:
        'Revisa o cambia las opciones gestionadas por la plataforma de consentimiento de Google.',
    blocked:
        'No se pudo confirmar el consentimiento de Google. Los anuncios siguen bloqueados.',
  ),
  'tr': _UmpPrivacyCopy(
    title: 'Google reklam gizliliği',
    body:
        'Google’ın izin platformunun yönettiği seçimleri inceleyin veya değiştirin.',
    blocked: 'Google izni doğrulanamadı. Reklamlar engelli kalır.',
  ),
  'de': _UmpPrivacyCopy(
    title: 'Google-Werbedatenschutz',
    body:
        'Prüfen oder ändern Sie die von Googles Einwilligungsplattform verwalteten Optionen.',
    blocked:
        'Die Google-Einwilligung konnte nicht bestätigt werden. Werbung bleibt gesperrt.',
  ),
  'it': _UmpPrivacyCopy(
    title: 'Privacy pubblicitaria di Google',
    body:
        'Rivedi o modifica le scelte gestite dalla piattaforma di consenso di Google.',
    blocked:
        'Impossibile confermare il consenso Google. Gli annunci restano bloccati.',
  ),
  'pt-BR': _UmpPrivacyCopy(
    title: 'Privacidade de anúncios do Google',
    body:
        'Revise ou altere as escolhas gerenciadas pela plataforma de consentimento do Google.',
    blocked:
        'Não foi possível confirmar o consentimento do Google. Os anúncios continuam bloqueados.',
  ),
  'pt-PT': _UmpPrivacyCopy(
    title: 'Privacidade de publicidade da Google',
    body:
        'Reveja ou altere as escolhas geridas pela plataforma de consentimento da Google.',
    blocked:
        'Não foi possível confirmar o consentimento da Google. Os anúncios continuam bloqueados.',
  ),
  'ur': _UmpPrivacyCopy(
    title: 'Google اشتہاری رازداری',
    body:
        'Google کے رضامندی پلیٹ فارم کے زیر انتظام انتخابات کا جائزہ لیں یا انہیں تبدیل کریں۔',
    blocked: 'Google رضامندی کی تصدیق نہیں ہو سکی۔ اشتہارات مسدود رہیں گے۔',
  ),
  'fa': _UmpPrivacyCopy(
    title: 'حریم خصوصی تبلیغات Google',
    body:
        'گزینه‌های مدیریت‌شده توسط سامانه رضایت Google را مرور یا تغییر دهید.',
    blocked: 'رضایت Google تأیید نشد. تبلیغات همچنان مسدود می‌مانند.',
  ),
  'hi': _UmpPrivacyCopy(
    title: 'Google विज्ञापन गोपनीयता',
    body:
        'Google के सहमति प्लेटफ़ॉर्म द्वारा प्रबंधित विकल्पों को देखें या बदलें।',
    blocked: 'Google सहमति की पुष्टि नहीं हो सकी। विज्ञापन अवरुद्ध रहेंगे।',
  ),
  'id': _UmpPrivacyCopy(
    title: 'Privasi iklan Google',
    body:
        'Tinjau atau ubah pilihan yang dikelola oleh platform persetujuan Google.',
    blocked:
        'Persetujuan Google tidak dapat dikonfirmasi. Iklan tetap diblokir.',
  ),
  'ms': _UmpPrivacyCopy(
    title: 'Privasi pengiklanan Google',
    body:
        'Semak atau ubah pilihan yang diurus oleh platform persetujuan Google.',
    blocked: 'Persetujuan Google tidak dapat disahkan. Iklan kekal disekat.',
  ),
  'ja': _UmpPrivacyCopy(
    title: 'Google 広告のプライバシー',
    body: 'Google の同意プラットフォームで管理される選択内容を確認または変更します。',
    blocked: 'Google の同意を確認できませんでした。広告は引き続きブロックされます。',
  ),
  'ko': _UmpPrivacyCopy(
    title: 'Google 광고 개인정보 보호',
    body: 'Google 동의 플랫폼에서 관리하는 선택 사항을 검토하거나 변경합니다.',
    blocked: 'Google 동의를 확인할 수 없습니다. 광고는 계속 차단됩니다.',
  ),
  'zh-Hans': _UmpPrivacyCopy(
    title: 'Google 广告隐私',
    body: '查看或更改由 Google 同意平台管理的选择。',
    blocked: '无法确认 Google 同意状态。广告将继续被屏蔽。',
  ),
  'zh-Hant': _UmpPrivacyCopy(
    title: 'Google 廣告隱私權',
    body: '查看或變更由 Google 同意平台管理的選擇。',
    blocked: '無法確認 Google 同意狀態。廣告將繼續遭到封鎖。',
  ),
  'ru': _UmpPrivacyCopy(
    title: 'Конфиденциальность рекламы Google',
    body:
        'Просмотрите или измените варианты, управляемые платформой согласия Google.',
    blocked:
        'Не удалось подтвердить согласие Google. Реклама остаётся заблокированной.',
  ),
  'bn': _UmpPrivacyCopy(
    title: 'Google বিজ্ঞাপনের গোপনীয়তা',
    body:
        'Google-এর সম্মতি প্ল্যাটফর্মে পরিচালিত পছন্দগুলো পর্যালোচনা বা পরিবর্তন করুন।',
    blocked: 'Google সম্মতি নিশ্চিত করা যায়নি। বিজ্ঞাপন বন্ধ থাকবে।',
  ),
  'vi': _UmpPrivacyCopy(
    title: 'Quyền riêng tư quảng cáo Google',
    body:
        'Xem lại hoặc thay đổi các lựa chọn do nền tảng đồng ý của Google quản lý.',
    blocked: 'Không thể xác nhận sự đồng ý của Google. Quảng cáo vẫn bị chặn.',
  ),
  'th': _UmpPrivacyCopy(
    title: 'ความเป็นส่วนตัวของโฆษณา Google',
    body: 'ตรวจสอบหรือเปลี่ยนตัวเลือกที่จัดการโดยแพลตฟอร์มความยินยอมของ Google',
    blocked: 'ยืนยันความยินยอมของ Google ไม่ได้ โฆษณาจะยังคงถูกบล็อก',
  ),
  'pl': _UmpPrivacyCopy(
    title: 'Prywatność reklam Google',
    body: 'Przejrzyj lub zmień opcje zarządzane przez platformę zgód Google.',
    blocked:
        'Nie udało się potwierdzić zgody Google. Reklamy pozostają zablokowane.',
  ),
  'nl': _UmpPrivacyCopy(
    title: 'Privacy voor Google-advertenties',
    body:
        'Bekijk of wijzig de keuzes die door het toestemmingsplatform van Google worden beheerd.',
    blocked:
        'Google-toestemming kon niet worden bevestigd. Advertenties blijven geblokkeerd.',
  ),
  'uk': _UmpPrivacyCopy(
    title: 'Конфіденційність реклами Google',
    body:
        'Перегляньте або змініть параметри, якими керує платформа згоди Google.',
    blocked:
        'Не вдалося підтвердити згоду Google. Реклама залишається заблокованою.',
  ),
};

const _eligibilityDetailCopy =
    <String, (String, String, String, String, String)>{
      'en': (
        'Age is not verified. No ad request is permitted.',
        'Advertising is disabled for people under 18.',
        'Country is not selected. No ad request is permitted.',
        'Advertising is not enabled for the selected country.',
        'Ads still require explicit consent and a reviewed provider.',
      ),
      'ar': (
        'لم يتم التحقق من العمر. لا يُسمح بأي طلب إعلان.',
        'الإعلانات معطلة لمن هم دون 18 عامًا.',
        'لم يتم اختيار الدولة. لا يُسمح بأي طلب إعلان.',
        'الإعلانات غير مفعلة للدولة المختارة.',
        'تظل الإعلانات بحاجة إلى موافقة صريحة ومزود تمت مراجعته.',
      ),
      'fr': (
        "L’âge n’est pas vérifié. Aucune demande publicitaire n’est autorisée.",
        'La publicité est désactivée pour les moins de 18 ans.',
        "Le pays n’est pas sélectionné. Aucune demande n’est autorisée.",
        "La publicité n’est pas activée pour le pays sélectionné.",
        'Un consentement explicite et un fournisseur approuvé restent requis.',
      ),
      'es': (
        'La edad no está verificada. No se permite solicitar anuncios.',
        'La publicidad está desactivada para menores de 18 años.',
        'No se seleccionó el país. No se permite solicitar anuncios.',
        'La publicidad no está habilitada para el país seleccionado.',
        'Aún se requiere consentimiento explícito y un proveedor revisado.',
      ),
      'tr': (
        'Yaş doğrulanmadı. Reklam isteğine izin verilmez.',
        '18 yaşından küçükler için reklamlar devre dışıdır.',
        'Ülke seçilmedi. Reklam isteğine izin verilmez.',
        'Seçilen ülkede reklamlar etkin değildir.',
        'Açık onay ve incelenmiş bir sağlayıcı yine de gereklidir.',
      ),
    };

class AdvertisingPrivacyPage extends ConsumerStatefulWidget {
  const AdvertisingPrivacyPage({super.key, this.umpConsentCoordinator});

  @visibleForTesting
  final UmpConsentCoordinator? umpConsentCoordinator;

  @override
  ConsumerState<AdvertisingPrivacyPage> createState() =>
      _AdvertisingPrivacyPageState();
}

class _AdvertisingPrivacyPageState
    extends ConsumerState<AdvertisingPrivacyPage> {
  late final UmpConsentCoordinator _umpConsent;
  UmpConsentSnapshot _umpSnapshot = const UmpConsentSnapshot.uninitialized();
  bool _umpBusy = false;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _umpConsent = widget.umpConsentCoordinator ?? AdMobUmpConsentGate.instance;
    _umpSnapshot = _umpConsent.snapshot;
  }

  bool get _umpEnabled =>
      widget.umpConsentCoordinator != null ||
      (_umpConsent.isApplicable &&
          ref.read(contextualAdGatewayProvider).isConfigured);

  void _scheduleAutomaticUmpRefresh(bool audienceEligible) {
    if (_refreshScheduled ||
        !audienceEligible ||
        !_umpEnabled ||
        _umpSnapshot.phase != UmpConsentPhase.uninitialized) {
      return;
    }
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) _refreshUmp();
    });
  }

  Future<void> _showUmpPrivacyOptions() async {
    if (_umpBusy || !_umpSnapshot.privacyOptionsRequired) {
      return;
    }
    setState(() => _umpBusy = true);
    final snapshot = await _umpConsent.showPrivacyOptions();
    if (!mounted) return;
    setState(() {
      _umpSnapshot = snapshot;
      _umpBusy = false;
    });
  }

  Future<void> _refreshUmp({bool force = false}) async {
    if (_umpBusy || !_umpEnabled) return;
    setState(() => _umpBusy = true);
    final snapshot = await _umpConsent.refresh(force: force);
    if (!mounted) return;
    setState(() {
      _umpSnapshot = snapshot;
      _umpBusy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = _advertisingLocaleTag(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final copy = _AdPrivacyCopy.forLocale(locale);
    final umpCopy = _UmpPrivacyCopy.forLocale(locale);
    final ageEligibility = ref.watch(adAgeEligibilityProvider);
    final audienceEligible = ref.watch(registeredAdultFreeAdAudienceProvider);
    final providerConfigured = ref
        .watch(contextualAdGatewayProvider)
        .isConfigured;
    _scheduleAutomaticUmpRefresh(audienceEligible);
    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(copy.boundary, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              key: const Key('advertising-audience-eligibility'),
              leading: Icon(
                audienceEligible
                    ? Icons.verified_user_outlined
                    : Icons.shield_outlined,
              ),
              title: Text(_eligibilityText(locale, audienceEligible)),
              subtitle: Text(_eligibilityDetail(locale, ageEligibility)),
            ),
          ),
          Card(
            child: ListTile(
              key: const Key('advertising-contextual-policy'),
              leading: const Icon(Icons.ads_click_outlined),
              title: Text(copy.contextualTitle),
              subtitle: Text(copy.contextualBody),
            ),
          ),
          if (_umpEnabled && _umpSnapshot.privacyOptionsRequired)
            Card(
              child: ListTile(
                key: const Key('advertising-google-privacy-options'),
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(umpCopy.title),
                subtitle: Text(umpCopy.body),
                trailing: _umpBusy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: _umpBusy ? null : _showUmpPrivacyOptions,
              ),
            ),
          if (_umpEnabled && _umpSnapshot.phase == UmpConsentPhase.blocked)
            Card(
              child: ListTile(
                key: const Key('advertising-google-consent-blocked'),
                leading: Icon(
                  Icons.gpp_maybe_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(umpCopy.title),
                subtitle: Text(umpCopy.blocked),
                trailing: TextButton(
                  onPressed: _umpBusy || !audienceEligible
                      ? null
                      : () => _refreshUmp(force: true),
                  child: Text(copy.retry),
                ),
              ),
            ),
          if (_umpBusy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (!providerConfigured)
            Card(
              child: ListTile(
                key: const Key('advertising-provider-unavailable'),
                leading: const Icon(Icons.visibility_off_outlined),
                title: Text(copy.unavailableTitle),
                subtitle: Text(copy.unavailableBody),
              ),
            ),
        ],
      ),
    );
  }
}

final class _AdPrivacyCopy {
  const _AdPrivacyCopy({
    required this.title,
    required this.intro,
    required this.boundary,
    required this.unavailableTitle,
    required this.unavailableBody,
    required this.declineTitle,
    required this.declineBody,
    required this.contextualTitle,
    required this.contextualBody,
    required this.error,
    required this.entryAllowed,
    required this.entryBlocked,
    required this.loadError,
    required this.loadErrorBody,
    required this.retry,
  });
  final String title;
  final String intro;
  final String boundary;
  final String unavailableTitle;
  final String unavailableBody;
  final String declineTitle;
  final String declineBody;
  final String contextualTitle;
  final String contextualBody;
  final String error;
  final String entryAllowed;
  final String entryBlocked;
  final String loadError;
  final String loadErrorBody;
  final String retry;
  static _AdPrivacyCopy forLocale(String locale) {
    final authored = _copy[locale];
    if (authored != null) return authored;
    final en = _copy['en']!;
    return _AdPrivacyCopy(
      title: _adDirect(locale, en.title),
      intro: _adDirect(locale, en.intro),
      boundary: _adDirect(locale, en.boundary),
      unavailableTitle: _adDirect(locale, en.unavailableTitle),
      unavailableBody: _adDirect(locale, en.unavailableBody),
      declineTitle: _adDirect(locale, en.declineTitle),
      declineBody: _adDirect(locale, en.declineBody),
      contextualTitle: _adDirect(locale, en.contextualTitle),
      contextualBody: _adDirect(locale, en.contextualBody),
      error: _adDirect(locale, en.error),
      entryAllowed: _adDirect(locale, en.entryAllowed),
      entryBlocked: _adDirect(locale, en.entryBlocked),
      loadError: _adDirect(
        locale,
        'Saved setting could not be loaded. Tap to retry.',
      ),
      loadErrorBody: _adDirect(locale, en.error),
      retry: _adDirect(locale, 'Retry'),
    );
  }
}

const _copy = <String, _AdPrivacyCopy>{
  'en': _AdPrivacyCopy(
    title: 'Advertising privacy',
    intro: 'You control whether the Free plan may show contextual ads.',
    boundary:
        'BIL never uses health, nutrition, weight, location, profile, or private community data for advertising. Premium is always ad-free.',
    unavailableTitle: 'Advertising is not active',
    unavailableBody:
        'No ad request is made until a reviewed production provider is configured.',
    declineTitle: 'Do not show ads',
    declineBody: 'This choice can be changed later.',
    contextualTitle: 'Allow contextual ads on Free',
    contextualBody: 'Non-personalized ads only on general discovery surfaces.',
    error: 'Your choice could not be saved. No ad request was made.',
    entryAllowed: 'Contextual, non-personalized ads on Free.',
    entryBlocked: 'Ad requests are not permitted.',
    loadError: 'Your saved advertising choice could not be loaded.',
    loadErrorBody:
        'Controls stay unavailable to avoid replacing an unread choice.',
    retry: 'Retry',
  ),
  'ar': _AdPrivacyCopy(
    title: 'خصوصية الإعلانات',
    intro: 'أنت تتحكم في السماح للخطة المجانية بعرض إعلانات سياقية.',
    boundary:
        'لا يستخدم BIL بيانات الصحة أو الغذاء أو الوزن أو الموقع أو الملف أو المجتمع الخاص للإعلانات. عضوية بريميوم بلا إعلانات دائمًا.',
    unavailableTitle: 'الإعلانات غير مفعلة',
    unavailableBody: 'لن يُرسل أي طلب إعلان حتى تهيئة مزود إنتاج تمت مراجعته.',
    declineTitle: 'عدم عرض الإعلانات',
    declineBody: 'يمكن تغيير هذا الخيار لاحقًا.',
    contextualTitle: 'السماح بإعلانات سياقية في الخطة المجانية',
    contextualBody: 'إعلانات غير مخصصة على أسطح الاستكشاف العامة فقط.',
    error: 'تعذر حفظ اختيارك. لم يُرسل أي طلب إعلان.',
    entryAllowed: 'إعلانات سياقية غير مخصصة في الخطة المجانية.',
    entryBlocked: 'لا يُسمح بطلب الإعلانات.',
    loadError: 'تعذر تحميل اختيارك الإعلاني المحفوظ.',
    loadErrorBody:
        'تظل عناصر التحكم غير متاحة حتى لا يُستبدل اختيار تعذرت قراءته.',
    retry: 'إعادة المحاولة',
  ),
  'fr': _AdPrivacyCopy(
    title: 'Confidentialité publicitaire',
    intro: 'Vous contrôlez les publicités contextuelles du forfait Gratuit.',
    boundary:
        'BIL n’utilise jamais les données de santé, nutrition, poids, localisation, profil ou communauté privée pour la publicité. Premium reste sans publicité.',
    unavailableTitle: 'Publicité inactive',
    unavailableBody:
        'Aucune requête n’est envoyée avant la configuration d’un fournisseur de production approuvé.',
    declineTitle: 'Ne pas afficher de publicité',
    declineBody: 'Ce choix peut être modifié plus tard.',
    contextualTitle: 'Autoriser les publicités contextuelles',
    contextualBody: 'Uniquement non personnalisées sur les écrans généraux.',
    error:
        'Impossible d’enregistrer votre choix. Aucune requête publicitaire n’a été envoyée.',
    entryAllowed: 'Publicités contextuelles non personnalisées sur Gratuit.',
    entryBlocked: 'Les requêtes publicitaires ne sont pas autorisées.',
    loadError: 'Impossible de charger votre choix publicitaire enregistré.',
    loadErrorBody:
        'Les contrôles restent indisponibles pour ne pas remplacer un choix illisible.',
    retry: 'Réessayer',
  ),
  'es': _AdPrivacyCopy(
    title: 'Privacidad publicitaria',
    intro: 'Tú controlas los anuncios contextuales del plan Gratis.',
    boundary:
        'BIL nunca usa datos de salud, nutrición, peso, ubicación, perfil o comunidad privada para publicidad. Premium no muestra anuncios.',
    unavailableTitle: 'La publicidad no está activa',
    unavailableBody:
        'No se solicita ningún anuncio hasta configurar un proveedor de producción revisado.',
    declineTitle: 'No mostrar anuncios',
    declineBody: 'Puedes cambiar esta opción más adelante.',
    contextualTitle: 'Permitir anuncios contextuales',
    contextualBody: 'Solo anuncios no personalizados en áreas generales.',
    error: 'No se pudo guardar tu elección. No se solicitó ningún anuncio.',
    entryAllowed: 'Anuncios contextuales no personalizados en Gratis.',
    entryBlocked: 'No se permiten solicitudes de anuncios.',
    loadError: 'No se pudo cargar tu elección publicitaria guardada.',
    loadErrorBody:
        'Los controles no están disponibles para evitar reemplazar una elección que no pudo leerse.',
    retry: 'Reintentar',
  ),
  'tr': _AdPrivacyCopy(
    title: 'Reklam gizliliği',
    intro: 'Ücretsiz plandaki bağlamsal reklamları siz kontrol edersiniz.',
    boundary:
        'BIL sağlık, beslenme, kilo, konum, profil veya özel topluluk verilerini reklam için kullanmaz. Premium her zaman reklamsızdır.',
    unavailableTitle: 'Reklamlar etkin değil',
    unavailableBody:
        'İncelenmiş üretim sağlayıcısı yapılandırılmadan reklam isteği gönderilmez.',
    declineTitle: 'Reklam gösterme',
    declineBody: 'Bu seçimi daha sonra değiştirebilirsiniz.',
    contextualTitle: 'Bağlamsal reklamlara izin ver',
    contextualBody: 'Yalnızca genel alanlarda kişiselleştirilmemiş reklamlar.',
    error: 'Seçiminiz kaydedilemedi. Reklam isteği gönderilmedi.',
    entryAllowed: 'Ücretsiz planda kişiselleştirilmemiş bağlamsal reklamlar.',
    entryBlocked: 'Reklam isteklerine izin verilmiyor.',
    loadError: 'Kayıtlı reklam tercihiniz yüklenemedi.',
    loadErrorBody:
        'Okunamayan bir tercihin üzerine yazılmaması için denetimler kullanılamaz.',
    retry: 'Yeniden dene',
  ),
};
