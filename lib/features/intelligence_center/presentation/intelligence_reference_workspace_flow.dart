part of 'intelligence_center_page.dart';

extension _ReferenceWorkspaceFlow on _IntelligenceCenterPageState {
  Future<void> _showCoachMenuSheet(BuildContext anchor) async {
    final menuTheme = Theme.of(anchor);
    final action = await showBilPearlBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
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
    } else if (action == 'smart_plan') {
      await _openCoachWorkspaceRoute('/smart-plan');
    } else if (action == 'settings') {
      await _openAiCoachSettings();
    } else if (action == 'clear') {
      await _openConversationHistory(deleteMode: true);
    }
  }

  Future<void> _showCoachToolsSheet() async {
    if (!mounted || _referenceNavigating) return;
    final localeTag = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    // Tools is a chooser, not an alias for Today's diary.
    final selection = await showBilPearlBottomSheet<String>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                CoachToolsLocaleCopy.resolve('Coach tools', localeTag),
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              for (final entry in <(IconData, String, String)>[
                (
                  Icons.monitor_weight_outlined,
                  tr('Weight history', 'سجل الوزن'),
                  '/weight-history',
                ),
                (
                  Icons.restaurant_outlined,
                  CoachToolsLocaleCopy.resolve('Food diary', localeTag),
                  '/daily-log',
                ),
                (
                  Icons.insights_outlined,
                  CoachToolsLocaleCopy.resolve('Nutrition analysis', localeTag),
                  '/analytics/nutrition',
                ),
                (
                  Icons.bedtime_outlined,
                  tr('Sleep', 'النوم'),
                  '/connected-health/sleep',
                ),
                (
                  Icons.settings_outlined,
                  tr('Coach settings', 'إعدادات المدرب'),
                  '/settings/ai-coach',
                ),
              ])
                ListTile(
                  leading: Icon(entry.$1),
                  title: Text(entry.$2),
                  onTap: () => Navigator.of(sheetContext).pop(entry.$3),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selection == null) return;
    await _openCoachWorkspaceRoute(selection);
  }

  Future<void> _navigateReference(int index) async {
    if (_referenceNavigating) return;
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
        if (sending || !conversationReady) {
          // Keep the existing conversation alive until its accepted request
          // and history load settle. Do not hold the navigation lock for the
          // entire lifetime of the destination, or launch another AI request.
          unawaited(context.push(BilReferenceBottomBar.routes[index]));
        } else {
          bilSelectPrimaryTab(context, index);
        }
      }
    } finally {
      _referenceNavigating = false;
    }
  }

  Future<void> _openCoachWorkspaceRoute(String route) async {
    final uri = Uri.parse(route);
    final query = Map<String, String>.from(uri.queryParameters);
    if (uri.path == '/plan') query.putIfAbsent('origin', () => 'coach');
    if (uri.path == '/daily-log' || uri.path == '/daily-log/water') {
      query.putIfAbsent('from', () => '/intelligence-center');
    }
    final target = uri.replace(queryParameters: query).toString();
    await _openCoachRoute(target, push: true);
  }

  Widget _buildReferencePresentation(BuildContext context) {
    // Keep the approved entry hold before the default Overview, including
    // reduced-motion mode. Entering a conversation later does not replay it.
    if (entryWelcomeVisible) return const _AiCoachEntryWelcome();
    if (_referenceOverview) {
      final overview = ref.watch(coachOverviewContextProvider).asData?.value;
      return CoachReferenceWorkspace(
        snapshot: overview?.snapshot,
        recordedMealCount: overview?.recordedMealCount,
        now: ref.read(intelligenceConversationClockProvider)(),
        onChat: () => _updateState(() => _referenceOverview = false),
        onExit: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        },
        onTools: () => unawaited(_showCoachToolsSheet()),
        onRoute: (route) => unawaited(_openCoachWorkspaceRoute(route)),
        onQuickAdd: () => unawaited(_navigateReference(2)),
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
