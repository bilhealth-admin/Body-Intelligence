import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/environment/app_environment.dart';
import '../../app/localization/runtime_copy.dart';
import 'domain/ad_policy.dart';
import 'providers/ad_providers.dart';
import 'repositories/ad_consent_repository.dart';

String advertisingPrivacyEntryTitle(String locale) =>
    _AdPrivacyCopy.forLocale(locale).title;

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
  final eligibility = _eligibilityCopyFor(locale);
  final detail = _eligibilityDetailCopyFor(locale);
  return <String>[
    copy.title,
    copy.intro,
    copy.boundary,
    copy.unavailableTitle,
    copy.unavailableBody,
    copy.declineTitle,
    copy.declineBody,
    copy.contextualTitle,
    copy.contextualBody,
    copy.error,
    copy.entryAllowed,
    copy.entryBlocked,
    copy.loadError,
    copy.loadErrorBody,
    copy.retry,
    eligibility.$1,
    eligibility.$2,
    detail.$1,
    detail.$2,
    detail.$3,
    detail.$4,
    detail.$5,
    _adultTitle(locale),
    _adultBody(locale),
  ];
}

String _eligibilityText(String locale, bool eligible) {
  final copy = _eligibilityCopyFor(locale);
  return eligible ? copy.$1 : copy.$2;
}

