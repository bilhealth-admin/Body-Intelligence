part of 'intelligence_center_page.dart';

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.feedbackValue,
    this.onFeedback,
    this.onReport,
  });
  final IntelligenceMessage message;
  final bool? feedbackValue;
  final ValueChanged<bool>? onFeedback;
  final ValueChanged<String>? onReport;

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
          child: Text(
            message.text,
            textDirection: _messageTextDirection(message.text),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
        ),
      );
    }

    final hasDetails =
        message.reason?.trim().isNotEmpty == true ||
        message.evidence.isNotEmpty ||
        message.missingData.isNotEmpty ||
        message.confidence != null;
    final trustedLinks = message.links
        .where((link) => link.isTrustedLocalRoute)
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
                Text(
                  message.text,
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
                if (hasDetails || onFeedback != null || onReport != null) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 3,
                    runSpacing: 2,
                    children: [
                      if (hasDetails)
                        TextButton.icon(
                          onPressed: () =>
                              _showMessageDetails(context, message),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 36),
                            visualDensity: VisualDensity.compact,
                            foregroundColor: scheme.onSurfaceVariant,
                          ),
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                          ),
                          label: Text(
                            intelligenceText(
                              context,
                              'Why this answer',
                              'لماذا هذا الجواب',
                            ),
                          ),
                        ),
                      if (onFeedback != null)
                        _QuickFeedbackBar(
                          value: feedbackValue,
                          onChanged: onFeedback!,
                          compact: true,
                        ),
                      if (onReport != null)
                        TextButton.icon(
                          key: Key('ai-coach-report-${message.id}'),
                          onPressed: () =>
                              _showAiAnswerReportSheet(context, onReport!),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            minimumSize: const Size(0, 36),
                            visualDensity: VisualDensity.compact,
                            foregroundColor: scheme.onSurfaceVariant,
                          ),
                          icon: const Icon(Icons.flag_outlined, size: 17),
                          label: Text(
                            intelligenceText(
                              context,
                              'Report answer',
                              'الإبلاغ عن الإجابة',
                            ),
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

Future<void> _showMessageDetails(
  BuildContext context,
  IntelligenceMessage message,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      final confidence = message.confidence == null
          ? null
          : '${(message.confidence!.clamp(0, 1) * 100).round()}%';
      return Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            children: [
              Text(
                intelligenceText(
                  sheetContext,
                  'Why BIL answered this way',
                  'لماذا أجاب BIL بهذه الطريقة',
                ),
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (message.reason?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 18),
                Text(
                  intelligenceText(sheetContext, 'Reasoning', 'السبب'),
                  style: Theme.of(sheetContext).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(message.reason!),
              ],
              if (message.evidence.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  intelligenceText(
                    sheetContext,
                    'Evidence used',
                    'الأدلة المستخدمة',
                  ),
                  style: Theme.of(sheetContext).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.evidence
                      .take(6)
                      .map(
                        (value) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            value,
                            style: Theme.of(sheetContext).textTheme.labelMedium,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (message.missingData.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  intelligenceText(
                    sheetContext,
                    'Still missing',
                    'ما يزال ناقصاً',
                  ),
                  style: Theme.of(sheetContext).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(message.missingData.join(' · ')),
              ],
              if (confidence != null) ...[
                const SizedBox(height: 18),
                Text(
                  intelligenceText(
                    sheetContext,
                    'Answer confidence: {confidence}',
                    'ثقة الإجابة: {confidence}',
                  ).replaceAll('{confidence}', confidence),
                  style: Theme.of(sheetContext).textTheme.labelLarge,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
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
            width: compact ? 32 : 36,
            height: compact ? 32 : 36,
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
              leading: Icon(_iconForAction(action.type)),
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
