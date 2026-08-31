part of 'intelligence_center_page.dart';

@visibleForTesting
String coachGreetingKeyForHour(int hour) {
  if (hour < 0 || hour > 23) {
    throw ArgumentError.value(hour, 'hour', 'must be from 0 through 23');
  }
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

@visibleForTesting
String coachGreetingSeparator({required bool arabic}) =>
    arabic ? '\u060C' : ',';

extension _IntelligenceConversationVoice on _IntelligenceCenterPageState {
  Future<bool> _ensureCoachRuntimePermission(
    BilRuntimeCapability capability, {
    bool includeSpeechRecognition = false,
  }) async {
    const policy = BilRuntimePermissionPolicy();
    var effectiveCapability = capability;
    var current = await policy.status(effectiveCapability);
    if (includeSpeechRecognition &&
        capability == BilRuntimeCapability.microphone &&
        current == BilRuntimePermissionState.granted &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      effectiveCapability = BilRuntimeCapability.speechRecognition;
      current = await policy.status(effectiveCapability);
    }
    if (current == BilRuntimePermissionState.granted) return true;
    if (!mounted) return false;
    final capabilityName = capability == BilRuntimeCapability.camera
        ? tr('camera', 'الكاميرا')
        : tr('microphone', 'الميكروفون');
    if (current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('Access is off', 'الوصول متوقف')),
          content: Text(
            tr(
              'BIL only uses the $capabilityName after you start this feature. Enable it in system settings to continue.',
              'يستخدم BIL $capabilityName فقط بعد بدء هذه الميزة. فعّل الإذن في إعدادات النظام للمتابعة.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('Not now', 'ليس الآن')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr('Open system settings', 'فتح إعدادات النظام')),
            ),
          ],
        ),
      );
      if (open == true) await policy.openSettings();
      return false;
    }
    final continueRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          tr(
            'Allow $capabilityName for this action?',
            'السماح بـ $capabilityName لهذا الإجراء؟',
          ),
        ),
        content: Text(
          capability == BilRuntimeCapability.microphone
              ? tr(
                  'BIL starts listening only after you press the voice button. On iPhone, speech recognition may ask separately.',
                  'يبدأ BIL الاستماع فقط بعد الضغط على زر الصوت. قد يطلب iPhone إذن التعرف على الكلام بشكل منفصل.',
                )
              : tr(
                  'BIL opens the camera only for the food photo you selected and never at startup.',
                  'يفتح BIL الكاميرا فقط لصورة الطعام التي اخترتها وليس عند بدء التطبيق.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Not now', 'ليس الآن')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Continue', 'متابعة')),
          ),
        ],
      ),
    );
    if (continueRequest != true) return false;
    final granted =
        await policy.request(effectiveCapability) ==
        BilRuntimePermissionState.granted;
    if (!granted || effectiveCapability != BilRuntimeCapability.microphone) {
      return granted;
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;
    return _ensureCoachRuntimePermission(
      capability,
      includeSpeechRecognition: includeSpeechRecognition,
    );
  }

  Future<void> _loadConversation() async {
    final preferences = ref.read(preferencesRepositoryProvider);
    final stored = await preferences.get('intelligenceConversationV1');
    final storedContextFingerprint = await preferences.get(
      'intelligenceConversationContextV1',
    );
    final contextRevision = await _coachContextRevision();
    if (!mounted) return;
    final restored = <IntelligenceMessage>[];
    final contextFingerprintChanged = storedContextFingerprint == null
        ? contextRevision.hasContext
        : storedContextFingerprint != contextRevision.fingerprint;
    var removedStaleContextTurns = contextFingerprintChanged;
    if (!contextFingerprintChanged && stored != null && stored.isNotEmpty) {
      try {
        final decoded = jsonDecode(stored) as List<Object?>;
        for (final value in decoded.whereType<Map>()) {
          final message = _presentationSafeMessage(
            IntelligenceMessage.fromJson(Map<String, Object?>.from(value)),
          );
          if (_isStaleAccessLock(message)) continue;
          if (contextRevision.changedAt != null &&
              message.createdAt.isBefore(contextRevision.changedAt!)) {
            removedStaleContextTurns = true;
            continue;
          }
          restored.add(message);
        }
      } catch (_) {
        restored.clear();
      }
    }
    final displayName = await _resolvedCoachDisplayName();
    if (!mounted) return;
    final now = ref.read(intelligenceConversationClockProvider)();
    final welcome = _sessionWelcome(displayName, at: now);
    _updateState(() {
      introVisible = true;
      messages
        ..clear()
        ..addAll(restored.where((message) => !message.id.startsWith('welcome')))
        ..add(
          IntelligenceMessage(
            id: 'welcome-session-${now.microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: welcome,
            createdAt: now,
            modality: IntelligenceMessageModality.system,
          ),
        );
    });
    if (removedStaleContextTurns) await _saveConversation();
    _scrollToLatest(jump: true);
  }

  Future<({DateTime? changedAt, String fingerprint, bool hasContext})>
  _coachContextRevision() async {
    DateTime? latest;
    var weightCount = 0;
    var dailyLogCount = 0;
    String? oldestWeightDay;
    String? latestWeightDay;
    try {
      final weights = await ref.read(weightRepositoryProvider).getAll();
      weightCount = weights.length;
      for (final entry in weights) {
        if (latest == null || entry.updatedAt.isAfter(latest)) {
          latest = entry.updatedAt;
        }
        final day = entry.dayKey;
        if (day != null) {
          if (oldestWeightDay == null || day.compareTo(oldestWeightDay) < 0) {
            oldestWeightDay = day;
          }
          if (latestWeightDay == null || day.compareTo(latestWeightDay) > 0) {
            latestWeightDay = day;
          }
        }
      }
    } on Object {
      // Conversation restore must remain available if one local source fails.
    }
    try {
      final logs = await ref.read(dailyLogRepositoryProvider).getAll();
      dailyLogCount = logs.length;
      for (final log in logs) {
        if (latest == null || log.updatedAt.isAfter(latest)) {
          latest = log.updatedAt;
        }
      }
    } on Object {
      // The available source still provides a safe lower-bound cutoff.
    }
    final fingerprint = <String>[
      'w:$weightCount',
      'wo:${oldestWeightDay ?? '-'}',
      'wl:${latestWeightDay ?? '-'}',
      'd:$dailyLogCount',
      'u:${latest?.toUtc().microsecondsSinceEpoch ?? 0}',
    ].join('|');
    return (
      changedAt: latest,
      fingerprint: fingerprint,
      hasContext: weightCount > 0 || dailyLogCount > 0,
    );
  }

  bool _isStaleAccessLock(IntelligenceMessage message) {
    if (message.role != IntelligenceMessageRole.bil) return false;
    final normalized = message.text.toLowerCase();
    return normalized.contains('personalized ai is off') ||
        normalized.contains('enable remote ai consent') ||
        normalized.contains('ai consent required') ||
        normalized.contains('الذكاء الاصطناعي المخصص متوقف') ||
        normalized.contains('موافقة الذكاء الاصطناعي البعيد');
  }

  String _sessionWelcome(String? displayName, {required DateTime at}) {
    final hour = at.hour;
    final greeting = switch (coachGreetingKeyForHour(hour)) {
      'Good morning' => tr('Good morning', 'صباح الخير'),
      'Good afternoon' => tr('Good afternoon', 'مساء الخير'),
      _ => tr('Good evening', 'مساء الخير'),
    };
    final name = displayName?.trim();
    final memberName = name == null || name.isEmpty
        ? tr('BIL member', 'عضو BIL')
        : name;
    final next = tr(
      'I’m ready for your next useful decision.',
      'أنا جاهز لقرارك المفيد التالي.',
    );
    final separator = coachGreetingSeparator(arabic: arabic);
    return '$greeting$separator $memberName. $next';
  }

  Future<String?> _resolvedCoachDisplayName() async {
    final localName =
        (await ref.read(preferencesRepositoryProvider).get('displayName'))
            ?.trim();
    if (localName?.isNotEmpty == true) return localName;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final metadata = user?.userMetadata;
      final emailLocalPart = user?.email?.trim().split('@').first.toLowerCase();
      for (final key in const ['display_name', 'full_name', 'name']) {
        final value = metadata?[key]?.toString().trim();
        if (value?.isNotEmpty == true &&
            !value!.contains('@') &&
            value.toLowerCase() != emailLocalPart) {
          return value;
        }
      }
    } on Object {
      // A greeting never depends on cloud availability.
    }
    return null;
  }

  Future<BilCoachVoiceGender> _preferredCoachVoice() async {
    // BIL Coach has one consistent character identity. His voice follows the
    // male captain shown in the hero and reply avatar; it is not derived from
    // the user's profile gender.
    return BilCoachVoiceGender.male;
  }

  Future<void> _speakCoachText(
    String text,
    String locale, {
    bool showFailure = false,
  }) async {
    try {
      await const BilTextToSpeech().speak(
        text,
        locale,
        voiceGender: await _preferredCoachVoice(),
      );
    } on Object {
      if (!showFailure || !mounted) return;
      _showActionCompleted(
        tr(
          'A coach voice for this language is unavailable on this device.',
          'صوت المدرب لهذه اللغة غير متاح على هذا الجهاز.',
        ),
      );
    }
  }

  void _scrollToLatest({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !conversationScroll.hasClients) return;
      // The chat is rendered in reverse, so offset zero is always the newest
      // turn regardless of how tall or lazily built the restored history is.
      final target = conversationScroll.position.minScrollExtent;
      if (jump) {
        conversationScroll.jumpTo(target);
      } else {
        conversationScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _saveConversation() async {
    try {
      final contextRevision = await _coachContextRevision();
      final persistentMessages = messages.where(
        (message) => !message.id.startsWith('welcome'),
      );
      final preferences = ref.read(preferencesRepositoryProvider);
      await preferences.set(
        'intelligenceConversationV1',
        jsonEncode(persistentMessages.map((item) => item.toJson()).toList()),
      );
      await preferences.set(
        'intelligenceConversationContextV1',
        contextRevision.fingerprint,
      );
    } on Object {
      // Conversation persistence is best-effort. A local storage failure must
      // not escape an unawaited save and terminate an otherwise valid reply.
    }
  }

  Future<void> _clearConversation() async {
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .remove('intelligenceConversationV1');
      await ref
          .read(preferencesRepositoryProvider)
          .remove('intelligenceConversationContextV1');
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'The local conversation could not be cleared. Your data was unchanged.',
              'تعذر مسح المحادثة المحلية. لم تتغير بياناتك.',
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    final displayName = await _resolvedCoachDisplayName();
    if (!mounted) return;
    final now = ref.read(intelligenceConversationClockProvider)();
    final welcome = _sessionWelcome(displayName, at: now);
    _updateState(() {
      messages
        ..clear()
        ..add(
          IntelligenceMessage(
            id: 'welcome-${now.microsecondsSinceEpoch}',
            role: IntelligenceMessageRole.bil,
            kind: IntelligenceMessageKind.coach,
            text: welcome,
            createdAt: now,
            modality: IntelligenceMessageModality.system,
          ),
        );
    });
    unawaited(_saveConversation());
  }

  Future<void> _toggleDictation() async {
    if (sending || voiceMode == _CoachVoiceMode.liveCall) return;
    if (listening) {
      await _submitVoiceTranscript();
      return;
    }
    voiceMode = _CoachVoiceMode.dictation;
    liveCallPaused = false;
    await _startVoiceCapture();
  }

  Future<void> _toggleLiveCall() async {
    if (voiceMode == _CoachVoiceMode.liveCall) {
      if (liveCallPaused) {
        liveCallPaused = false;
        if (mounted) _updateState(() {});
        await _startVoiceCapture();
      } else {
        await _pauseLiveCall();
      }
      return;
    }
    if (sending) return;
    voiceMode = _CoachVoiceMode.liveCall;
    liveCallPaused = false;
    await _startVoiceCapture();
  }

  Future<void> _pauseLiveCall() async {
    liveCallPaused = true;
    voiceSilenceTimer?.cancel();
    await _stopVoiceCapture(resetMode: false);
    try {
      await const BilTextToSpeech().stop();
    } on Object {
      // The call still pauses if a device has no active TTS engine.
    }
    if (mounted) _updateState(() {});
  }

  Future<void> _stopLiveCall() async {
    liveCallPaused = false;
    requestGeneration += 1;
    replyDelayTimer?.cancel();
    await _stopVoiceCapture(resetMode: true);
    try {
      await const BilTextToSpeech().stop();
    } on Object {
      // Ending the call never depends on a working TTS engine.
    }
    if (mounted) {
      _updateState(() {
        sending = false;
        replyPhase = _CoachReplyPhase.idle;
        failedRequest = null;
      });
    }
  }

  Future<void> _startVoiceCapture() async {
    final permissionGranted = await _ensureCoachRuntimePermission(
      BilRuntimeCapability.microphone,
      includeSpeechRecognition: true,
    );
    if (!permissionGranted || !mounted) {
      if (mounted) {
        _updateState(() {
          if (voiceMode == _CoachVoiceMode.liveCall) {
            liveCallPaused = true;
          } else {
            voiceMode = _CoachVoiceMode.idle;
          }
        });
      }
      return;
    }
    _updateState(() => introVisible = false);
    unawaited(_playVoiceActivationCue());
    // Both microphones use the OS recognizer. Only its resulting text can
    // cross the AI boundary; raw microphone bytes never enter a model request.
    if (await _startNativeVoiceCapture()) return;
    if (mounted) _showVoiceUnavailable();
  }

  Future<void> _playVoiceActivationCue() async {
    try {
      await HapticFeedback.lightImpact();
      await SystemSound.play(SystemSoundType.click);
    } on Object {
      // Voice starts even on devices that do not expose a system cue channel.
    }
  }

  Future<bool> _startNativeVoiceCapture() async {
    voiceSilenceTimer?.cancel();
    voiceLanguageHint = null;
    voiceSubmitPending = false;
    pendingVoiceTranscript = '';
    question.clear();
    try {
      final available = await speech.initialize(
        onError: (error) => unawaited(_handleVoiceFailure(error)),
      );
      if (!available || !mounted) {
        return false;
      }
      // Speech language is deliberately independent from the BIL interface.
      // Supplying the UI locale here makes Android lock recognition to that
      // language before its language-switch model gets a chance to run.
      if (!mounted) return false;
      _updateState(() {
        listening = true;
      });
      await speech.listen(
        onResult: (result) {
          if (!mounted || voiceSubmitPending) return;
          final transcript = result.recognizedWords.trim();
          if (transcript.isEmpty) return;
          if (result.localeId?.trim().isNotEmpty == true) {
            voiceLanguageHint = result.localeId!.trim();
          }
          pendingVoiceTranscript = transcript;
          _updateState(() {
            listening = true;
            question.value = TextEditingValue(
              text: transcript,
              selection: TextSelection.collapsed(offset: transcript.length),
            );
          });
          _scrollToLatest();
          voiceSilenceTimer?.cancel();
          voiceSilenceTimer = Timer(
            result.isFinal
                ? const Duration(milliseconds: 900)
                : const Duration(seconds: 2),
            () => unawaited(_submitVoiceTranscript()),
          );
        },
        listenOptions: SpeechListenOptions(
          localeId: null,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 2),
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: true,
          // Android 14+ detects and switches the recognition model to the
          // language being spoken, independently from the BIL interface.
          autoDetectLanguage: true,
          // Do not restrict speech to the 25 interface locales. Android may
          // report any supported BCP-47 language for this conversation.
          allowedLocaleIds: const <String>[],
        ),
      );
      return true;
    } on Object {
      try {
        await speech.cancel();
      } on Object {
        // The inline composer remains available as a fallback.
      }
      if (mounted) {
        _updateState(() {
          listening = false;
        });
      }
      return false;
    }
  }

  Future<void> _submitVoiceTranscript() async {
    if (voiceSubmitPending) return;
    final transcript = pendingVoiceTranscript.trim();
    if (transcript.isEmpty) {
      await _stopVoiceCapture();
      return;
    }
    voiceSubmitPending = true;
    voiceSilenceTimer?.cancel();
    final detectedLanguageTag = voiceLanguageHint;
    question.clear();
    try {
      await speech.stop();
    } on Object {
      // The recognized text is already in the composer and remains usable.
    }
    if (mounted) _updateState(() => listening = false);
    final autoSpeakReply = _IntelligenceCenterPageState._voiceTurnPolicy
        .planFor(
          voiceMode == _CoachVoiceMode.liveCall
              ? CoachVoiceEntryPoint.liveCall
              : CoachVoiceEntryPoint.composerDictation,
        )
        .autoSpeakReply;
    await ask(
      inputChannel: CoachInputChannel.voice,
      detectedLanguageTag: detectedLanguageTag,
      textOverride: transcript,
      autoSpeakReply: autoSpeakReply,
    );
    voiceLanguageHint = null;
    pendingVoiceTranscript = '';
    question.clear();
    voiceSubmitPending = false;
    if (!autoSpeakReply && voiceMode == _CoachVoiceMode.dictation) {
      voiceMode = _CoachVoiceMode.idle;
      if (mounted) _updateState(() {});
    }
  }

  Future<void> _resumeLiveCallIfNeeded(int generation) async {
    if (!mounted ||
        generation != requestGeneration ||
        voiceMode != _CoachVoiceMode.liveCall ||
        liveCallPaused ||
        listening ||
        sending) {
      return;
    }
    await _startVoiceCapture();
  }

  Future<void> _stopVoiceCapture({bool resetMode = false}) async {
    voiceSilenceTimer?.cancel();
    try {
      await speech.cancel();
    } on Object {
      // The inline composer remains available even if native cancellation fails.
    }
    if (mounted) {
      _updateState(() {
        listening = false;
        if (resetMode) voiceMode = _CoachVoiceMode.idle;
      });
    }
  }

  Future<void> _handleVoiceFailure([SpeechRecognitionError? error]) async {
    if (!mounted) return;
    if (pendingVoiceTranscript.trim().isNotEmpty) {
      await _submitVoiceTranscript();
      return;
    }
    await _stopVoiceCapture();
    if (!mounted) return;
    if (voiceMode == _CoachVoiceMode.liveCall) {
      _updateState(() => liveCallPaused = true);
    }
    if (error?.errorMsg case 'speech_timeout' || 'speech_no_match') {
      _showActionCompleted(
        tr(
          'I didn’t catch that. Tap the microphone and try again.',
          'لم ألتقط كلامًا واضحًا. اضغط الميكروفون وحاول مرة أخرى.',
        ),
      );
      return;
    }
    _showVoiceUnavailable();
  }

  void _showVoiceUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'Voice input is unavailable right now. You can type and send your question.',
            'تعذر تشغيل الإدخال الصوتي الآن. يمكنك كتابة سؤالك وإرساله.',
          ),
        ),
      ),
    );
  }
}
