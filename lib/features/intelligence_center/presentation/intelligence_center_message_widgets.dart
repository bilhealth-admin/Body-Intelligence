part of 'intelligence_center_page.dart';

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.feedbackValue,
    this.reported = false,
    this.onFeedback,
    this.onReport,
    this.onSpeak,
    this.onRetry,
    this.onUndo,
    this.undoInProgress = false,
    this.onAction,
    this.actionPhases = const <String, _CoachActionExecutionPhase>{},
    this.animateReveal = false,
    this.richContent,
    required this.expectedOwnerKey,
    required this.ownerVisitIsCurrent,
    this.presentationCopy,
    this.onCopy,
    this.onShare,
  });
  final IntelligenceMessage message;
  final bool? feedbackValue;
  final bool reported;
  final ValueChanged<bool>? onFeedback;
  final ValueChanged<AiCoachAnswerReportDraft>? onReport;
  final VoidCallback? onSpeak;
  final VoidCallback? onRetry;
  final VoidCallback? onUndo;
  final bool undoInProgress;
  final ValueChanged<IntelligenceAction>? onAction;
  final Map<String, _CoachActionExecutionPhase> actionPhases;
  final bool animateReveal;
  final Widget? richContent;
  final String expectedOwnerKey;
  final bool Function() ownerVisitIsCurrent;
  final CoachMessagePlainCopy? presentationCopy;
  final VoidCallback? onCopy;
  final ValueChanged<BuildContext>? onShare;

  @override
  Widget build(BuildContext context) {
    final user = message.role == IntelligenceMessageRole.user;
    final scheme = Theme.of(context).colorScheme;
    if (user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          margin: const EdgeInsets.only(left: 32, bottom: 18),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 11, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer,
                scheme.primaryContainer.withValues(alpha: .84),
              ],
            ),
            border: Border.all(
              color: scheme.primary.withValues(alpha: .26),
              width: .7,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: CoachMessageText(
            key: ValueKey('coach-message-text-${message.id}'),
            text: message.text,
            createdAt: message.createdAt,
            alignEnd: true,
            textDirection: _messageTextDirection(message.text),
            style: _coachConversationActionStyle(
              context,
              color: scheme.onPrimaryContainer,
            )?.copyWith(height: 1.4),
          ),
        ),
      );
    }

    final trustedLinks = message.links
        .where((link) => link.isTrustedLocalRoute)
        .toList(growable: false);
    final trustedActions = message.actionLinks
        .where((action) => action.isTrusted)
        .toList(growable: false);
    return CoachReplyArrival(
      messageId: message.id,
      animate: animateReveal,
      child: Container(
        key: ValueKey('ai-coach-reply-card-${message.id}'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(13),
        decoration: BilPearlFinish.panel(
          context,
          radius: BorderRadius.circular(18),
          shadow: false,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoachMessageBody(
                    text: message.text,
                    presentation: message.presentation,
                    archive:
                        message.presentation == null &&
                            message.presentationOwnerKey != null
                        ? {'ownerKey': message.presentationOwnerKey}
                        : null,
                    expectedOwnerKey: expectedOwnerKey,
                    ownerVisitIsCurrent: ownerVisitIsCurrent,
                    copy: presentationCopy,
                    textBuilder: (text) => CoachMessageText(
                      key: ValueKey('coach-message-text-${message.id}'),
                      text: text,
                      createdAt: message.createdAt,
                      textDirection: _messageTextDirection(text),
                      style: _coachConversationBodyStyle(context),
                      animateReveal: false,
                      showTime: false,
                    ),
                  ),
                  ?richContent,
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final actions = <Widget>[
                        if (onSpeak != null)
                          IconButton(
                            key: Key('ai-coach-speak-${message.id}'),
                            tooltip: intelligenceText(
                              context,
                              'Read answer aloud',
                              'اقرأ الإجابة بصوت عالٍ',
                            ),
                            onPressed: onSpeak,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            icon: const Icon(Icons.volume_up_rounded, size: 19),
                          ),
                        if (onCopy != null)
                          IconButton(
                            key: Key('ai-coach-copy-${message.id}'),
                            tooltip: intelligenceText(
                              context,
                              'Copy answer',
                              'نسخ الرد',
                            ),
                            onPressed: onCopy,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 18),
                          ),
                        if (onShare != null)
                          Builder(
                            builder: (anchor) => IconButton(
                              key: Key('ai-coach-share-${message.id}'),
                              tooltip: intelligenceText(
                                context,
                                'Share answer',
                                'مشاركة الرد',
                              ),
                              onPressed: () => onShare!(anchor),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              icon: const Icon(
                                Icons.ios_share_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                        if (onFeedback != null)
                          _QuickFeedbackBar(
                            messageId: message.id,
                            value: feedbackValue,
                            onChanged: onFeedback!,
                            compact: true,
                          ),
                        if (onReport != null)
                          IconButton(
                            key: Key('ai-coach-report-${message.id}'),
                            tooltip: intelligenceText(
                              context,
                              'Report answer',
                              'الإبلاغ عن الإجابة',
                            ),
                            onPressed: reported
                                ? null
                                : () => showAiCoachAnswerReportSheet(
                                    context,
                                    onReport!,
                                  ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            style: IconButton.styleFrom(
                              foregroundColor: reported
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                              backgroundColor: reported
                                  ? scheme.error.withValues(alpha: .14)
                                  : Colors.transparent,
                            ),
                            icon: Icon(
                              reported
                                  ? Icons.flag_rounded
                                  : Icons.flag_outlined,
                              size: 18,
                            ),
                          ),
                      ];
                      final time = CoachMessageTime(
                        createdAt: message.createdAt,
                        style: _coachConversationActionStyle(
                          context,
                          color: scheme.onSurfaceVariant,
                        ),
                      );
                      final textScale = MediaQuery.textScalerOf(
                        context,
                      ).scale(1);
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 360 || textScale > 1.2) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: time,
                                ),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Wrap(
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 2,
                                    children: actions,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [time, const Spacer(), ...actions],
                          );
                        },
                      );
                    },
                  ),
                  if (message.citationIds.isNotEmpty)
                    TextButton.icon(
                      key: Key('ai-coach-health-sources-${message.id}'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => context.push(
                        Uri(
                          path: '/health-information-sources',
                          queryParameters: {
                            'sources': message.citationIds.join(','),
                          },
                        ).toString(),
                      ),
                      icon: const Icon(Icons.menu_book_outlined, size: 17),
                      label: Text(
                        '${intelligenceText(context, 'Source', 'المصدر')} '
                        '(${message.citationIds.length})',
                      ),
                    ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: const Key('ai-coach-retry'),
                        onPressed: onRetry,
                        icon: const BilGlassPressFeedback(
                          child: Icon(Icons.refresh_rounded, size: 18),
                        ),
                        label: Text(
                          intelligenceText(context, 'Retry', 'إعادة المحاولة'),
                        ),
                      ),
                    ),
                  ],
                  if (onUndo != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        key: Key('ai-coach-undo-${message.id}'),
                        onPressed: undoInProgress ? null : onUndo,
                        icon: undoInProgress
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const BilGlassPressFeedback(
                                child: Icon(Icons.undo_rounded, size: 18),
                              ),
                        label: Text(intelligenceText(context, 'Undo', 'تراجع')),
                      ),
                    ),
                  ],
                  if (trustedLinks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final link in trustedLinks)
                          ActionChip(
                            key: Key(
                              'ai-coach-link-${link.kind.name}-${link.id}',
                            ),
                            avatar: Icon(
                              link.kind == IntelligenceMessageLinkKind.recipe
                                  ? Icons.restaurant_menu_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 18,
                            ),
                            label: Text(link.label),
                            tooltip: intelligenceText(
                              context,
                              'Open {label}',
                              'افتح {label}',
                            ).replaceAll('{label}', link.label),
                            onPressed: () => context.push(link.route),
                          ),
                      ],
                    ),
                  ],
                  if (trustedActions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final action in trustedActions)
                          _CoachMessageActionControl(
                            action: action,
                            phase:
                                actionPhases['${action.type.name}:${action.id}'] ??
                                _CoachActionExecutionPhase.idle,
                            onPressed: onAction == null
                                ? null
                                : () => onAction!(action.toAction()),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachMessageActionControl extends StatelessWidget {
  const _CoachMessageActionControl({
    required this.action,
    required this.phase,
    required this.onPressed,
  });

  final IntelligenceMessageAction action;
  final _CoachActionExecutionPhase phase;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final locale = BilLocalePolicy.canonicalTag(
      Localizations.localeOf(context),
    );
    final running = phase == _CoachActionExecutionPhase.running;
    final failed = phase == _CoachActionExecutionPhase.failed;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActionChip(
            key: Key('ai-coach-action-${action.type.name}-${action.id}'),
            avatar: running
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : BilGlassPressFeedback(
                    child: Icon(_iconForAction(action.type), size: 18),
                  ),
            label: Text(
              running
                  ? AiCoachChatCopy.resolve(locale, AiCoachChatCopy.opening)
                  : action.label,
            ),
            tooltip: action.label,
            onPressed: running ? null : onPressed,
          ),
          if (failed) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Text(
                AiCoachChatCopy.resolve(
                  locale,
                  AiCoachChatCopy.navigationFailed,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
            TextButton.icon(
              key: Key(
                'ai-coach-action-retry-${action.type.name}-${action.id}',
              ),
              onPressed: onPressed,
              icon: const BilGlassPressFeedback(
                child: Icon(Icons.refresh_rounded, size: 17),
              ),
              label: Text(
                AiCoachChatCopy.resolve(locale, AiCoachChatCopy.retry),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

TextDirection _messageTextDirection(String text) {
  for (final rune in text.runes) {
    final rtl =
        (rune >= 0x0590 && rune <= 0x08ff) ||
        (rune >= 0xfb1d && rune <= 0xfdff) ||
        (rune >= 0xfe70 && rune <= 0xfeff);
    if (rtl) return TextDirection.rtl;
    final strongLtr =
        (rune >= 0x0041 && rune <= 0x005a) ||
        (rune >= 0x0061 && rune <= 0x007a) ||
        (rune >= 0x00c0 && rune <= 0x02af) ||
        (rune >= 0x0370 && rune <= 0x052f) ||
        (rune >= 0x0900 && rune <= 0x1fff) ||
        (rune >= 0x3040 && rune <= 0x9fff);
    if (strongLtr) return TextDirection.ltr;
  }
  return TextDirection.ltr;
}

class _QuickFeedbackBar extends StatelessWidget {
  const _QuickFeedbackBar({
    required this.messageId,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final String messageId;
  final bool? value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FeedbackReaction(
          selected: value == true,
          positive: true,
          compact: compact,
          messageId: messageId,
          onTap: () => onChanged(true),
        ),
        _FeedbackReaction(
          selected: value == false,
          positive: false,
          compact: compact,
          messageId: messageId,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _FeedbackReaction extends StatelessWidget {
  const _FeedbackReaction({
    required this.selected,
    required this.positive,
    required this.compact,
    required this.messageId,
    required this.onTap,
  });

  final bool selected;
  final bool positive;
  final bool compact;
  final String messageId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emojiFontFamily = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'Apple Color Emoji',
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.linux => 'Noto Color Emoji',
      TargetPlatform.windows => 'Segoe UI Emoji',
    };
    final selectedColor = positive
        ? BilFlagshipTokens.emerald500
        : scheme.error;
    final dimension = compact ? 36.0 : 44.0;
    return IconButton(
      key: Key(
        'ai-coach-feedback-${positive ? 'helpful' : 'not-helpful'}-$messageId',
      ),
      tooltip: intelligenceText(
        context,
        positive ? 'Helpful' : 'Not helpful',
        positive ? 'مفيد' : 'غير مفيد',
      ),
      isSelected: selected,
      onPressed: () {
        unawaited(HapticFeedback.selectionClick());
        onTap();
      },
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: dimension, height: dimension),
      style: IconButton.styleFrom(
        foregroundColor: selectedColor,
        backgroundColor: selectedColor.withValues(alpha: selected ? .20 : .09),
        shape: const CircleBorder(),
        overlayColor: selectedColor.withValues(alpha: .12),
      ),
      iconSize: compact ? 18 : 20,
      icon: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: selected ? 1.08 : 1,
        child: Text(
          positive ? '👍' : '👎',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: 20,
            height: 1,
            fontFamily: emojiFontFamily,
            fontFamilyFallback: const <String>[
              'Segoe UI Emoji',
              'Apple Color Emoji',
              'Noto Color Emoji',
            ],
          ),
        ),
      ),
    );
  }
}

String _compactSpokenCoachReply(String detailedReply) {
  final plain = detailedReply
      .replaceAll(RegExp(r'[`*_#>]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (plain.length <= 140) return plain;
  final sentenceEnd = RegExp(r'[.!?؟。]').firstMatch(plain);
  if (sentenceEnd != null && sentenceEnd.end >= 24 && sentenceEnd.end <= 140) {
    return plain.substring(0, sentenceEnd.end).trim();
  }
  return '${plain.substring(0, 137).trimRight()}…';
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.actions, required this.onAction});

  final List<IntelligenceAction> actions;
  final ValueChanged<IntelligenceAction> onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            intelligenceText(context, 'Suggested actions', 'إجراءات مقترحة'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final action in actions)
            ListTile(
              key: Key(
                'ai-coach-action-sheet-${action.type.name}-${action.id}',
              ),
              leading: switch (_semanticKindForAction(action.type)) {
                final kind? => BilSemanticIconBadge(
                  kind: kind,
                  iconOverride: _iconForAction(action.type),
                  appleIconOverride: _iconForAction(action.type),
                ),
                null => BilGlassPressFeedback(
                  child: Icon(_iconForAction(action.type)),
                ),
              },
              title: Text(action.label),
              subtitle: Text(
                action.requiresConfirmation
                    ? intelligenceText(
                        context,
                        'Requires your confirmation',
                        'يتطلب تأكيدك',
                      )
                    : '',
              ),
              onTap: () {
                Navigator.pop(context);
                onAction(action);
              },
            ),
        ],
      ),
    );
  }
}

IconData _iconForAction(IntelligenceActionType type) => switch (type) {
  IntelligenceActionType.navigate => Icons.navigation_outlined,
  IntelligenceActionType.readNutritionRemaining => Icons.pie_chart_outline,
  IntelligenceActionType.readProfileIdentity => Icons.person_outline,
  IntelligenceActionType.openDailyLog => BilSemanticIcons.diary,
  IntelligenceActionType.addWater => BilSemanticIcons.water,
  IntelligenceActionType.addWeight => BilSemanticIcons.weight,
  IntelligenceActionType.reviewMeal => BilSemanticIcons.meal,
  IntelligenceActionType.reviewWorkout => BilSemanticIcons.workout,
  IntelligenceActionType.openPlan => Icons.route_outlined,
  IntelligenceActionType.openReport => BilSemanticIcons.insights,
  IntelligenceActionType.openAiCoachSubscription =>
    Icons.workspace_premium_outlined,
  IntelligenceActionType.buyAiBoost => Icons.bolt_rounded,
  IntelligenceActionType.manageSubscription => BilSemanticIcons.subscription,
  IntelligenceActionType.setThemeMode => Icons.contrast_rounded,
  IntelligenceActionType.setLanguage => Icons.language_rounded,
  IntelligenceActionType.setUnitPreference => Icons.straighten_rounded,
  IntelligenceActionType.setReminder => Icons.notifications_outlined,
  IntelligenceActionType.reviewMemories => Icons.psychology_alt_outlined,
  IntelligenceActionType.prepareLocalExport => Icons.file_download_outlined,
  IntelligenceActionType.updateGoal => Icons.flag_outlined,
  IntelligenceActionType.saveMeasurements => Icons.straighten_outlined,
  IntelligenceActionType.quickAddMacros => BilSemanticIcons.meal,
  IntelligenceActionType.logFoods => BilSemanticIcons.meal,
  IntelligenceActionType.replaceMealItem => Icons.edit_outlined,
  IntelligenceActionType.updateMealItem => Icons.edit_outlined,
  IntelligenceActionType.moveMealItem => Icons.drive_file_move_outline,
  IntelligenceActionType.deleteMealItem => Icons.delete_outline_rounded,
  IntelligenceActionType.requestAccountDeletion =>
    BilSemanticIcons.deleteAccount,
  IntelligenceActionType.signOut => Icons.logout_rounded,
  IntelligenceActionType.saveMemory => Icons.bookmark_add_outlined,
  IntelligenceActionType.healthCommand => BilSemanticIcons.diary,
  IntelligenceActionType.readHealthData => BilSemanticIcons.insights,
};

BilSemanticIconKind? _semanticKindForAction(
  IntelligenceActionType type,
) => switch (type) {
  IntelligenceActionType.readNutritionRemaining ||
  IntelligenceActionType.openPlan ||
  IntelligenceActionType.quickAddMacros ||
  IntelligenceActionType.logFoods => BilSemanticIconKind.nutrition,
  IntelligenceActionType.readProfileIdentity => BilSemanticIconKind.profile,
  IntelligenceActionType.openDailyLog ||
  IntelligenceActionType.replaceMealItem ||
  IntelligenceActionType.updateMealItem ||
  IntelligenceActionType.moveMealItem ||
  IntelligenceActionType.healthCommand ||
  IntelligenceActionType.saveMemory => BilSemanticIconKind.notes,
  IntelligenceActionType.addWater => BilSemanticIconKind.water,
  IntelligenceActionType.addWeight => BilSemanticIconKind.weight,
  IntelligenceActionType.reviewMeal => BilSemanticIconKind.meal,
  IntelligenceActionType.reviewWorkout => BilSemanticIconKind.exercise,
  IntelligenceActionType.openReport ||
  IntelligenceActionType.readHealthData => BilSemanticIconKind.report,
  IntelligenceActionType.setThemeMode => BilSemanticIconKind.appearance,
  IntelligenceActionType.setLanguage => BilSemanticIconKind.language,
  IntelligenceActionType.setUnitPreference => BilSemanticIconKind.measurements,
  IntelligenceActionType.setReminder => BilSemanticIconKind.notifications,
  IntelligenceActionType.reviewMemories => BilSemanticIconKind.notes,
  IntelligenceActionType.prepareLocalExport => BilSemanticIconKind.report,
  IntelligenceActionType.updateGoal => BilSemanticIconKind.goals,
  IntelligenceActionType.saveMeasurements => BilSemanticIconKind.measurements,
  IntelligenceActionType.openAiCoachSubscription ||
  IntelligenceActionType.buyAiBoost ||
  IntelligenceActionType.manageSubscription ||
  IntelligenceActionType.navigate => BilSemanticIconKind.aiCoach,
  IntelligenceActionType.deleteMealItem ||
  IntelligenceActionType.requestAccountDeletion ||
  IntelligenceActionType.signOut => null,
};
