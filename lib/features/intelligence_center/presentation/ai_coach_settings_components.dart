part of 'ai_coach_settings_page.dart';

class _ContextFocusCard extends StatelessWidget {
  const _ContextFocusCard({
    required this.focuses,
    required this.enabled,
    required this.onChanged,
    required this.t,
  });

  final Set<CoachContextFocus> focuses;
  final bool enabled;
  final void Function(CoachContextFocus focus, bool included) onChanged;
  final _Copy t;

  @override
  Widget build(BuildContext context) {
    final options = <(CoachContextFocus, IconData, String)>[
      (
        CoachContextFocus.nutrition,
        Icons.restaurant_menu_rounded,
        t(
          'Nutrition and meals',
          'التغذية والوجبات',
          'Nutrition et repas',
          'Nutrición y comidas',
          'Beslenme ve öğünler',
        ),
      ),
      (
        CoachContextFocus.training,
        Icons.directions_run_rounded,
        t(
          'Training and activity',
          'التدريب والنشاط',
          'Entraînement et activité',
          'Entrenamiento y actividad',
          'Antrenman ve aktivite',
        ),
      ),
      (
        CoachContextFocus.habits,
        Icons.bedtime_outlined,
        t(
          'Sleep, fasting and habits',
          'النوم والصيام والعادات',
          'Sommeil, jeûne et habitudes',
          'Sueño, ayuno y hábitos',
          'Uyku, oruç ve alışkanlıklar',
        ),
      ),
      (
        CoachContextFocus.analytics,
        Icons.insights_rounded,
        t(
          'Progress analytics',
          'تحليلات التقدم',
          'Analyses de progression',
          'Análisis del progreso',
          'İlerleme analizleri',
        ),
      ),
    ];

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.tune_rounded,
            title: t(
              'Choose whether to use cloud AI',
              'اختر ما إذا كنت تريد استخدام الذكاء السحابي',
              'Choisissez si vous souhaitez utiliser l’IA cloud',
              'Elige si quieres usar la IA en la nube',
              'Bulut yapay zekâyı kullanıp kullanmayacağınızı seçin',
            ),
          ),
          const SizedBox(height: 5),
          Text(
            t(
              'AI Coach is optional, is not a doctor, and receives text context only after explicit consent. Voice recognition remains separate from this consent.',
              'مدرب AI اختياري وليس طبيبًا، ولا يتلقى السياق النصي إلا بعد موافقة صريحة. يظل التعرف على الكلام منفصلًا عن هذه الموافقة.',
              'Le Coach IA est facultatif, ne remplace pas un médecin et ne reçoit le contexte textuel qu’après un consentement explicite. La reconnaissance vocale reste distincte.',
              'El Coach con IA es opcional, no es un médico y solo recibe contexto de texto tras tu consentimiento explícito. El reconocimiento de voz es independiente.',
              'AI Koç isteğe bağlıdır, doktor değildir ve metin bağlamını yalnızca açık onaydan sonra alır. Konuşma tanıma bu onaydan ayrıdır.',
            ),
            style: const TextStyle(color: Color(0xFF536873), height: 1.4),
          ),
          const SizedBox(height: 4),
          for (final option in options)
            CheckboxListTile(
              key: Key('ai-coach-context-${option.$1.name}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.trailing,
              secondary: BilSemanticIconBadge(
                kind: BilSemanticIconKind.aiCoach,
                iconOverride: option.$2,
                appleIconOverride: option.$2,
              ),
              value: focuses.contains(option.$1),
              onChanged: enabled
                  ? (value) => onChanged(option.$1, value == true)
                  : null,
              title: Text(
                option.$3,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResetGiftBanner extends StatelessWidget {
  const _ResetGiftBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('ai-coach-global-reset-notice'),
    color: const Color(0xFFEAF8F0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFB7E3CA)),
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.card_giftcard_rounded, color: Color(0xFF17784C)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF123D2B),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            key: const Key('ai-coach-global-reset-notice-dismiss'),
            onPressed: onDismiss,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    ),
  );
}

class _BoostCard extends StatelessWidget {
  const _BoostCard({required this.boost, required this.t});
  final AiBoostPurchaseService boost;
  final _Copy t;

  @override
  Widget build(BuildContext context) => _PremiumCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final artworkSize = (constraints.maxWidth * .24)
                .clamp(72.0, 96.0)
                .toDouble();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BilAiBoostCoachArtwork(
                  key: const ValueKey('settings-ai-boost-coach-artwork'),
                  size: artworkSize,
                  semanticLabel: 'BIL AI Boost',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BIL AI Boost',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF071923),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '+2,500 BIL AI Tokens',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF071923),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'A verified, non-expiring balance for text, voice, or Vision. Price is supplied by your store.',
            'رصيد موثّق لا تنتهي صلاحيته للنص أو الصوت أو الصور. يعرض متجرك السعر.',
            'Un solde vérifié sans expiration. Le prix vient de votre boutique.',
            'Saldo verificado sin caducidad. Tu tienda muestra el precio.',
            'Metin, ses ve görüntü için süresiz bakiye. Fiyatı mağazanız gösterir.',
          ),
          style: const TextStyle(color: Color(0xFF536873), height: 1.4),
        ),
        if (boost.displayPrice != null) ...[
          const SizedBox(height: 7),
          Text(
            boost.displayPrice!,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF12394E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: boost.state == AiBoostPurchaseState.ready
              ? boost.purchaseBoost
              : null,
          icon: Icon(
            boost.state == AiBoostPurchaseState.pending
                ? Icons.hourglass_top_rounded
                : Icons.lock_rounded,
          ),
          label: Text(
            boost.state == AiBoostPurchaseState.pending
                ? t(
                    'Waiting for store…',
                    'بانتظار المتجر…',
                    'En attente…',
                    'Esperando…',
                    'Mağaza bekleniyor…',
                  )
                : t(
                    'Buy verified Boost',
                    'شراء Boost موثّق',
                    'Acheter le Boost',
                    'Comprar Boost',
                    'Doğrulanmış Boost al',
                  ),
          ),
        ),
        if (boost.errorCode != null) ...[
          const SizedBox(height: 8),
          Text(
            t(
              'The store product is unavailable or verification failed. No tokens were granted.',
              'منتج المتجر غير متاح أو فشل التحقق. لم يُمنح أي رصيد.',
              'Le produit est indisponible ou la vérification a échoué.',
              'El producto no está disponible o falló la verificación.',
              'Ürün kullanılamıyor veya doğrulama başarısız.',
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
  );
}

String _number(int value) {
  final source = value.toString();
  return source.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}
