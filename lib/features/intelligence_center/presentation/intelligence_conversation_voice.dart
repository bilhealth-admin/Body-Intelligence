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
    bool Function()? isCurrent,
  }) async {
    bool currentRequest() {
      if (!mounted || coachInBackground) return false;
      try {
        return isCurrent?.call() ?? true;
      } on Object {
        return false;
      }
    }

    if (!currentRequest()) return false;
    const policy = BilRuntimePermissionPolicy();
    final permissionSequence = coachRuntimePermissionSequence(
      capability: capability,
      includeSpeechRecognition: includeSpeechRecognition,
      platform: defaultTargetPlatform,
    );
    var effectiveCapability = permissionSequence.first;
    var current = await policy.status(effectiveCapability);
    if (!currentRequest()) return false;
    if (permissionSequence.length > 1 &&
        current == BilRuntimePermissionState.granted &&
        effectiveCapability == BilRuntimeCapability.microphone) {
      effectiveCapability = permissionSequence.last;
      current = await policy.status(effectiveCapability);
      if (!currentRequest()) return false;
    }
    if (current == BilRuntimePermissionState.granted) return true;
    if (!mounted || !currentRequest()) return false;
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
        'Camera access is off',
        'الوصول إلى الكاميرا متوقف',
      ),
      BilRuntimeCapability.notifications => tr('Notifications', 'الإشعارات'),
    };
    if (current == BilRuntimePermissionState.permanentlyDenied ||
        current == BilRuntimePermissionState.restricted) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await policy.openSettings();
        return false;
      }
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
      if (!currentRequest()) return false;
      if (open == true) await policy.openSettings();
      return false;
    }
    if (!currentRequest()) return false;
    final granted =
        await policy.request(effectiveCapability) ==
        BilRuntimePermissionState.granted;
    if (!currentRequest() || !granted) return false;
    if (effectiveCapability != BilRuntimeCapability.microphone ||
        permissionSequence.length == 1) {
      return true;
    }
    return _ensureCoachRuntimePermission(
      capability,
      includeSpeechRecognition: includeSpeechRecognition,
      isCurrent: isCurrent,
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
    if (!_voiceRouteIsCurrent || (!showFailure && liveCallPaused)) {
      return;
    }
    try {
      final voiceGender = await _preferredCoachVoice();
      if (!_voiceRouteIsCurrent || (!showFailure && liveCallPaused)) {
        return;
      }
      await const BilTextToSpeech().speak(
        text,
        locale,
        voiceGender: voiceGender,
      );
    } on Object {
      if (!showFailure || !_voiceRouteIsCurrent) return;
      _showActionCompleted(
        tr(
          'A coach voice for this language is unavailable on this device.',
          'صوت المدرب لهذه اللغة غير متاح على هذا الجهاز.',
        ),
      );
    }
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
    final epoch = conversationPersistenceEpoch;
    final queryGeneration = requestGeneration;
    final stop = _stopVoiceCapture(resetMode: false);
    final captureGeneration = voiceCaptureGeneration;
    bool current() =>
        mounted &&
        !coachInBackground &&
        conversationPersistenceEpoch == epoch &&
        requestGeneration == queryGeneration &&
        voiceCaptureGeneration == captureGeneration;
    await stop;
    if (!current()) return;
    await _playVoiceDeactivationCue(isCurrent: current);
    if (!current()) return;
    try {
      await const BilTextToSpeech().stop();
    } on Object {
      // The call still pauses if a device has no active TTS engine.
    }
    if (current()) _updateState(() {});
  }

  Future<void> _stopLiveCall() async {
    liveCallPaused = false;
    liveCallNoSpeechRestarts = 0;
    requestGeneration += 1;
    replyDelayTimer?.cancel();
    final epoch = conversationPersistenceEpoch;
    final queryGeneration = requestGeneration;
    final stop = _stopVoiceCapture(resetMode: true);
    final captureGeneration = voiceCaptureGeneration;
    bool current() =>
        mounted &&
        !coachInBackground &&
        conversationPersistenceEpoch == epoch &&
        requestGeneration == queryGeneration &&
        voiceCaptureGeneration == captureGeneration;
    await stop;
    if (!current()) return;
    await _playVoiceDeactivationCue(isCurrent: current);
    if (!current()) return;
    try {
      await const BilTextToSpeech().stop();
    } on Object {
      // Ending the call never depends on a working TTS engine.
    }
    if (current()) {
      _updateState(() {
        sending = false;
        replyPhase = _CoachReplyPhase.idle;
        failedRequest = null;
      });
    }
  }

  Future<void> _startVoiceCapture({bool playCue = true}) async {
    if (!_canCaptureVoice || voiceCaptureStarting || sending) return;
    final previous = voiceMediaRequest;
    if (previous != null) {
      _finishVoiceMediaRequest(previous, pauseLiveCall: false);
    }
    final generation = ++voiceCaptureGeneration;
    voiceCaptureStarting = true;
    _CoachMediaPageRequest? request;
    try {
      // Capture the owner and request before the first permission/platform
      // await. A later callback must never obtain a new owner scope.
      final captured = _newCoachMediaRequest();
      request = captured;
      voiceMediaRequest = captured;
      if (!voiceTranscriptBridge.begin(captured.attempt)) return;
      voiceSilenceTimer?.cancel();
      voiceLanguageHint = null;
      pendingVoiceTranscript = '';
      voiceSubmitPending = false;
      var writingTranscript = false;
      var userEdited = false;
      var lastComposerText = question.text;

      void composerChanged() {
        final text = question.text;
        if (text == lastComposerText) return;
        lastComposerText = text;
        if (writingTranscript ||
            voiceSubmitPending ||
            !_voiceRequestCurrent(captured, generation)) {
          return;
        }
        userEdited = true;
        if (!voiceTranscriptBridge.updateDraft(captured.attempt, text)) return;
        pendingVoiceTranscript = text;
        voiceSilenceTimer?.cancel();
        if (!voiceCaptureStarting) {
          unawaited(_finishVoiceTranscriptForReview(captured, generation));
        }
      }

      question.addListener(composerChanged);
      captured.releaseVoiceDraftListener = () =>
          question.removeListener(composerChanged);
      void writeTranscript(String text) {
        writingTranscript = true;
        try {
          question.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          lastComposerText = text;
        } finally {
          writingTranscript = false;
        }
      }

      await _prepareVoiceCapture(
        captured,
        generation,
        playCue: playCue,
        writeTranscript: writeTranscript,
        hasUserEdited: () => userEdited,
      );
    } on Object {
      if (request != null && _voiceRequestCurrent(request, generation)) {
        _showVoiceUnavailable();
        request.attempt.cancel();
      }
    } finally {
      if (request == null && generation == voiceCaptureGeneration) {
        voiceCaptureStarting = false;
      } else if (request != null && identical(voiceMediaRequest, request)) {
        voiceCaptureStarting = false;
        if (generation != voiceCaptureGeneration ||
            !request.attempt.isCurrent) {
          _finishVoiceMediaRequest(request);
        }
      }
    }
  }

  bool get _voiceRouteIsCurrent {
    if (!mounted || coachInBackground) return false;
    try {
      // An outgoing route remains mounted throughout its transition. Its old
      // reply must not speak or open another recognizer before dispose runs.
      return ModalRoute.of(context)?.isCurrent == true;
    } on Object {
      // The element can already be deactivated while native work completes.
      return false;
    }
  }

  bool get _canCaptureVoice =>
      _voiceRouteIsCurrent &&
      voiceMode != _CoachVoiceMode.idle &&
      !(voiceMode == _CoachVoiceMode.liveCall && liveCallPaused);

  Future<void> _prepareVoiceCapture(
    _CoachMediaPageRequest request,
    int generation, {
    required bool playCue,
    required void Function(String) writeTranscript,
    required bool Function() hasUserEdited,
  }) async {
    final permissionGranted = await _ensureCoachRuntimePermission(
      BilRuntimeCapability.microphone,
      includeSpeechRecognition: true,
      isCurrent: () => _voiceRequestCurrent(request, generation),
    );
    if (!_voiceRequestCurrent(request, generation)) return;
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
      request.attempt.cancel();
      return;
    }
    request.capabilities.addAll(
      coachRuntimePermissionSequence(
        capability: BilRuntimeCapability.microphone,
        includeSpeechRecognition: true,
        platform: defaultTargetPlatform,
      ),
    );
    if (!await _voiceRequestAllowed(request, generation)) return;
    if (hasUserEdited()) {
      await _finishVoiceTranscriptForReview(request, generation);
      return;
    }
    if (!_canCaptureVoice) return;
    _updateState(() => introVisible = false);
    if (playCue) {
      await _playVoiceActivationCue(
        isCurrent: () => _voiceRequestCurrent(request, generation),
      );
      if (!await _voiceRequestAllowed(request, generation)) return;
    }
    if (!_canCaptureVoice || hasUserEdited()) {
      if (hasUserEdited()) {
        await _finishVoiceTranscriptForReview(request, generation);
      }
      return;
    }
    // Both microphones use the OS recognizer. Only its resulting text can
    // cross the AI boundary; raw microphone bytes never enter a model request.
    if (await _startNativeVoiceCapture(
      request,
      generation,
      writeTranscript: writeTranscript,
      hasUserEdited: hasUserEdited,
    )) {
      return;
    }
    if (_voiceRequestCurrent(request, generation) && _canCaptureVoice) {
      _showVoiceUnavailable();
      request.attempt.cancel();
    }
  }

  Future<void> _playVoiceActivationCue({bool Function()? isCurrent}) async {
    bool current() =>
        mounted && !coachInBackground && (isCurrent?.call() ?? true);
    if (!current()) return;
    try {
      await HapticFeedback.lightImpact();
      if (!current()) return;
      await BilMicSound.playOpen();
    } on Object {
      if (!current()) return;
      try {
        await SystemSound.play(SystemSoundType.click);
      } on Object {
        // Voice starts even on devices that do not expose a sound channel.
      }
    }
  }

  Future<void> _playVoiceDeactivationCue({bool Function()? isCurrent}) async {
    bool current() =>
        mounted && !coachInBackground && (isCurrent?.call() ?? true);
    if (!current()) return;
    try {
      await HapticFeedback.selectionClick();
      if (!current()) return;
      await BilMicSound.playEnd();
    } on Object {
      if (!current()) return;
      try {
        await SystemSound.play(SystemSoundType.click);
      } on Object {
        // Ending voice never depends on a sound or haptics channel.
      }
    }
  }

  Future<bool> _startNativeVoiceCapture(
    _CoachMediaPageRequest request,
    int generation, {
    required void Function(String) writeTranscript,
    required bool Function() hasUserEdited,
  }) async {
    try {
      final available = await speech.initialize(
        onError: (error) {
          if (_voiceRequestCurrent(request, generation) &&
              !voiceSubmitPending &&
              !voiceTranscriptBridge.hasFinal) {
            unawaited(
              _handleVoiceFailure(
                error,
                request: request,
                generation: generation,
              ),
            );
          }
        },
      );
      if (!await _voiceRequestAllowed(request, generation) ||
          !available ||
          !_canCaptureVoice) {
        return false;
      }
      // Speech language is deliberately independent from the BIL interface.
      // Supplying the UI locale here makes Android lock recognition to that
      // language before its language-switch model gets a chance to run.
      final speechLocaleAllowList = await _coachSpeechLocaleAllowList();
      if (!await _voiceRequestAllowed(request, generation) ||
          !_canCaptureVoice) {
        return false;
      }
      if (hasUserEdited()) {
        await _finishVoiceTranscriptForReview(request, generation);
        return true;
      }
      _updateState(() {
        listening = true;
      });
      await speech.listen(
        onResult: (result) {
          if (!_voiceRequestCurrent(request, generation) ||
              !_canCaptureVoice ||
              voiceSubmitPending ||
              hasUserEdited()) {
            return;
          }
          final accepted = result.isFinal
              ? voiceTranscriptBridge.acceptFinal(
                  request.attempt,
                  result.recognizedWords,
                  languageTag: result.localeId,
                )
              : voiceTranscriptBridge.acceptPartial(
                  request.attempt,
                  result.recognizedWords,
                  languageTag: result.localeId,
                );
          if (!accepted) return;
          unawaited(
            _publishVoiceTranscript(
              request,
              generation,
              writeTranscript: writeTranscript,
              hasUserEdited: hasUserEdited,
            ),
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
      if (!await _voiceRequestAllowed(request, generation)) {
        // Do not cancel a shared native recognizer on behalf of an old attempt:
        // a newer deliberate capture may already own it.
        return false;
      }
      if (hasUserEdited()) {
        await _finishVoiceTranscriptForReview(request, generation);
      }
      return true;
    } on Object {
      if (!_voiceRequestCurrent(request, generation)) return false;
      try {
        await speech.cancel();
      } on Object {
        // The inline composer remains available as a fallback.
      }
      if (!await _voiceRequestAllowed(request, generation)) return false;
      _updateState(() => listening = false);
      return false;
    }
  }

  bool _voiceRequestCurrent(_CoachMediaPageRequest request, int generation) {
    if (!_voiceRouteIsCurrent) {
      request.attempt.cancel();
      return false;
    }
    return generation == voiceCaptureGeneration &&
        identical(voiceMediaRequest, request) &&
        request.attempt.isCurrent;
  }

  Future<bool> _voiceRequestAllowed(
    _CoachMediaPageRequest request,
    int generation,
  ) async {
    if (!_voiceRequestCurrent(request, generation)) return false;
    final allowed = await _mediaRequestCurrent(request);
    return allowed && _voiceRequestCurrent(request, generation);
  }

  Future<void> _publishVoiceTranscript(
    _CoachMediaPageRequest request,
    int generation, {
    required void Function(String) writeTranscript,
    required bool Function() hasUserEdited,
  }) async {
    if (!await _voiceRequestAllowed(request, generation) ||
        voiceSubmitPending ||
        hasUserEdited()) {
      return;
    }
    // Read the newest bridge state after the permission await. An earlier
    // partial callback cannot publish its old text over a newer final.
    final transcript = voiceTranscriptBridge.draftText;
    if (transcript.isEmpty) return;
    _updateState(() {
      pendingVoiceTranscript = transcript;
      voiceLanguageHint = voiceTranscriptBridge.languageTag;
      liveCallNoSpeechRestarts = 0;
      voiceTransientRestarts = 0;
      // The final's review window must expose the editable composer instead
      // of the listening label used while recognition is still changing.
      listening = !voiceTranscriptBridge.hasFinal;
      writeTranscript(transcript);
    });
    _scrollToLatest();
    voiceSilenceTimer?.cancel();
    if (voiceTranscriptBridge.hasFinal) {
      if (voiceMode == _CoachVoiceMode.liveCall) {
        // Preserve the deliberate live-call loop, but only a real final can
        // use its existing review window. Any composer edit cancels this timer.
        voiceSilenceTimer = Timer(const Duration(milliseconds: 900), () {
          unawaited(
            _submitVoiceTranscript(request: request, generation: generation),
          );
        });
      } else {
        await _finishVoiceTranscriptForReview(request, generation);
      }
    } else {
      voiceSilenceTimer = Timer(const Duration(milliseconds: 3500), () {
        unawaited(_finishVoiceTranscriptForReview(request, generation));
      });
    }
  }

  Future<void> _finishVoiceTranscriptForReview(
    _CoachMediaPageRequest request,
    int generation,
  ) async {
    if (!await _voiceRequestAllowed(request, generation) ||
        voiceSubmitPending) {
      return;
    }
    voiceTranscriptBridge.finish(request.attempt);
    voiceSilenceTimer?.cancel();
    final shouldStop = listening || voiceCaptureStarting;
    _updateState(() {
      listening = false;
      if (voiceMode == _CoachVoiceMode.liveCall) liveCallPaused = true;
    });
    if (!shouldStop) return;
    try {
      await speech.stop();
    } on Object {
      // The reviewed composer text remains usable if native stop is unavailable.
    }
    if (!await _voiceRequestAllowed(request, generation) ||
        request.attempt.isClaimed) {
      return;
    }
    if (voiceMode == _CoachVoiceMode.dictation) {
      await _playVoiceDeactivationCue(
        isCurrent: () => _voiceRequestCurrent(request, generation),
      );
    }
  }

  /// Called by the existing composer Send/keyboard-submit path. A stale media
  /// handoff consumes this invocation and preserves the composer for a fresh
  /// user action; it cannot silently become an ordinary text request.
  Future<bool> _submitPendingVoiceDraft() async {
    final request = voiceMediaRequest;
    if (request == null) return false;
    final generation = voiceCaptureGeneration;
    if (!_voiceRequestCurrent(request, generation)) {
      _finishVoiceMediaRequest(request);
      return true;
    }
    if (voiceSubmitPending) return true;
    if (question.text.trim().isEmpty) return false;
    // A typed correction made while the permission sheet is open stays local
    // until that deliberate capture has completed permission admission.
    if (request.capabilities.isEmpty) return true;
    await _submitVoiceTranscript(
      request: request,
      generation: generation,
      userInitiated: true,
    );
    return true;
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
}
