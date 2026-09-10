part of 'intelligence_center_page.dart';

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.feedbackValue,
    this.reported = false,
    this.onFeedback,
    this.onReport,
    this.onSpeak,
    this.onAction,
    this.actionPhases = const <String, _CoachActionExecutionPhase>{},
  });
  final IntelligenceMessage message;
  final bool? feedbackValue;
  final bool reported;
  final ValueChanged<bool>? onFeedback;
  final ValueChanged<String>? onReport;
  final VoidCallback? onSpeak;
  final ValueChanged<IntelligenceAction>? onAction;
  final Map<String, _CoachActionExecutionPhase> actionPhases;

  @override
  Widget build(BuildContext context) {
    final user = message.role == IntelligenceMessageRole.user;
    final scheme = Theme.of(context).colorScheme;
    if (user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          margin: const EdgeInsets.only(left: 48, bottom: 18),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 11, 16, 12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: .62),
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
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
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
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 28, 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BilResponseMark(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoachMessageText(
                  key: ValueKey('coach-message-text-${message.id}'),
                  text: message.text,
                  createdAt: message.createdAt,
                  textDirection: _messageTextDirection(message.text),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.55),
                ),
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
                if (onFeedback != null ||
                    onReport != null ||
                    onSpeak != null) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 3,
                    runSpacing: 2,
                    children: [
                      if (onSpeak != null)
                        IconButton(
                          key: Key('ai-coach-speak-${message.id}'),
                          tooltip: intelligenceText(
                            context,
                            'Read answer aloud',
                            'اقرأ الإجابة بصوت عالٍ',
                          ),
                          onPressed: onSpeak,
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(48),
                          ),
                          icon: const Icon(Icons.volume_up_rounded, size: 19),
                        ),
                      if (onFeedback != null)
                        _QuickFeedbackBar(
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
                          onPressed: () =>
                              _showAiAnswerReportSheet(context, onReport!),
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(48),
                            visualDensity: VisualDensity.standard,
                            foregroundColor: reported
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                            backgroundColor: reported
                                ? scheme.error.withValues(alpha: .14)
                                : Colors.transparent,
                          ),
                          icon: Icon(
                            reported ? Icons.flag_rounded : Icons.flag_outlined,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
                : Icon(_iconForAction(action.type), size: 18),
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
              icon: const Icon(Icons.refresh_rounded, size: 17),
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

Future<void> _showAiAnswerReportSheet(
  BuildContext context,
  ValueChanged<String> onReport,
) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            intelligenceText(
              sheetContext,
              'Report this AI answer?',
              'الإبلاغ عن إجابة الذكاء الاصطناعي؟',
            ),
            style: Theme.of(
              sheetContext,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            intelligenceText(
              sheetContext,
              'Use this for unsafe, offensive, hateful, sexual, deceptive, or otherwise harmful content. BIL records the response ID and safety category, not your question or the answer text.',
              'استخدم هذا للمحتوى غير الآمن أو المسيء أو الذي يحض على الكراهية أو الجنسي أو المخادع أو الضار. يسجل BIL معرّف الرد وفئة السلامة فقط، وليس سؤالك أو نص الإجابة.',
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            key: const Key('ai-coach-confirm-report'),
            onPressed: () {
              Navigator.of(sheetContext).pop();
              onReport('unsafe');
            },
            icon: const Icon(Icons.flag_rounded),
            label: Text(
              intelligenceText(
                sheetContext,
                'Report unsafe or offensive answer',
                'الإبلاغ عن إجابة غير آمنة أو مسيئة',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(
              MaterialLocalizations.of(sheetContext).cancelButtonLabel,
            ),
          ),
        ],
      ),
    ),
  );
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
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

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
          onTap: () => onChanged(true),
        ),
        _FeedbackReaction(
          selected: value == false,
          positive: false,
          compact: compact,
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
    required this.onTap,
  });

  final bool selected;
  final bool positive;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedColor = positive ? scheme.primary : scheme.error;
    return Semantics(
      button: true,
      selected: selected,
      label: intelligenceText(
        context,
        positive ? 'Helpful' : 'Not helpful',
        positive ? 'مفيد' : 'غير مفيد',
      ),
      child: Tooltip(
        message: intelligenceText(
          context,
          positive ? 'Helpful' : 'Not helpful',
          positive ? 'مفيد' : 'غير مفيد',
        ),
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? selectedColor.withValues(alpha: .14)
                  : Colors.transparent,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                positive
                    ? selected
                          ? Icons.thumb_up_alt_rounded
                          : Icons.thumb_up_alt_outlined
                    : selected
                    ? Icons.thumb_down_alt_rounded
                    : Icons.thumb_down_alt_outlined,
                key: ValueKey((positive, selected)),
                size: compact ? 18 : 20,
                color: selected ? selectedColor : scheme.onSurfaceVariant,
              ),
            ),
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
                null => Icon(_iconForAction(action.type)),
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
  IntelligenceActionType.updateGoal => Icons.flag_outlined,
  IntelligenceActionType.saveMeasurements => Icons.straighten_outlined,
  IntelligenceActionType.quickAddMacros => BilSemanticIcons.meal,
  IntelligenceActionType.updateMealItem => Icons.edit_outlined,
  IntelligenceActionType.moveMealItem => Icons.drive_file_move_outline,
  IntelligenceActionType.deleteMealItem => Icons.delete_outline_rounded,
  IntelligenceActionType.requestAccountDeletion =>
    BilSemanticIcons.deleteAccount,
  IntelligenceActionType.saveMemory => Icons.bookmark_add_outlined,
};

BilSemanticIconKind? _semanticKindForAction(IntelligenceActionType type) =>
    switch (type) {
      IntelligenceActionType.readNutritionRemaining ||
      IntelligenceActionType.openPlan ||
      IntelligenceActionType.quickAddMacros => BilSemanticIconKind.nutrition,
      IntelligenceActionType.readProfileIdentity => BilSemanticIconKind.profile,
      IntelligenceActionType.openDailyLog ||
      IntelligenceActionType.updateMealItem ||
      IntelligenceActionType.moveMealItem ||
      IntelligenceActionType.saveMemory => BilSemanticIconKind.notes,
      IntelligenceActionType.addWater => BilSemanticIconKind.water,
      IntelligenceActionType.addWeight => BilSemanticIconKind.weight,
      IntelligenceActionType.reviewMeal => BilSemanticIconKind.meal,
      IntelligenceActionType.reviewWorkout => BilSemanticIconKind.exercise,
      IntelligenceActionType.openReport => BilSemanticIconKind.report,
      IntelligenceActionType.setThemeMode => BilSemanticIconKind.appearance,
      IntelligenceActionType.setLanguage => BilSemanticIconKind.language,
      IntelligenceActionType.updateGoal => BilSemanticIconKind.goals,
      IntelligenceActionType.saveMeasurements =>
        BilSemanticIconKind.measurements,
      IntelligenceActionType.openAiCoachSubscription ||
      IntelligenceActionType.buyAiBoost ||
      IntelligenceActionType.manageSubscription ||
      IntelligenceActionType.navigate => BilSemanticIconKind.aiCoach,
      IntelligenceActionType.deleteMealItem ||
      IntelligenceActionType.requestAccountDeletion => null,
    };
