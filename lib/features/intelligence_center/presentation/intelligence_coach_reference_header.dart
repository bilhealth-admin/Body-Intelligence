part of 'intelligence_center_page.dart';

/// Native interaction bounds are independent from the compact visible chrome.
class _CoachHero extends StatelessWidget {
  const _CoachHero({
    super.key,
    required this.onBack,
    required this.onHistory,
    required this.onMenu,
    this.interactionEnabled = true,
  });
  final VoidCallback onBack, onHistory, onMenu;
  final bool interactionEnabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact =
        MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
        MediaQuery.sizeOf(context).width < 380;
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CoachHeaderAction(
          icon: Icons.search_rounded,
          label: intelligenceText(
            context,
            'Search conversations',
            'ابحث في محادثاتك',
          ),
          onPressed: interactionEnabled ? onHistory : null,
        ),
        _CoachHeaderAction(
          icon: Icons.history_rounded,
          label: intelligenceText(
            context,
            'Conversation history',
            'سجل المحادثات',
          ),
          onPressed: interactionEnabled ? onHistory : null,
        ),
        _CoachHeaderAction(
          icon: Icons.more_horiz_rounded,
          label: intelligenceText(context, 'Coach controls', 'أدوات المدرب'),
          onPressed: interactionEnabled ? onMenu : null,
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BilPearlFinish.panel(
        context,
        radius: BorderRadius.zero,
        shadow: false,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 48,
                child: IconButton(
                  onPressed: onBack,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: BilGlassPressFeedback(
                    child: Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ),
              ),
              _CoachHeroPortrait(
                size: 48,
                onTap: interactionEnabled ? onHistory : null,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      intelligenceText(context, 'AI Coach', 'المدرب الذكي'),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (!compact)
                      Text(
                        intelligenceText(
                          context,
                          'Your health partner, always with you',
                          'شريك صحتك، معك دائمًا',
                        ),
                        style: TextStyle(
                          fontSize: 9,
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
              if (!compact) controls,
            ],
          ),
          if (compact) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    intelligenceText(
                      context,
                      'Your health partner, always with you',
                      'شريك صحتك، معك دائمًا',
                    ),
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                controls,
              ],
            ),
          ],
          const Align(
            alignment: AlignmentDirectional.centerEnd,
            child: CommunityGoldBalanceAction(compact: true),
          ),
        ],
      ),
    );
  }
}

class _CoachHeaderAction extends StatelessWidget {
  const _CoachHeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: IconButton(
      tooltip: label,
      onPressed: onPressed,
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: BilGlassPressFeedback(
        child: Icon(
          icon,
          size: 19,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
