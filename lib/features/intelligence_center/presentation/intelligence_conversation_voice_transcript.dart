part of 'intelligence_center_page.dart';

extension _IntelligenceConversationVoiceTranscript
    on _IntelligenceCenterPageState {
  Future<void> _submitVoiceTranscript({
    required _CoachMediaPageRequest request,
    required int generation,
    bool userInitiated = false,
  }) async {
    if (!_voiceRequestCurrent(request, generation) ||
        voiceSubmitPending ||
        sending ||
        consentPromptVisible ||
        foodImageFlowOpening) {
      return;
    }
    if (userInitiated) {
      if (!voiceTranscriptBridge.updateDraft(request.attempt, question.text)) {
        return;
      }
    } else if (!voiceTranscriptBridge.hasFinal ||
        question.text != voiceTranscriptBridge.draftText) {
      // The live-call timer cannot submit a partial or an unfinished user edit.
      return;
    }
    if (!voiceTranscriptBridge.isReadyForReview) return;
    voiceSubmitPending = true;
    voiceSilenceTimer?.cancel();
    try {
      if (!await _voiceRequestAllowed(request, generation)) return;
      final composerAtClaim = question.text;
      if (!userInitiated &&
          composerAtClaim != voiceTranscriptBridge.draftText) {
        return;
      }
      final submission = voiceTranscriptBridge.takeForSubmission(
        request.attempt,
      );
      if (submission == null) return;
      final mode = voiceMode;
      try {
        await speech.stop();
      } on Object {
        // Native stop never changes the exact text already accepted for review.
      }
      if (!await _voiceRequestAllowed(request, generation)) return;
      if (mode == _CoachVoiceMode.dictation) {
        await _playVoiceDeactivationCue(
          isCurrent: () => _voiceRequestCurrent(request, generation),
        );
        if (!await _voiceRequestAllowed(request, generation)) return;
      }
      if (!userInitiated && question.text != composerAtClaim) return;
      final autoSpeakReply = _IntelligenceCenterPageState._voiceTurnPolicy
          .planFor(
            mode == _CoachVoiceMode.liveCall
                ? CoachVoiceEntryPoint.liveCall
                : CoachVoiceEntryPoint.composerDictation,
          )
          .autoSpeakReply;
      if (!_voiceRequestCurrent(request, generation)) return;
      _updateState(() {
        listening = false;
        if (autoSpeakReply) liveCallPaused = false;
      });
      // This synchronous handoff is the boundary. The existing ask owns its
      // next request generation, consent, query routing and food review.
      final previousQueryGeneration = requestGeneration;
      final response = ask(
        inputChannel: CoachInputChannel.voice,
        detectedLanguageTag: submission.languageTag,
        textOverride: submission.text,
        autoSpeakReply: autoSpeakReply,
      );
      final admitted = requestGeneration != previousQueryGeneration;
      _finishVoiceMediaRequest(
        request,
        pauseLiveCall: !admitted,
        resetMode: mode == _CoachVoiceMode.dictation,
      );
      if (admitted && question.text == composerAtClaim) question.clear();
      await response;
      // No cleanup after the reply: a new capture or typed draft may already
      // exist, and ask's own generation governs any live-call resumption.
    } finally {
      if (identical(voiceMediaRequest, request)) {
        if (!request.attempt.isCurrent || request.attempt.isClaimed) {
          _finishVoiceMediaRequest(request);
        } else {
          voiceSubmitPending = false;
        }
      }
    }
  }

  void _finishVoiceMediaRequest(
    _CoachMediaPageRequest request, {
    bool pauseLiveCall = true,
    bool resetMode = false,
  }) {
    request.dispose();
    if (!identical(voiceMediaRequest, request)) return;
    voiceMediaRequest = null;
    voiceTranscriptBridge.cancel();
    voiceSilenceTimer?.cancel();
    voiceCaptureStarting = false;
    voiceSubmitPending = false;
    voiceLanguageHint = null;
    pendingVoiceTranscript = '';
    if (mounted) {
      _updateState(() {
        listening = false;
        if (resetMode) {
          voiceMode = _CoachVoiceMode.idle;
        } else if (pauseLiveCall && voiceMode == _CoachVoiceMode.liveCall) {
          liveCallPaused = true;
        }
      });
    }
  }

  Future<void> _resumeLiveCallIfNeeded(int generation) async {
    if (!_voiceRouteIsCurrent ||
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
    final request = voiceMediaRequest;
    if (request != null) {
      _finishVoiceMediaRequest(request, resetMode: resetMode);
    } else {
      voiceTranscriptBridge.cancel();
      voiceCaptureStarting = false;
      voiceSubmitPending = false;
    }
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

  Future<void> _handleVoiceFailure(
    SpeechRecognitionError? error, {
    required _CoachMediaPageRequest request,
    required int generation,
  }) async {
    if (!await _voiceRequestAllowed(request, generation) ||
        voiceSubmitPending) {
      return;
    }
    if (voiceTranscriptBridge.draftText.trim().isNotEmpty) {
      await _finishVoiceTranscriptForReview(request, generation);
      return;
    }
    voiceSilenceTimer?.cancel();
    try {
      await speech.cancel();
    } on Object {
      // Retry admission still depends on the original owner and request.
    }
    if (!await _voiceRequestAllowed(request, generation)) return;
    _updateState(() => listening = false);
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
      if (await _voiceRequestAllowed(request, generation) &&
          !sending &&
          _canCaptureVoice &&
          question.text.trim().isEmpty) {
        _finishVoiceMediaRequest(request, pauseLiveCall: false);
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
        if (await _voiceRequestAllowed(request, generation) &&
            _canCaptureVoice &&
            !sending &&
            question.text.trim().isEmpty) {
          _finishVoiceMediaRequest(request, pauseLiveCall: false);
          await _startVoiceCapture(playCue: false);
        }
        return;
      }
      if (voiceMode == _CoachVoiceMode.liveCall) {
        _updateState(() => liveCallPaused = true);
      }
      await _playVoiceDeactivationCue(
        isCurrent: () => _voiceRequestCurrent(request, generation),
      );
      if (!await _voiceRequestAllowed(request, generation)) return;
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
      _finishVoiceMediaRequest(request);
      return;
    }
    if (voiceMode == _CoachVoiceMode.liveCall) {
      _updateState(() => liveCallPaused = true);
    }
    _showVoiceUnavailable();
    _finishVoiceMediaRequest(request);
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
