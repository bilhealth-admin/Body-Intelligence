part of 'intelligence_center_page.dart';

@visibleForTesting
List<BilRuntimeCapability> coachRuntimePermissionSequence({
  required BilRuntimeCapability capability,
  required bool includeSpeechRecognition,
  required TargetPlatform platform,
}) =>
    capability == BilRuntimeCapability.microphone &&
        includeSpeechRecognition &&
        platform == TargetPlatform.iOS
    ? const [
        BilRuntimeCapability.microphone,
        BilRuntimeCapability.speechRecognition,
      ]
    : [capability];

@visibleForTesting
({
  String englishName,
  String arabicName,
  String englishRationale,
  String arabicRationale,
})
coachRuntimePermissionPresentation(
  BilRuntimeCapability capability,
) => switch (capability) {
  BilRuntimeCapability.camera => (
    englishName: 'camera',
    arabicName: 'الكاميرا',
    englishRationale:
        'BIL opens the camera only for the food photo you selected and never at startup.',
    arabicRationale:
        'يفتح BIL الكاميرا فقط لصورة الطعام التي اخترتها وليس عند بدء التطبيق.',
  ),
  BilRuntimeCapability.microphone => (
    englishName: 'microphone',
    arabicName: 'الميكروفون',
    englishRationale:
        'BIL uses speech recognition only after you start voice input. Recognized text is sent after you pause.',
    arabicRationale:
        'يستخدم BIL التعرف على الكلام فقط بعد بدء الإدخال الصوتي. يُرسل النص المتعرف عليه بعد أن تتوقف عن الكلام.',
  ),
  BilRuntimeCapability.speechRecognition => (
    englishName: 'speech recognition',
    arabicName: 'التعرف على الكلام',
    englishRationale:
        'BIL uses speech recognition only after you start voice input. Recognized text is sent after you pause.',
    arabicRationale:
        'يستخدم BIL التعرف على الكلام فقط بعد بدء الإدخال الصوتي. يُرسل النص المتعرف عليه بعد أن تتوقف عن الكلام.',
  ),
  BilRuntimeCapability.notifications => (
    englishName: 'notifications',
    arabicName: 'الإشعارات',
    englishRationale:
        'BIL asks for notifications only when you choose to receive timely updates.',
    arabicRationale:
        'يطلب BIL إذن الإشعارات فقط عندما تختار تلقي التحديثات في وقتها.',
  ),
};

