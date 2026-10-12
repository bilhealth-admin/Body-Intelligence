part of 'ai_coach_settings_page.dart';

extension _AiCoachSettingsBody on _AiCoachSettingsPageState {
  Widget _settingsBody(
    Map<String, Object?>? received, {
    Object? usageError,
    Object? contextError,
    bool usageLoading = false,
  }) {
    final data = received ?? const <String, Object?>{};
    final loadedFocuses =
        _lastLocalContext?.focuses ?? const <CoachContextFocus>{};
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
        if (_lastLocalContext != null)
          _ContextFocusCard(
            focuses: effectiveFocuses,
            enabled: !changingContextFocus && _lastLocalContext != null,
            onChanged: (focus, included) =>
                _setContextFocus(focus, included, effectiveFocuses),
            t: t,
          ),
        if (_lastLocalContext == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: contextError == null
                ? const LinearProgressIndicator()
                : TextButton(
                    onPressed: () =>
                        ref.invalidate(coachSettingsContextProvider),
                    child: Text(context.strings.text('Try again')),
                  ),
          ),
        const SizedBox(height: 20),
        _SectionTitle(
          icon: Icons.privacy_tip_outlined,
          title: t(
            'Context and privacy',
            'السياق والخصوصية',
            'Contexte et confidentialité',
            'Contexto y privacidad',
            'Bağlam ve gizlilik',
          ),
        ),
        const SizedBox(height: 12),
        _ConsentTile(
          icon: Icons.auto_awesome_rounded,
          value: data['remote_ai_consent'] == true,
          enabled:
              !changingConsent &&
              received != null &&
              data['consent_status_available'] == true,
          onChanged: _setRemoteAiConsent,
          title: t(
            'Google Gemini AI consent',
            'ذكاء مخصص لك',
            'Intelligence personnalisée',
            'Inteligencia personalizada',
            'Kişiselleştirilmiş zekâ',
          ),
          subtitle: t(
            'When enabled, your question and selected weight/body, nutrition, activity, sleep, habit, and recent conversation context can be sent to Google Gemini, a third-party AI service operated by Google, only to answer your request. Turn this off at any time; local BIL features remain available.',
            'عند التفعيل، قد يُرسل سؤالك والسياق المحدد عن الوزن والجسم والتغذية والنشاط والنوم والعادات والمحادثة الحديثة إلى Google Gemini، وهي خدمة ذكاء اصطناعي تابعة لجهة خارجية وتديرها Google، فقط للإجابة عن طلبك. يمكنك إيقافه في أي وقت، وتبقى ميزات BIL المحلية متاحة.',
            'Lorsque cette option est activée, seul le contexte limité nécessaire à votre question est envoyé au service Gemini de BIL. L’historique reste local, hormis les 12 derniers messages envoyés avec cette requête. Vous pouvez désactiver cette option à tout moment.',
            'Cuando está activado, solo se envía al servicio Gemini de BIL el contexto limitado necesario para tu pregunta. El historial permanece local, salvo los últimos 12 mensajes enviados con esa solicitud. Puedes desactivarlo en cualquier momento.',
            'Etkinleştirildiğinde yalnızca sorunuz için gereken sınırlı bağlam BIL’in Gemini hizmetine gönderilir. Konuşma geçmişi, istekle gönderilen son 12 mesaj dışında yerel kalır. İstediğiniz zaman kapatabilirsiniz.',
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            leading: const BilFlatIcon(
              kind: BilSemanticIconKind.privacy,
              materialIcon: Icons.phonelink_lock_rounded,
              appleIcon: Icons.phonelink_lock_rounded,
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
        if (resetNoticeId.isNotEmpty) ...[
          _ResetGiftBanner(
            message: authoredResetMessage?.isNotEmpty == true
                ? authoredResetMessage!
                : context.strings.text(_globalResetGiftCopy),
            onDismiss: () => _dismissResetNotice(resetNoticeId),
          ),
          const SizedBox(height: 14),
        ],
        _SectionTitle(
          icon: Icons.account_balance_wallet_outlined,
          title: t(
            'Balance and usage',
            'الرصيد والاستخدام',
            'Solde et utilisation',
            'Saldo y uso',
            'Bakiye ve kullanım',
          ),
        ),
        const SizedBox(height: 12),
        if (received == null)
          usageLoading
              ? const LinearProgressIndicator()
              : _errorState(usageError)
        else
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
        if (received != null)
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
                  style: TextStyle(
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        if (received != null) _BoostCard(boost: boost, t: t),
        const SizedBox(height: 8),
        if (received != null)
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
}
