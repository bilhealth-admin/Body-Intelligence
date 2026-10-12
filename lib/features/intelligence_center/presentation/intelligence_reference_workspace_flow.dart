part of 'intelligence_center_page.dart';

extension _ReferenceWorkspaceFlow on _IntelligenceCenterPageState {
  Future<void> _showCoachMenuSheet(BuildContext anchor) async {
    final menuTheme = Theme.of(anchor);
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Theme(
        data: menuTheme,
        child: BilFrostedPanel(
          radius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: _CoachMenuSheet(
            currentTitle: activeConversationTitle,
            canRename: activeConversationId != null,
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'overview') {
      _updateState(() => _referenceOverview = true);
    } else if (action == 'history') {
      await _openConversationHistory();
    } else if (action == 'rename') {
      final id = activeConversationId;
      if (id != null) await _renameConversation(id);
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
    _cancelCoachMediaRequests();
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
      if (index == 2) {
        await showBilQuickAdd(context, originPath: '/intelligence-center');
      } else if (index != 1) {
        await context.push(BilReferenceBottomBar.routes[index]);
      }
    } finally {
      _referenceNavigating = false;
    }
  }

  Widget _buildReferencePresentation(BuildContext context) {
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
    // Follow the user's light/dark choice; the glass roles own presentation only.
    return Builder(builder: _buildReferenceChat);
  }
}