String _eligibilityDetail(
  String locale,
  AdAgeEligibility age,
  AdRegionEligibility region,
) {
  final copy = _eligibilityDetailCopyFor(locale);
  if (age == AdAgeEligibility.unknown) return copy.$1;
  if (age == AdAgeEligibility.under18) return copy.$2;
  if (region == AdRegionEligibility.unknown) return copy.$3;
  if (region == AdRegionEligibility.restricted) return copy.$4;
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

String _adultTitle(String locale) =>
    _adultConfirmationTitle[locale] ??
    _adDirect(locale, _adultConfirmationTitle['en']!);

String _adultBody(String locale) =>
    _adultConfirmationBody[locale] ??
    _adDirect(locale, _adultConfirmationBody['en']!);

const _eligibilityCopy = <String, (String, String)>{
  'en': ('Eligible for contextual ads', 'Advertising remains blocked'),
  'ar': ('مؤهل للإعلانات السياقية', 'ستظل الإعلانات محظورة'),
  'fr': ('Éligible aux publicités contextuelles', 'La publicité reste bloquée'),
  'es': ('Apto para anuncios contextuales', 'La publicidad sigue bloqueada'),
  'tr': ('Bağlamsal reklamlar için uygun', 'Reklamlar engelli kalır'),
};

const _adultConfirmationTitle = <String, String>{
  'en': 'I confirm that I am 18 or older',
  'ar': 'أؤكد أن عمري 18 عامًا أو أكثر',
  'fr': 'Je confirme avoir 18 ans ou plus',
  'es': 'Confirmo que tengo 18 años o más',
  'tr': '18 yaşında veya daha büyük olduğumu onaylıyorum',
};
const _adultConfirmationBody = <String, String>{
  'en': 'Without adult confirmation, BIL never requests an ad.',
  'ar': 'دون تأكيد سن الرشد، لا يطلب BIL أي إعلان مطلقًا.',
  'fr': 'Sans confirmation de majorité, BIL ne demande aucune publicité.',
  'es': 'Sin confirmar la mayoría de edad, BIL no solicita anuncios.',
  'tr': 'Yetişkin onayı olmadan BIL hiçbir reklam istemez.',
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
  const AdvertisingPrivacyPage({super.key});

  @override
  ConsumerState<AdvertisingPrivacyPage> createState() =>
      _AdvertisingPrivacyPageState();
}

class _AdvertisingPrivacyPageState
    extends ConsumerState<AdvertisingPrivacyPage> {
  final AdConsentRepository _repository = const LocalAdConsentRepository();
  final LocalAdAudienceRepository _audienceRepository =
      const LocalAdAudienceRepository();
  AdConsentStatus? _status;
  bool _saving = false;
  Object? _error;
  bool _adultConfirmed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await _repository.read();
      final adultConfirmed = await _audienceRepository.readAdultConfirmation();
      final countryCode =
          WidgetsBinding.instance.platformDispatcher.locale.countryCode;
      if (!mounted) return;
      ref.read(adConsentProvider.notifier).state = status;
      ref.read(adAgeEligibilityProvider.notifier).state = adultConfirmed
          ? AdAgeEligibility.adult
          : AdAgeEligibility.unknown;
      ref.read(adRegionProvider.notifier).state = countryCode == null
          ? AdRegionEligibility.unknown
          : AppEnvironment.adRegionAllowed(countryCode)
          ? AdRegionEligibility.eligible
          : AdRegionEligibility.restricted;
      setState(() {
        _status = status;
        _adultConfirmed = adultConfirmed;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _update(AdConsentStatus status) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.write(status);
      ref.read(adConsentProvider.notifier).state = status;
      if (mounted) {
        setState(() {
          _status = status;
          _error = null;
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateAdultConfirmation(bool value) async {
    if (_saving) return;
    final previous = _adultConfirmed;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _audienceRepository.writeAdultConfirmation(value);
      ref.read(adAgeEligibilityProvider.notifier).state = value
          ? AdAgeEligibility.adult
          : AdAgeEligibility.unknown;
      if (mounted) setState(() => _adultConfirmed = value);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _adultConfirmed = previous;
          _error = error;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _AdPrivacyCopy.forLocale(
      Localizations.localeOf(context).languageCode,
    );
    final ageEligibility = ref.watch(adAgeEligibilityProvider);
    final regionEligibility = ref.watch(adRegionProvider);
    final audienceEligible =
        ageEligibility == AdAgeEligibility.adult &&
        regionEligibility == AdRegionEligibility.eligible;
    final canAllowContextual = audienceEligible && AppEnvironment.adsConfigured;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(copy.title)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(copy.intro, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(copy.boundary),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                key: const Key('advertising-audience-eligibility'),
                leading: Icon(
                  audienceEligible
                      ? Icons.verified_user_outlined
                      : Icons.shield_outlined,
                ),
                title: Text(
                  _eligibilityText(
                    Localizations.localeOf(context).languageCode,
                    audienceEligible,
                  ),
                ),
                subtitle: Text(
                  _eligibilityDetail(
                    Localizations.localeOf(context).languageCode,
                    ageEligibility,
                    regionEligibility,
                  ),
                ),
              ),
            ),
            SwitchListTile.adaptive(
              key: const Key('advertising-adult-confirmation'),
              value: _adultConfirmed,
              title: Text(
                _adultTitle(Localizations.localeOf(context).languageCode),
              ),
              subtitle: Text(
                _adultBody(Localizations.localeOf(context).languageCode),
              ),
              onChanged: _saving ? null : _updateAdultConfirmation,
            ),
            const SizedBox(height: 20),
            if (!AppEnvironment.adsConfigured)
              Card(
                child: ListTile(
                  key: const Key('advertising-provider-unavailable'),
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: Text(copy.unavailableTitle),
                  subtitle: Text(copy.unavailableBody),
                ),
              ),
            if (_status == null && _error == null)
              const Center(child: CircularProgressIndicator())
            else if (_status == null)
              Card(
                child: ListTile(
                  key: const Key('advertising-load-error'),
                  leading: Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(copy.loadError),
                  subtitle: Text(copy.loadErrorBody),
                  trailing: TextButton(
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() => _error = null);
                            _load();
                          },
                    child: Text(copy.retry),
                  ),
                ),
              )
            else ...[
              RadioGroup<AdConsentStatus>(
                groupValue: _status ?? AdConsentStatus.unknown,
                onChanged: (value) {
                  if (!_saving && value != null) _update(value);
                },
                child: Column(
                  children: [
                    RadioListTile<AdConsentStatus>(
                      key: const Key('advertising-consent-declined'),
                      enabled: !_saving,
                      value: AdConsentStatus.declined,
                      title: Text(copy.declineTitle),
                      subtitle: Text(copy.declineBody),
                    ),
                    RadioListTile<AdConsentStatus>(
                      key: const Key('advertising-consent-contextual'),
                      enabled: !_saving && canAllowContextual,
                      value: AdConsentStatus.contextualOnly,
                      title: Text(copy.contextualTitle),
                      subtitle: Text(copy.contextualBody),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    copy.error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ],
        ),
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
        'BIL never uses health, nutrition, weight, location, profile, or private community data for advertising. Pro is always ad-free.',
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
        'لا يستخدم BIL بيانات الصحة أو الغذاء أو الوزن أو الموقع أو الملف أو المجتمع الخاص للإعلانات. خطة Pro بلا إعلانات دائمًا.',
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
        'BIL n’utilise jamais les données de santé, nutrition, poids, localisation, profil ou communauté privée pour la publicité. Pro reste sans publicité.',
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
        'BIL nunca usa datos de salud, nutrición, peso, ubicación, perfil o comunidad privada para publicidad. Pro no muestra anuncios.',
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
        'BIL sağlık, beslenme, kilo, konum, profil veya özel topluluk verilerini reklam için kullanmaz. Pro her zaman reklamsızdır.',
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
