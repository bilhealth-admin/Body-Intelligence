import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/localization/app_localizations.dart';
import '../../commerce/presentation/ai_boost_coach_artwork.dart';
import '../services/ai_boost_purchase_service.dart';

part 'ai_coach_settings_components.dart';

class AiCoachSettingsPage extends StatefulWidget {
  const AiCoachSettingsPage({super.key});

  @override
  State<AiCoachSettingsPage> createState() => _AiCoachSettingsPageState();
}

class _AiCoachSettingsPageState extends State<AiCoachSettingsPage>
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
    if (boost.state == AiBoostPurchaseState.verified) usage = _loadUsage();
    setState(() {});
  }

  Future<Map<String, Object?>> _loadUsage() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw StateError('authentication_required');
    }
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _TokenHero(
          totalRemaining: totalRemaining,
          weeklyRemaining: weeklyRemaining,
          weeklyLimit: weeklyLimit,
          paidRemaining: paidRemaining,
          spentFraction: spentFraction,
          active: active,
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

typedef _Copy = String Function(String, String, String, String, String);

class _TokenHero extends StatelessWidget {
  const _TokenHero({
    required this.totalRemaining,
    required this.weeklyRemaining,
    required this.weeklyLimit,
    required this.paidRemaining,
    required this.spentFraction,
    required this.active,
    required this.resetAt,
    required this.t,
  });

  final int totalRemaining;
  final int weeklyRemaining;
  final int weeklyLimit;
  final int paidRemaining;
  final double spentFraction;
  final bool active;
  final String resetAt;
  final _Copy t;

  @override
  Widget build(BuildContext context) {
    const light = Color(0xFFC8F3FF);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12394E), Color(0xFF071923)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26071923),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -18,
            bottom: -6,
            child: Opacity(
              opacity: 0.42,
              child: Image.asset(
                'assets/images/ai_coach/bil_male_smart_coach_v1.png',
                height: 210,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Image.asset(
                  'assets/images/flagship/bil_body_intelligence_journey_v1.png',
                  height: 210,
                  fit: BoxFit.cover,
                  alignment: const Alignment(.18, -.72),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 190),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (active ? const Color(0xFF65D59A) : Colors.white)
                                  .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active
                                ? const Color(0xFF65D59A)
                                : Colors.white54,
                          ),
                        ),
                        child: Text(
                          active
                              ? t(
                                  'COACH ACTIVE',
                                  'المدرب نشط',
                                  'COACH ACTIF',
                                  'COACH ACTIVO',
                                  'KOÇ AKTİF',
                                )
                              : t(
                                  'BOOST BALANCE',
                                  'رصيد BOOST',
                                  'SOLDE BOOST',
                                  'SALDO BOOST',
                                  'BOOST BAKİYESİ',
                                ),
                          style: TextStyle(
                            color: active
                                ? const Color(0xFF8BE6B5)
                                : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _number(totalRemaining),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'BIL AI Tokens',
                    style: TextStyle(
                      color: light,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 225,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: 1 - spentFraction,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.13),
                        valueColor: const AlwaysStoppedAnimation(light),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    t(
                      '${_number(weeklyRemaining)} of ${_number(weeklyLimit)} left this week',
                      'تبقى ${_number(weeklyRemaining)} من ${_number(weeklyLimit)} هذا الأسبوع',
                      '${_number(weeklyRemaining)} sur ${_number(weeklyLimit)} cette semaine',
                      '${_number(weeklyRemaining)} de ${_number(weeklyLimit)} esta semana',
                      'Bu hafta ${_number(weeklyLimit)} tokenden ${_number(weeklyRemaining)} kaldı',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    paidRemaining > 0
                        ? '${_number(paidRemaining)} ${t('non-expiring Boost', 'Boost لا تنتهي صلاحيته', 'Boost sans expiration', 'Boost sin caducidad', 'süresiz Boost')}'
                        : '${t('Resets', 'يتجدد', 'Réinitialisation', 'Se reinicia', 'Yenilenir')} $resetAt',
                    style: const TextStyle(
                      color: Color(0xBFFFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xFFE2EBEF)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF12394E)),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF071923),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F7FA),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF1D8ACB)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => _PremiumCard(
    child: SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: enabled ? onChanged : null,
      activeTrackColor: const Color(0xFF1D8ACB),
      secondary: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5FB),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: const Color(0xFF12394E)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(subtitle, style: const TextStyle(height: 1.4)),
      ),
    ),
  );
}
