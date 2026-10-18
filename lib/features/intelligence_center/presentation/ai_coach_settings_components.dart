part of 'ai_coach_settings_page.dart';

class _CoachActionPermissionCard extends ConsumerWidget {
  const _CoachActionPermissionCard({required this.t});

  final _Copy t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(coachActionPermissionModeProvider);
    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.admin_panel_settings_outlined,
            title: t(
              'Coach action permissions',
              'صلاحيات إجراءات المدرب',
              'Autorisations des actions du Coach',
              'Permisos de acciones del Coach',
              'Koç eylem izinleri',
            ),
          ),
          const SizedBox(height: 5),
          Text(
            t(
              'Choose how the Coach handles changes. Sensitive and destructive actions always require confirmation. This preference applies for the current app session.',
              'اختر طريقة تعامل المدرب مع التغييرات. تتطلب الإجراءات الحساسة أو الحذف تأكيدًا دائمًا. يسري هذا الاختيار خلال جلسة التطبيق الحالية.',
              'Choisissez comment le Coach traite les modifications. Les actions sensibles ou destructrices nécessitent toujours une confirmation. Ce choix s’applique à la session actuelle.',
              'Elige cómo gestiona el Coach los cambios. Las acciones sensibles o destructivas siempre requieren confirmación. Esta preferencia se aplica a la sesión actual.',
              'Koçun değişiklikleri nasıl ele alacağını seçin. Hassas ve silici işlemler her zaman onay gerektirir. Bu tercih geçerli uygulama oturumu için geçerlidir.',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          RadioGroup<CoachActionPermissionMode>(
            groupValue: selected,
            onChanged: (next) {
              if (next != null) {
                ref.read(coachActionPermissionModeProvider.notifier).state =
                    next;
              }
            },
            child: Column(
              children: [
                for (final mode in CoachActionPermissionMode.values)
                  RadioListTile<CoachActionPermissionMode>(
                    key: Key('ai-coach-permission-${mode.name}'),
                    value: mode,
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(switch (mode) {
                      CoachActionPermissionMode.readOnly => t(
                        'Read only',
                        'قراءة فقط',
                        'Lecture seule',
                        'Solo lectura',
                        'Yalnızca okuma',
                      ),
                      CoachActionPermissionMode.askBeforeWrite => t(
                        'Ask before write',
                        'اسأل قبل الحفظ',
                        'Demander avant modification',
                        'Preguntar antes de guardar',
                        'Yazmadan önce sor',
                      ),
                      CoachActionPermissionMode.writeAllowed => t(
                        'Write allowed',
                        'السماح بالتغييرات القابلة للتراجع',
                        'Modifications réversibles autorisées',
                        'Permitir cambios reversibles',
                        'Geri alınabilir değişikliklere izin ver',
                      ),
                    }),
                    subtitle: Text(switch (mode) {
                      CoachActionPermissionMode.readOnly => t(
                        'The Coach can review your selected BIL context but will not save changes.',
                        'يمكن للمدرب مراجعة سياق BIL الذي اخترته، لكنه لن يحفظ تغييرات.',
                        'Le Coach peut consulter le contexte BIL choisi sans enregistrer de modifications.',
                        'El Coach puede revisar el contexto BIL elegido, pero no guardará cambios.',
                        'Koç seçtiğiniz BIL bağlamını inceleyebilir, ancak değişiklikleri kaydetmez.',
                      ),
                      CoachActionPermissionMode.askBeforeWrite => t(
                        'The Coach asks before saving reversible changes.',
                        'يطلب المدرب تأكيدك قبل حفظ التغييرات القابلة للتراجع.',
                        'Le Coach demande votre accord avant d’enregistrer une modification réversible.',
                        'El Coach pide confirmación antes de guardar cambios reversibles.',
                        'Koç, geri alınabilir değişiklikleri kaydetmeden önce onayınızı ister.',
                      ),
                      CoachActionPermissionMode.writeAllowed => t(
                        'The Coach may save reversible changes without an extra prompt. Sensitive or destructive actions still require confirmation.',
                        'يمكن للمدرب حفظ التغييرات القابلة للتراجع دون سؤال إضافي. وتظل الإجراءات الحساسة أو الحذف بحاجة إلى تأكيد.',
                        'Le Coach peut enregistrer des changements réversibles sans demander à nouveau. Les actions sensibles ou destructrices exigent toujours une confirmation.',
                        'El Coach puede guardar cambios reversibles sin otra pregunta. Las acciones sensibles o destructivas siguen requiriendo confirmación.',
                        'Koç geri alınabilir değişiklikleri ek bir soru sormadan kaydedebilir. Hassas ve silici işlemler yine de onay gerektirir.',
                      ),
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
              'Context included in answers',
              'السياق المستخدم في الإجابات',
              'Contexte inclus dans les réponses',
              'Contexto incluido en las respuestas',
              'Yanıtlara dahil edilen bağlam',
            ),
          ),
          const SizedBox(height: 5),
          BilClinicalNote(
            title: t(
              'Health guidance boundary',
              'حدود الإرشاد الصحي',
              'Limites des conseils de santé',
              'Límite de orientación de salud',
              'Sağlık rehberliği sınırı',
            ),
            text: t(
              'AI Coach is optional, is not a doctor, and receives text context only after explicit consent. Voice recognition remains separate from this consent.',
              'مدرب AI اختياري وليس طبيبًا، ولا يتلقى السياق النصي إلا بعد موافقة صريحة. يظل التعرف على الكلام منفصلًا عن هذه الموافقة.',
              'Le Coach IA est facultatif, ne remplace pas un médecin et ne reçoit le contexte textuel qu’après un consentement explicite. La reconnaissance vocale reste distincte.',
              'El Coach con IA es opcional, no es un médico y solo recibe contexto de texto tras tu consentimiento explícito. El reconocimiento de voz es independiente.',
              'AI Koç isteğe bağlıdır, doktor değildir ve metin bağlamını yalnızca açık onaydan sonra alır. Konuşma tanıma bu onaydan ayrıdır.',
            ),
          ),
          const SizedBox(height: 4),
          for (final option in options)
            CheckboxListTile(
              key: Key('ai-coach-context-${option.$1.name}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.trailing,
              secondary: BilGlassPressFeedback(
                child: Icon(
                  option.$2,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
    color: Theme.of(context).colorScheme.tertiaryContainer,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.card_giftcard_rounded,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onTertiaryContainer,
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
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '+2,500 BIL AI Tokens',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
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
          onPressed: boost.canPurchase ? boost.purchaseBoost : null,
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
        if (boost.canRetry) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: boost.retryPendingTransaction,
            child: Text(
              t(
                'Check existing store transaction',
                'التحقق من معاملة المتجر الحالية',
                'Vérifier la transaction existante',
                'Comprobar la transacción existente',
                'Mevcut mağaza işlemini kontrol et',
              ),
            ),
          ),
        ],
        if (boost.errorCode != null) ...[
          const SizedBox(height: 8),
          Text(
            boost.lastDelivery?.active == false &&
                    const {
                      'purchase_inactive',
                      'store_finish_pending',
                    }.contains(boost.errorCode)
                ? BilStoreCopy.text(
                    Localizations.localeOf(context).toLanguageTag(),
                    'purchase_inactive',
                  )
                : boost.errorCode == 'store_finish_pending'
                ? t(
                    'Your Boost was verified. Store confirmation is still pending; check the existing transaction before buying again.',
                    'تم التحقق من Boost. تأكيد المتجر ما زال معلقًا؛ تحقق من المعاملة الحالية قبل الشراء مجددًا.',
                    'Boost vérifié. La confirmation du magasin reste en attente.',
                    'Boost verificado. La confirmación de la tienda sigue pendiente.',
                    'Boost doğrulandı. Mağaza onayı bekleniyor.',
                  )
                : boost.errorCode == 'purchase_cancelled'
                ? t(
                    'Purchase cancelled. You can try again.',
                    'تم إلغاء الشراء. يمكنك المحاولة مجددًا.',
                    'Achat annulé. Vous pouvez réessayer.',
                    'Compra cancelada. Puedes volver a intentarlo.',
                    'Satın alma iptal edildi. Tekrar deneyebilirsiniz.',
                  )
                : t(
                    'The store or verification did not finish. Your balance will be refreshed from BIL; check an existing transaction before buying again.',
                    'لم يكتمل المتجر أو التحقق. سيُحدّث الرصيد من BIL؛ تحقق من المعاملة الحالية قبل الشراء مجددًا.',
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
