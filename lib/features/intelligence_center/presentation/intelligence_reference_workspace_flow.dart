part of 'intelligence_center_page.dart';

extension _ReferenceWorkspaceFlow on _IntelligenceCenterPageState {
  Future<void> _showCoachMenuSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => const _CoachMenuSheet(),
    );
    if (!mounted || action == null) return;
    if (action == 'overview') {
      _updateState(() => _referenceOverview = true);
    } else if (action == 'history') {
      await _openConversationHistory();
    } else if (action == 'memory') {
      await context.push('/decision-memory');
    } else if (action == 'settings') {
      await _openAiCoachSettings();
    } else if (action == 'clear') {
      await _openConversationHistory(deleteMode: true);
    }
  }

  Future<void> _navigateReference(int index) async {
    if (_referenceNavigating || sending || !conversationReady) return;
    _referenceNavigating = true;
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final draft = pendingVoiceTranscript.trim();
      if (question.text.trim().isEmpty && draft.isNotEmpty) {
        question.text = draft;
      }
      if (voiceMode == _CoachVoiceMode.liveCall) {
        await _pauseLiveCall();
      } else if (listening || voiceCaptureStarting) {
        await _stopVoiceCapture(resetMode: true);
      }
      if (!mounted) return;
      await _saveConversation();
      if (!mounted) return;
      if (index != 1) {
        await context.push(BilReferenceBottomBar.routes[index]);
      }
    } finally {
      _referenceNavigating = false;
    }
  }

  Widget _buildReferencePresentation(BuildContext context) {
    final inherited = Theme.of(context);
    if (_referenceOverview) {
      final snapshot = ref.watch(coachContextSnapshotProvider).asData?.value;
      return CoachReferenceWorkspace(
        snapshot: snapshot,
        now: ref.read(intelligenceConversationClockProvider)(),
        onChat: () => _updateState(() => _referenceOverview = false),
        onRoute: (route) => context.push(route),
        onPhoto: () {
          _updateState(() => _referenceOverview = false);
          unawaited(_analyzeFoodImageInChat());
        },
        onVoice: () {
          _updateState(() => _referenceOverview = false);
          unawaited(_toggleLiveCall());
        },
      );
    }
    return Theme(
      data: inherited.copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07111B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF318BFF),
          brightness: Brightness.dark,
          surface: const Color(0xFF07111B),
          onSurface: const Color(0xFFF0F5FC),
        ),
        textTheme: inherited.textTheme.apply(
          bodyColor: const Color(0xFFF0F5FC),
          displayColor: const Color(0xFFF0F5FC),
        ),
      ),
      child: Builder(builder: _buildReferenceChat),
    );
  }
}
