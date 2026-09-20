import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../shared/widgets/bil_coach_identity.dart';
import '../../commerce/presentation/ai_boost_coach_artwork.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../onboarding/onboarding_runtime_copy.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../domain/coach_context_preferences.dart';
import '../services/ai_boost_purchase_service.dart';

part 'ai_coach_settings_components.dart';
part 'ai_coach_settings_usage_widgets.dart';

const _globalResetGiftCopy =
    'A gift from BIL 🎁 Your current-period AI Coach usage was reset, and 2,500 non-expiring AI Boost tokens were added.';

@visibleForTesting
Set<CoachContextFocus> coachContextFocusesFromUsage(Object? raw) {
  if (raw is! List) return const CoachContextPreferences().focuses;
  final names = raw
      .map((value) => value?.toString())
      .whereType<String>()
      .toSet();
  return Set.unmodifiable(
    CoachContextFocus.values.where((focus) => names.contains(focus.name)),
  );
}

class AiCoachSettingsPage extends ConsumerStatefulWidget {
  const AiCoachSettingsPage({super.key});

  @override
  ConsumerState<AiCoachSettingsPage> createState() =>
      _AiCoachSettingsPageState();
}

class _AiCoachSettingsPageState extends ConsumerState<AiCoachSettingsPage>
    with WidgetsBindingObserver {
  late final AiBoostPurchaseService boost;
  Future<Map<String, Object?>>? usage;
  bool changingConsent = false;
  bool changingContextFocus = false;
  Set<CoachContextFocus>? contextFocuses;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    boost = AiBoostPurchaseService()..addListener(_boostChanged);
    usage = _loadUsage();
    boost.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    setState(() {
      contextFocuses = null;
      usage = _loadUsage();
    });
  }

  void _boostChanged() {
    if (!mounted) return;
    if (boost.state == AiBoostPurchaseState.verified) {
      usage = _loadUsage();
      ref.invalidate(aiCoachCreditAccessProvider);
    }
    setState(() {});
  }

  Future<Map<String, Object?>> _loadUsage() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw StateError('authentication_required');
    }
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) throw StateError('authentication_required');
    final value = await client.rpc('bil_get_ai_usage_status');
    final result = Map<String, Object?>.from(value as Map);
    final storedContext = await ref
        .read(preferencesRepositoryProvider)
        .get(CoachContextPreferences.storageKey);
    result['context_focuses'] = CoachContextPreferences.decode(
      storedContext,
    ).focuses.map((focus) => focus.name).toList(growable: false);
    try {
      final consent = await client.rpc('bil_get_remote_ai_consent');
      final consentMap = Map<String, Object?>.from(consent as Map);
      result['remote_ai_consent'] = consentMap['granted'] == true;
      result['cloud_voice_consent'] =
          consentMap['granted'] == true &&
          consentMap['policy_version']?.toString() == '2';
      result['consent_status_available'] = true;
    } on Object {
      result['remote_ai_consent'] = false;
      result['cloud_voice_consent'] = false;
      result['consent_status_available'] = false;
    }
    try {
      final notice = await client
          .from('bil_ai_coach_reset_notices')
          .select('reset_id,created_at,message')
          .eq('owner_id', ownerId)
          .isFilter('seen_at', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (notice != null) {
        result['reset_notice'] = Map<String, Object?>.from(notice);
      }
    } on Object {
      // Older backends can still show usage while the additive notice
      // migration is rolling out.
    }
    return result;
  }

  Future<void> _setRemoteAiConsent(bool granted) async {
    if (changingConsent) return;
    setState(() => changingConsent = true);
    try {
      await Supabase.instance.client.rpc(
        'bil_record_consent',
        params: <String, Object?>{
          'p_purpose': 'remote_ai',
          'p_policy_version': '2',
          'p_granted': granted,
        },
      );
      if (mounted) setState(() => usage = _loadUsage());
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Could not update AI privacy consent. Nothing was sent.',
              'تعذّر تحديث موافقة الخصوصية. لم يتم إرسال أي شيء.',
              'Impossible de mettre à jour le consentement. Aucun envoi.',
              'No se pudo actualizar el consentimiento. No se envió nada.',
              'Gizlilik izni güncellenemedi. Hiçbir şey gönderilmedi.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => changingConsent = false);
    }
  }

  Future<void> _setContextFocus(
    CoachContextFocus focus,
    bool included,
    Set<CoachContextFocus> current,
  ) async {
    if (changingContextFocus) return;
    final next = <CoachContextFocus>{...current};
    included ? next.add(focus) : next.remove(focus);
    setState(() => changingContextFocus = true);
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .set(
            CoachContextPreferences.storageKey,
            CoachContextPreferences(focuses: Set.unmodifiable(next)).encode(),
          );
      if (mounted) {
        setState(() => contextFocuses = Set.unmodifiable(next));
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Could not update Coach context categories. Nothing changed.',
              'تعذر تحديث فئات سياق المدرب. لم يتغير شيء.',
              'Impossible de modifier les catégories de contexte. Aucun changement.',
              'No se pudieron actualizar las categorías de contexto. No cambió nada.',
              'Koç bağlam kategorileri güncellenemedi. Hiçbir şey değişmedi.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => changingContextFocus = false);
    }
  }

  String t(String en, String ar, String fr, String es, String tr) {
    final locale = Localizations.localeOf(context);
    return switch (locale.languageCode) {
      'ar' => ar,
      'en' => en,
      'fr' => fr,
      'es' => es,
      'tr' => tr,
      _ =>
        RuntimeCopy.resolve(en, BilLocalePolicy.canonicalTag(locale)) ??
            OnboardingRuntimeCopy.resolve(en, locale),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(aiCoachUsageRefreshProvider, (previous, next) {
      if (previous == next || !mounted) return;
      setState(() {
        contextFocuses = null;
        usage = _loadUsage();
      });
    });
    const navy = Color(0xFF071923);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F7F9),
        surfaceTintColor: Colors.transparent,
        foregroundColor: navy,
        title: Text(
          t(
            'Coach access',
            'رصيد المدرب',
            'Accès Coach',
            'Acceso al Coach',
            'Koç erişimi',
          ),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<Map<String, Object?>>(
        future: usage,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorState(snapshot.error);
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1D8ACB)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final fresh = _loadUsage();
              setState(() {
                contextFocuses = null;
                usage = fresh;
              });
              await fresh;
            },
            child: _settingsBody(snapshot.data!),
          );
        },
      ),
    );
  }

  Widget _settingsBody(Map<String, Object?> data) {
    final loadedFocuses = coachContextFocusesFromUsage(data['context_focuses']);
    final effectiveFocuses = contextFocuses ?? loadedFocuses;
    final rawCredits = data['credits'];
    final credits = rawCredits is Map
        ? Map<String, Object?>.from(rawCredits)
        : const <String, Object?>{};
    final weeklyLimit = _int(credits['weekly_limit']);
    final weeklyUsed = _int(credits['weekly_used']);
    final weeklyReserved = _int(credits['weekly_reserved']);
    final weeklyRemaining = _int(credits['weekly_remaining']);
    final paidRemaining = _int(credits['paid_remaining']);
    final totalRemaining = _int(credits['total_remaining']);
    final spentFraction = weeklyLimit <= 0
        ? 0.0
        : ((weeklyUsed + weeklyReserved) / weeklyLimit).clamp(0.0, 1.0);
    final active = data['plan'] == 'ai_coach';
    final rawNotice = data['reset_notice'];
    final notice = rawNotice is Map
        ? Map<String, Object?>.from(rawNotice)
        : const <String, Object?>{};
    final resetNoticeId = notice['reset_id']?.toString() ?? '';
    final authoredResetMessage = notice['message']?.toString().trim();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (resetNoticeId.isNotEmpty) ...[
          _ResetGiftBanner(
            message: authoredResetMessage?.isNotEmpty == true
                ? authoredResetMessage!
                : context.strings.text(_globalResetGiftCopy),
            onDismiss: () => _dismissResetNotice(resetNoticeId),
          ),
          const SizedBox(height: 14),
        ],
        _TokenHero(
          totalRemaining: totalRemaining,
          weeklyRemaining: weeklyRemaining,
          weeklyLimit: weeklyLimit,
          paidRemaining: paidRemaining,
          spentFraction: spentFraction,
          active: active,
          weekStart: data['week_start']?.toString() ?? '—',
          resetAt: data['reset_at']?.toString() ?? '—',
          t: t,
        ),
        const SizedBox(height: 14),
        _PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                icon: Icons.hub_rounded,
                title: t(
                  'One balance. Every way you coach.',
                  'رصيد واحد. لكل طرق التدريب.',
                  'Un solde pour tous vos échanges.',
                  'Un saldo para todas tus consultas.',
                  'Tüm koçluk için tek bakiye.',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CapabilityChip(
                    icon: Icons.chat_bubble_rounded,
                    label: t('Text', 'نص', 'Texte', 'Texto', 'Metin'),
                  ),
                  _CapabilityChip(
                    icon: Icons.graphic_eq_rounded,
                    label: t('Voice', 'صوت', 'Voix', 'Voz', 'Ses'),
                  ),
                  _CapabilityChip(
                    icon: Icons.camera_alt_rounded,
                    label: t('Vision', 'صورة', 'Vision', 'Visión', 'Görüntü'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                t(
                  'BIL reserves a small amount before a cloud request, then charges only the actual provider cost. Local answers cost zero tokens.',
                  'يحجز BIL مبلغًا صغيرًا قبل الطلب السحابي، ثم يخصم التكلفة الفعلية فقط. الإجابات المحلية لا تستهلك أي توكن.',
                  'BIL réserve un petit montant puis facture uniquement le coût réel. Les réponses locales sont gratuites.',
                  'BIL reserva una pequeña cantidad y cobra solo el coste real. Las respuestas locales no gastan tokens.',
                  'BIL önce küçük bir tutar ayırır, sonra yalnızca gerçek maliyeti düşer. Yerel yanıtlar ücretsizdir.',
                ),
                style: const TextStyle(
                  height: 1.45,
                  color: Color(0xFF536873),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ConsentTile(
          icon: Icons.auto_awesome_rounded,
          value: data['remote_ai_consent'] == true,
          enabled: !changingConsent,
          onChanged: _setRemoteAiConsent,
          title: t(
            'Personalized intelligence',
            'ذكاء مخصص لك',
            'Intelligence personnalisée',
            'Inteligencia personalizada',
            'Kişiselleştirilmiş zekâ',
          ),
          subtitle: t(
            'When enabled, only the bounded context needed for your question is sent to BIL’s Gemini service. Conversation history remains local except for the last 12 turns sent with that request. Turn this off at any time.',
            'عند التفعيل، يُرسل إلى خدمة Gemini التابعة لـBIL فقط السياق المحدود اللازم لسؤالك. يبقى سجل المحادثة محليًا باستثناء آخر 12 رسالة تُرسل مع ذلك الطلب. يمكنك إيقافه في أي وقت.',
            'Lorsque cette option est activée, seul le contexte limité nécessaire à votre question est envoyé au service Gemini de BIL. L’historique reste local, hormis les 12 derniers messages envoyés avec cette requête. Vous pouvez désactiver cette option à tout moment.',
            'Cuando está activado, solo se envía al servicio Gemini de BIL el contexto limitado necesario para tu pregunta. El historial permanece local, salvo los últimos 12 mensajes enviados con esa solicitud. Puedes desactivarlo en cualquier momento.',
            'Etkinleştirildiğinde yalnızca sorunuz için gereken sınırlı bağlam BIL’in Gemini hizmetine gönderilir. Konuşma geçmişi, istekle gönderilen son 12 mesaj dışında yerel kalır. İstediğiniz zaman kapatabilirsiniz.',
          ),
        ),
        const SizedBox(height: 10),
        _ContextFocusCard(
          focuses: effectiveFocuses,
          enabled: !changingContextFocus,
          onChanged: (focus, included) =>
              _setContextFocus(focus, included, effectiveFocuses),
          t: t,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F8FA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD7E4E9)),
          ),
          child: ListTile(
            leading: const BilSemanticIconBadge(
              kind: BilSemanticIconKind.privacy,
              iconOverride: Icons.phonelink_lock_rounded,
              appleIconOverride: Icons.phonelink_lock_rounded,
            ),
            title: Text(
              t(
                'Your platform handles speech recognition',
                'تتولى خدمة المنصة التعرّف على الكلام',
                'Votre plateforme gère la reconnaissance vocale',
                'Tu plataforma gestiona el reconocimiento de voz',
                'Konuşma tanımayı platformunuz gerçekleştirir',
              ),
            ),
            subtitle: Text(
              t(
                'Raw microphone audio is not sent to BIL or Gemini. Your device or platform speech service converts it to text under its settings; only recognized text is sent when you submit.',
                'لا يُرسل صوت الميكروفون الخام إلى BIL أو Gemini. تحوّله خدمة الكلام في جهازك أو منصتك إلى نص وفق إعداداتها؛ ولا يُرسل سوى النص المتعرّف عليه عندما ترسله.',
                'Le son brut du microphone n’est pas envoyé à BIL ni à Gemini. Le service vocal de votre appareil ou de votre plateforme le convertit en texte selon ses réglages ; seul le texte reconnu est envoyé lorsque vous validez.',
                'El audio sin procesar del micrófono no se envía a BIL ni a Gemini. El servicio de voz del dispositivo o de la plataforma lo convierte en texto según sus ajustes; solo se envía el texto reconocido cuando lo confirmas.',
                'Ham mikrofon sesi BIL’e veya Gemini’ye gönderilmez. Cihazınızdaki ya da platformdaki konuşma hizmeti, kendi ayarlarına göre sesi metne dönüştürür; yalnızca gönderdiğinizde tanınan metin iletilir.',
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _BoostCard(boost: boost, t: t),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _manageSubscription,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(
            t(
              'Manage subscription in store',
              'إدارة الاشتراك في المتجر',
              'Gérer l’abonnement',
              'Gestionar suscripción',
              'Aboneliği yönet',
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState(Object? error) {
    final authenticationRequired = error.toString().contains(
      'authentication_required',
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              authenticationRequired
                  ? Icons.person_outline_rounded
                  : Icons.cloud_off_rounded,
              size: 46,
              color: const Color(0xFF536873),
            ),
            const SizedBox(height: 12),
            Text(
              authenticationRequired
                  ? context.strings.text(
                      'Sign in and try again to manage AI Coach access.',
                    )
                  : t(
                      'Could not load your Coach balance. Check your account and try again.',
                      'تعذّر تحميل رصيد المدرب. تحقق من حسابك وحاول مجددًا.',
                      'Impossible de charger le solde. Réessayez.',
                      'No se pudo cargar el saldo. Inténtalo de nuevo.',
                      'Koç bakiyesi yüklenemedi. Tekrar deneyin.',
                    ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: authenticationRequired
                  ? () => context.push('/login')
                  : () => setState(() => usage = _loadUsage()),
              icon: Icon(
                authenticationRequired
                    ? Icons.login_rounded
                    : Icons.refresh_rounded,
              ),
              label: Text(
                authenticationRequired
                    ? context.strings.text('Sign in')
                    : t(
                        'Try again',
                        'حاول مجددًا',
                        'Réessayer',
                        'Reintentar',
                        'Tekrar dene',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _int(Object? value) => value is num ? value.toInt() : 0;

  Future<void> _dismissResetNotice(String resetId) async {
    final client = Supabase.instance.client;
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) return;
    try {
      final changed = await client.rpc(
        'bil_dismiss_ai_coach_reset_notice',
        params: <String, Object?>{'p_owner_id': ownerId, 'p_reset_id': resetId},
      );
      if (changed != true) return;
      if (mounted) setState(() => usage = _loadUsage());
    } on Object {
      // Keep the notice visible when acknowledgement did not persist.
    }
  }

  Future<void> _manageSubscription() async {
    final uri = defaultTargetPlatform == TargetPlatform.iOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    boost.removeListener(_boostChanged);
    boost.dispose();
    super.dispose();
  }
}