extension _IntelligenceConversationVoice on _IntelligenceCenterPageState {
  Future<bool> _ensureCoachRuntimePermission(
    BilRuntimeCapability capability, {
    bool includeSpeechRecognition = false,
  }) async {
    if (!mounted || coachInBackground) return false;
    const policy = BilRuntimePermissionPolicy();
    final permissionSequence = coachRuntimePermissionSequence(
      capability: capability,
      includeSpeechRecognition: includeSpeechRecognition,
      platform: defaultTargetPlatform,
    );
    var effectiveCapability = permissionSequence.first;
    var current = await policy.status(effectiveCapability);
    if (permissionSequence.length > 1 &&
        current == BilRuntimePermissionState.granted &&
        effectiveCapability == BilRuntimeCapability.microphone) {
      effectiveCapability = permissionSequence.last;
      current = await policy.status(effectiveCapability);
    }
    if (current == BilRuntimePermissionState.granted) return true;
    if (!mounted) return false;
    final presentation = coachRuntimePermissionPresentation(
      effectiveCapability,
    );
    final permissionTitle = switch (effectiveCapability) {
      BilRuntimeCapability.microphone => MealVoiceRuntimeCopy.resolve(
        MealVoiceCopyKey.microphonePermissionTitle,
        BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      ),
      BilRuntimeCapability.speechRecognition => MealVoiceRuntimeCopy.resolve(
        MealVoiceCopyKey.speechPermissionTitle,
        BilLocalePolicy.canonicalTag(Localizations.localeOf(context)),
      ),
      BilRuntimeCapability.camera => tr(
        'Allow camera for this action?',
        'السماح بالكاميرا لهذا الإجراء؟',
      ),
      BilRuntimeCapability.notifications => tr('Notifications', 'الإشعارات'),
    };
    if (current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog.adaptive(
          title: Text(permissionTitle),
          content: Text(
            tr(
              'This permission is off. Enable it in system settings to use this feature; typing remains available.',
              'هذا الإذن متوقف. فعّله في إعدادات النظام لاستخدام هذه الميزة؛ وتبقى الكتابة متاحة.',
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
      builder: (dialogContext) => AlertDialog.adaptive(
        title: Text(permissionTitle),
        content: Text(
          tr(presentation.englishRationale, presentation.arabicRationale),
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
    if (continueRequest != true || !mounted || coachInBackground) return false;
    final granted =
        await policy.request(effectiveCapability) ==
        BilRuntimePermissionState.granted;
    if (!granted) return false;
    if (effectiveCapability != BilRuntimeCapability.microphone ||
        permissionSequence.length == 1) {
      return true;
    }
    return _ensureCoachRuntimePermission(
      capability,
      includeSpeechRecognition: includeSpeechRecognition,
    );
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
    if (!mounted || coachInBackground || (!showFailure && liveCallPaused)) {
      return;
    }
    try {
      final voiceGender = await _preferredCoachVoice();
      if (!mounted || coachInBackground || (!showFailure && liveCallPaused)) {
        return;
      }
      await const BilTextToSpeech().speak(
        text,
        locale,
        voiceGender: voiceGender,
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

  Future<void> _toggleDictation() async {
    if (!mounted ||
        !conversationReady ||
        coachInBackground ||
        voiceCaptureStarting ||
        sending ||
        voiceMode == _CoachVoiceMode.liveCall) {
      return;
    }
    if (listening) {
      await _submitVoiceTranscript();
      return;
    }
    voiceMode = _CoachVoiceMode.dictation;
    liveCallPaused = false;
    voiceTransientRestarts = 0;
    await _startVoiceCapture();
  }

  Future<void> _toggleLiveCall() async {
    if (!mounted || !conversationReady || coachInBackground) return;
    if (voiceMode == _CoachVoiceMode.liveCall) {
      if (liveCallPaused) {
        liveCallPaused = false;
        liveCallNoSpeechRestarts = 0;
        voiceTransientRestarts = 0;
        if (mounted) _updateState(() {});
        await _startVoiceCapture(playCue: true);
      } else {
        await _pauseLiveCall();
      }
      return;
    }
    if (sending) return;
    voiceMode = _CoachVoiceMode.liveCall;
    liveCallPaused = false;
    liveCallNoSpeechRestarts = 0;
    voiceTransientRestarts = 0;
    await _startVoiceCapture(playCue: true);
  }

  Future<void> _pauseLiveCall() async {
    liveCallPaused = true;
    voiceSilenceTimer?.cancel();
    await _stopVoiceCapture(resetMode: false);
    await _playVoiceDeactivationCue();
    try {
      await const BilTextToSpeech().stop();
    } on Object {
      // The call still pauses if a device has no active TTS engine.
    }
    if (mounted) _updateState(() {});
  }

  Future<void> _stopLiveCall() async {
    liveCallPaused = false;
    liveCallNoSpeechRestarts = 0;
    requestGeneration += 1;
    replyDelayTimer?.cancel();
    await _stopVoiceCapture(resetMode: true);
    await _playVoiceDeactivationCue();
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

  Future<void> _startVoiceCapture({bool playCue = true}) async {
    if (!_canCaptureVoice || voiceCaptureStarting) return;
    voiceCaptureStarting = true;
    final generation = ++voiceCaptureGeneration;
    try {
      await _prepareVoiceCapture(generation, playCue: playCue);
    } on Object {
      if (_canCaptureVoice && generation == voiceCaptureGeneration) {
        _showVoiceUnavailable();
      }
    } finally {
      voiceCaptureStarting = false;
    }
  }

  bool get _canCaptureVoice =>
      mounted &&
      !coachInBackground &&
      voiceMode != _CoachVoiceMode.idle &&
      !(voiceMode == _CoachVoiceMode.liveCall && liveCallPaused);

  Future<void> _prepareVoiceCapture(
    int generation, {
    required bool playCue,
  }) async {
    final permissionGranted = await _ensureCoachRuntimePermission(
      BilRuntimeCapability.microphone,
      includeSpeechRecognition: true,
    );
    if (generation != voiceCaptureGeneration || !_canCaptureVoice) return;
    if (!permissionGranted) {
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
    if (playCue) await _playVoiceActivationCue();
    if (generation != voiceCaptureGeneration || !_canCaptureVoice) return;
    // Both microphones use the OS recognizer. Only its resulting text can
    // cross the AI boundary; raw microphone bytes never enter a model request.
    if (await _startNativeVoiceCapture(generation)) return;
    if (_canCaptureVoice && generation == voiceCaptureGeneration) {
      _showVoiceUnavailable();
    }
  }

  Future<void> _playVoiceActivationCue() async {
    try {
      await HapticFeedback.lightImpact();
      await BilMicSound.playOpen();
    } on Object {
      try {
        await SystemSound.play(SystemSoundType.click);
      } on Object {
        // Voice starts even on devices that do not expose a sound channel.
      }
    }
  }

  Future<void> _playVoiceDeactivationCue() async {
    try {
      await HapticFeedback.selectionClick();
      await BilMicSound.playEnd();
    } on Object {
      try {
        await SystemSound.play(SystemSoundType.click);
      } on Object {
        // Ending voice never depends on a sound or haptics channel.
      }
    }
  }

  Future<bool> _startNativeVoiceCapture(int generation) async {
    voiceSilenceTimer?.cancel();
    voiceLanguageHint = null;
    voiceSubmitPending = false;
    pendingVoiceTranscript = '';
    final initialDraft = question.value;
    try {
      final available = await speech.initialize(
        onError: (error) {
          if (_canCaptureVoice && generation == voiceCaptureGeneration) {
            unawaited(_handleVoiceFailure(error));
          }
        },
      );
      if (!available ||
          !_canCaptureVoice ||
          generation != voiceCaptureGeneration) {
        return false;
      }
      // Speech language is deliberately independent from the BIL interface.
      // Supplying the UI locale here makes Android lock recognition to that
      // language before its language-switch model gets a chance to run.
      if (!mounted) return false;
      final speechLocaleAllowList = await _coachSpeechLocaleAllowList();
      if (!_canCaptureVoice || generation != voiceCaptureGeneration) {
        return false;
      }
      _updateState(() {
        listening = true;
      });
      await speech.listen(
        onResult: (result) {
          if (!_canCaptureVoice ||
              generation != voiceCaptureGeneration ||
              voiceSubmitPending) {
            return;
          }
          final transcript = result.recognizedWords.trim();
          if (transcript.isEmpty) return;
          if (result.localeId?.trim().isNotEmpty == true) {
            voiceLanguageHint = result.localeId!.trim();
          }
          pendingVoiceTranscript = transcript;
          liveCallNoSpeechRestarts = 0;
          voiceTransientRestarts = 0;
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
                // Match the native recognizer's silence window. A shorter
                // Dart timer submitted the first partial phrase while the
                // user was still speaking, especially on Android devices
                // that emit a partial result immediately after route setup.
                : const Duration(milliseconds: 3500),
            () => unawaited(_submitVoiceTranscript()),
          );
        },
        listenOptions: SpeechListenOptions(
          localeId: null,
          listenFor: const Duration(seconds: 45),
          // Give Android's recognizer time to open its audio route and let a
          // user begin speaking. Two seconds was short enough to produce an
          // immediate timeout on slower OEM speech services.
          pauseFor: const Duration(milliseconds: 3500),
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: true,
          // Android 14+ detects and switches the recognition model to the
          // language being spoken, independently from the BIL interface.
          autoDetectLanguage: true,
          // Restrict Android's language switcher to the BIL release languages
          // that the platform actually exposes. This is a speech allow-list,
          // not the interface locale, and it is empty only when the platform
          // gives us no locale inventory to filter safely.
          allowedLocaleIds: speechLocaleAllowList,
        ),
      );
      if (!_canCaptureVoice || generation != voiceCaptureGeneration) {
        await speech.cancel();
        return false;
      }
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
          if (question.text.isEmpty) question.value = initialDraft;
        });
      }
      return false;
    }
  }

  Future<List<String>> _coachSpeechLocaleAllowList() async {
    try {
      final available = (await speech.locales())
          .map((locale) => locale.localeId.trim())
          .where((locale) => locale.isNotEmpty)
          .toList(growable: false);
      return _matchCoachSpeechLocales(available);
    } on Object {
      // Recognition remains usable on platforms with an empty/unavailable
      // locale inventory; the native bridge will use its normal fallback.
      return const <String>[];
    }
  }

  Future<void> _submitVoiceTranscript() async {
    if (!mounted || coachInBackground || voiceSubmitPending) return;
    final transcript = pendingVoiceTranscript.trim();
    if (transcript.isEmpty) {
      await _stopVoiceCapture();
      if (voiceMode == _CoachVoiceMode.dictation) {
        await _playVoiceDeactivationCue();
      }
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
    if (!mounted || coachInBackground) {
      voiceSubmitPending = false;
      return;
    }
    if (voiceMode == _CoachVoiceMode.dictation) {
      await _playVoiceDeactivationCue();
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
    if (!mounted) return;
    voiceLanguageHint = null;
    pendingVoiceTranscript = '';
    // A user may already be typing the next turn while the answer arrives.
    // Do not erase that new draft when this voice request finishes.
    voiceSubmitPending = false;
    if (!autoSpeakReply && voiceMode == _CoachVoiceMode.dictation) {
      voiceMode = _CoachVoiceMode.idle;
      if (mounted) _updateState(() {});
    }
  }

  Future<void> _resumeLiveCallIfNeeded(int generation) async {
    if (!mounted ||
        coachInBackground ||
        generation != requestGeneration ||
        voiceMode != _CoachVoiceMode.liveCall ||
        liveCallPaused ||
        listening ||
        sending) {
      return;
    }
    if (question.text.trim().isNotEmpty) {
      _updateState(() => liveCallPaused = true);
      return;
    }
    await _startVoiceCapture(playCue: false);
  }

  Future<void> _stopVoiceCapture({bool resetMode = false}) async {
    voiceCaptureGeneration++;
    voiceSilenceTimer?.cancel();
    if (mounted) {
      _updateState(() {
        listening = false;
        if (resetMode) voiceMode = _CoachVoiceMode.idle;
      });
    }
    try {
      await speech.cancel();
    } on Object {
      // The inline composer remains available even if native cancellation fails.
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
    final errorCode = error?.errorMsg;
    final transient =
        errorCode == 'recognizer_error_5' ||
        errorCode == 'speech_recognizer_busy' ||
        errorCode == 'speech_start_failed' ||
        errorCode == 'audio_input_unavailable' ||
        errorCode == 'audio_session_unavailable';
    if (transient &&
        !sending &&
        voiceMode != _CoachVoiceMode.idle &&
        voiceTransientRestarts < 1) {
      // Android speech services can return ERROR_CLIENT while the audio
      // route is still being released. Recreate the recognizer once so the
      // user's first deliberate tap does not look like an immediate stop.
      voiceTransientRestarts += 1;
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted && !sending && voiceMode != _CoachVoiceMode.idle) {
        await _startVoiceCapture(playCue: false);
      }
      return;
    }
    if (errorCode case 'speech_timeout' || 'speech_no_match') {
      // A live call should keep its listening session alive when the OS
      // recognizer times out before any words arrive. Retry a couple of times
      // silently; only then pause and show an actionable message. Dictation
      // remains a deliberate one-shot action and keeps the existing prompt.
      if (voiceMode == _CoachVoiceMode.liveCall &&
          !liveCallPaused &&
          !sending &&
          liveCallNoSpeechRestarts < 2) {
        liveCallNoSpeechRestarts += 1;
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (mounted &&
            voiceMode == _CoachVoiceMode.liveCall &&
            !liveCallPaused &&
            !sending) {
          await _startVoiceCapture(playCue: false);
        }
        return;
      }
      if (voiceMode == _CoachVoiceMode.liveCall) {
        _updateState(() => liveCallPaused = true);
      }
      await _playVoiceDeactivationCue();
      _showActionCompleted(
        tr(
          voiceMode == _CoachVoiceMode.liveCall
              ? 'I did not hear a clear sentence. Tap the call icon to listen again.'
              : 'I didn’t catch that. Tap the microphone and try again.',
          voiceMode == _CoachVoiceMode.liveCall
              ? 'لم أسمع جملة واضحة. اضغط أيقونة المكالمة للاستماع مجددًا.'
              : 'لم ألتقط كلامًا واضحًا. اضغط الميكروفون وحاول مرة أخرى.',
        ),
      );
      return;
    }
    if (voiceMode == _CoachVoiceMode.liveCall) {
      _updateState(() => liveCallPaused = true);
    }
    _showVoiceUnavailable();
  }

  void _showVoiceUnavailable() {
    if (!mounted) return;
    _updateState(() {
      listening = false;
      if (voiceMode == _CoachVoiceMode.liveCall) liveCallPaused = true;
    });
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

List<String> _matchCoachSpeechLocales(List<String> available) {
  final candidates = available
      .map((value) => value.replaceAll('_', '-'))
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (candidates.isEmpty) return const <String>[];
  final orderedCandidates = candidates.toList()..sort();
  final orderedTargets = BilLocalePolicy.productionTags.toList()..sort();
  final selected = <String>[];
  for (final target in orderedTargets) {
    final normalizedTarget = target.toLowerCase();
    String? match;
    for (final candidate in orderedCandidates) {
      if (candidate.toLowerCase() == normalizedTarget) {
        match = candidate;
        break;
      }
    }
    if (match == null) {
      final language = normalizedTarget.split('-').first;
      final languageMatches = orderedCandidates.where(
        (candidate) => candidate.toLowerCase().split('-').first == language,
      );
      final preferredVariant = switch (normalizedTarget) {
        'zh-hans' =>
          (String value) =>
              value.endsWith('-cn') ||
              value.endsWith('-sg') ||
              value.endsWith('-hans'),
        'zh-hant' =>
          (String value) =>
              value.endsWith('-tw') ||
              value.endsWith('-hk') ||
              value.endsWith('-mo') ||
              value.endsWith('-hant'),
        'pt-br' => (String value) => value.endsWith('-br'),
        'pt-pt' => (String value) => value.endsWith('-pt'),
        _ => (String value) => false,
      };
      for (final candidate in languageMatches) {
        if (preferredVariant(candidate.toLowerCase())) {
          match = candidate;
          break;
        }
      }
      match ??= languageMatches.isEmpty ? null : languageMatches.first;
    }
    if (match != null && !selected.contains(match)) selected.add(match);
  }
  return selected;
}
