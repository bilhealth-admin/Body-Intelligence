import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/bil_coach_identity.dart';
import '../../commerce/presentation/ai_boost_coach_artwork.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../services/ai_boost_purchase_service.dart';

part 'ai_coach_settings_components.dart';
part 'ai_coach_settings_usage_widgets.dart';

const _globalResetGiftCopy =
    'A gift from BIL 🎁 Your AI Coach usage has been fully reset. You can use your allowance again until the end of your current cycle.';

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
    setState(() => usage = _loadUsage());
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
          .select('reset_id,created_at')
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

  Future<void> _setRemoteAiConsent(
    bool granted, {
    String policyVersion = '1',
  }) async {
    if (changingConsent) return;
    setState(() => changingConsent = true);
    try {
      await Supabase.instance.client.rpc(
        'bil_record_consent',
        params: <String, Object?>{
          'p_purpose': 'remote_ai',
          'p_policy_version': policyVersion,
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

  String t(String en, String ar, String fr, String es, String tr) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ar' => ar,
      'en' => en,
      'fr' => fr,
      'es' => es,
      'tr' => tr,
      _ => context.strings.text(en),
    };
  }

  @override
  Widget build(BuildContext context) {
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
              setState(() => usage = fresh);
              await fresh;
            },
            child: _settingsBody(snapshot.data!),
          );
        },
      ),
    );
  }

  Widget _settingsBody(Map<String, Object?> data) {
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (resetNoticeId.isNotEmpty) ...[
          _ResetGiftBanner(
            message: context.strings.text(_globalResetGiftCopy),
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
            'Send only the bounded context needed to answer your question. Your full diary and full conversation are never uploaded.',
            'يرسل فقط السياق المحدود اللازم للإجابة. لا تُرفع يومياتك أو محادثتك كاملة.',
            'Seul le contexte strictement nécessaire est envoyé.',
            'Solo se envía el contexto estrictamente necesario.',
            'Yalnızca yanıt için gereken sınırlı bağlam gönderilir.',
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F8FA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD7E4E9)),
          ),
          child: ListTile(
            leading: const Icon(Icons.phonelink_lock_rounded),
            title: Text(
              t(
                'Voice stays on this device',
                'الصوت يبقى على هذا الجهاز',
                'La voix reste sur cet appareil',
                'La voz permanece en este dispositivo',
                'Ses bu cihazda kalır',
              ),
            ),
            subtitle: Text(
              t(
                'Your device turns speech into text. Only that recognized text can be sent to Gemini.',
                'يحوّل جهازك الكلام إلى نص. لا يُرسل إلى Gemini إلا النص الناتج.',
                'Votre appareil transforme la parole en texte. Seul ce texte peut être envoyé à Gemini.',
                'Tu dispositivo convierte la voz en texto. Solo ese texto puede enviarse a Gemini.',
                'Cihazınız konuşmayı metne çevirir. Gemini’ye yalnızca bu metin gönderilebilir.',
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
