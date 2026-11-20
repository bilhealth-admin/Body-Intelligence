part of 'coach_reference_workspace.dart';

String _water(Map<String, Object?> row) {
  final amount = row['amountMl'];
  return amount is num && amount.isFinite && amount >= 0 ? '$amount ml' : '—';
}

String _steps(Map<String, Object?> row, BuildContext context) {
  final amount = row['steps'];
  return amount is num && amount.isFinite && amount >= 0
      ? '$amount ${intelligenceText(context, 'steps', 'خطوات')}'
      : '—';
}

/// Reserve the translated, scaled badge height even before verification.
/// A missing/expired badge has no hidden label or semantics, but cannot move
/// the tabs and diary cards while its authority is refreshing.
class _CoachAccessLabelSlot extends StatelessWidget {
  const _CoachAccessLabelSlot({
    required this.visible,
    required this.labels,
    required this.child,
  });
  final bool visible;
  final List<String> labels;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = DefaultTextStyle.of(
        context,
      ).style.merge(const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
      var textHeight = 0.0;
      for (final label in labels) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.localeOf(context),
        );
        painter.layout(
          maxWidth: (constraints.maxWidth - 20).clamp(1.0, double.infinity),
        );
        if (painter.height > textHeight) textHeight = painter.height;
        painter.dispose();
      }
      return SizedBox(
        height: textHeight + 10,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: visible ? child : const SizedBox.shrink(),
        ),
      );
    },
  );
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BilPearlFinish.panel(context),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

Color _workspaceAccent(BuildContext context, Color accent) =>
    Theme.of(context).brightness == Brightness.dark
    ? Color.lerp(accent, Theme.of(context).colorScheme.onSurface, .60)!
    : HSLColor.fromColor(accent).withLightness(.24).toColor();

class _NutrientTile extends StatelessWidget {
  const _NutrientTile({
    required this.label,
    required this.amount,
    required this.target,
    required this.accent,
    required this.progress,
    required this.locked,
    required this.onTap,
  });
  final String label, amount, target;
  final Color accent;
  final double progress;
  final bool locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _WorkspaceCard(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _workspaceAccent(context, accent),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (locked)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '$amount / $target',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: BilStripedProgress(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String label, detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: BilNavigationFeedback(
              child: Icon(
                icon,
                size: 17,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const BilNavigationFeedback(
            child: Icon(
              Icons.chevron_right_rounded,
              size: 15,
              color: Color(0xFF9DACC0),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Stationary workspace chrome; data/access decisions remain in its owner.
class _CoachWorkspaceHeading extends StatelessWidget {
  const _CoachWorkspaceHeading({
    required this.now,
    required this.name,
    required this.paidLabel,
    required this.unlocked,
    required this.paidPlan,
    required this.onExit,
    required this.onChat,
    required this.onTools,
    required this.onRoute,
  });
  final DateTime now;
  final String? name;
  final bool paidLabel;
  final bool unlocked;
  final CommercePlan? paidPlan;
  final VoidCallback? onExit;
  final VoidCallback onChat;
  final VoidCallback? onTools;
  final ValueChanged<String> onRoute;
  @override
  Widget build(BuildContext context) {
    final name = this.name;
    final ar = Directionality.of(context) == TextDirection.rtl;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    String t(String en, String arabic) => intelligenceText(context, en, arabic);
    return Padding(
      key: const Key("coach-workspace-pinned-heading"),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    key: const Key('coach-workspace-back-to-chat'),
                    tooltip: t('Back', 'رجوع'),
                    onPressed: onExit ?? onChat,
                    icon: BilNavigationFeedback(
                      child: Icon(
                        ar
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                        color: muted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${now.hour < 12 ? t('Good morning', 'صباح الخير') : t('Welcome back', 'أهلًا بعودتك')}${name == null || name.isEmpty ? '' : ', $name'}',
                      key: const Key('coach-workspace-greeting'),
                      style: bilPageHeadingStyle(
                        context,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t("Let's make today count.", 'لنصنع فرقًا اليوم.'),
                      key: const Key('coach-workspace-greeting-detail'),
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _CoachAccessLabelSlot(
                        visible: paidLabel || unlocked,
                        labels: [
                          BilStoreCopy.text(
                            Localizations.localeOf(context).toLanguageTag(),
                            'premium',
                          ),
                          BilStoreCopy.text(
                            Localizations.localeOf(context).toLanguageTag(),
                            'premium_ai_coach',
                          ),
                          t(
                            'Verified AI Boost access',
                            'وصول موثق عبر AI Boost',
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            paidLabel
                                ? BilStoreCopy.text(
                                    Localizations.localeOf(
                                      context,
                                    ).toLanguageTag(),
                                    paidPlan == CommercePlan.premiumAiCoach
                                        ? 'premium_ai_coach'
                                        : 'premium',
                                  )
                                : t(
                                    'Verified AI Boost access',
                                    'وصول موثق عبر AI Boost',
                                  ),
                            key: const Key('coach-workspace-plan-label'),
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF84BFF3),
                    width: 1.5,
                  ),
                ),
                child: const ClipOval(
                  child: BilCoachPortrait(width: 38, height: 38),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in <(String, String)>[
                  (t('Coach', 'المدرب'), 'coach'),
                  (t('Insights', 'تحليلات'), '/analytics'),
                  (t('Plan', 'الخطة'), '/plan'),
                  (t('Progress', 'التقدم'), '/history'),
                  (t('Tools', 'الأدوات'), '/daily-log'),
                  (t('My Plan', 'خطتي'), '/smart-plan'),
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 5),
                    child: MergeSemantics(
                      child: Semantics(
                        selected: item.$2 == 'coach',
                        child: TextButton(
                          key: Key('coach-workspace-tab-${item.$2}'),
                          style: TextButton.styleFrom(
                            foregroundColor: CommunitySapphire.actionBlue(
                              context,
                            ),
                            disabledForegroundColor: scheme.onSurface
                                .withValues(alpha: .38),
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 10,
                            ),
                            minimumSize: const Size(48, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          onPressed: item.$2 == 'coach'
                              ? onChat
                              : item.$2 == '/daily-log'
                              ? (onTools ?? () => onRoute('/daily-log'))
                              : () => onRoute(item.$2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.$2 == 'coach') ...[
                                const Icon(Icons.smart_toy_outlined, size: 18),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                item.$1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: item.$2 == 'coach'
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
