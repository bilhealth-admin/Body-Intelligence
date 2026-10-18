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
        MediaQuery.sizeOf(context).width < 520;
    final buttonSize = compact ? 40.0 : 44.0;
    final compactActions = Row(
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
          size: buttonSize,
        ),
        _CoachHeaderAction(
          icon: Icons.history_rounded,
          label: intelligenceText(
            context,
            'Conversation history',
            'سجل المحادثات',
          ),
          onPressed: interactionEnabled ? onHistory : null,
          size: buttonSize,
        ),
        _CoachHeaderAction(
          icon: Icons.more_horiz_rounded,
          label: intelligenceText(context, 'Coach controls', 'أدوات المدرب'),
          onPressed: interactionEnabled ? onMenu : null,
          size: buttonSize,
        ),
      ],
    );
    final backSize = 48.0;
    final portraitSize = compact ? 40.0 : 44.0;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        compact ? 6 : 12,
        compact ? 3 : 6,
        compact ? 6 : 12,
        compact ? 3 : 6,
      ),
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
                dimension: backSize,
                child: IconButton(
                  onPressed: onBack,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(
                    width: backSize,
                    height: backSize,
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
                size: portraitSize,
                onTap: interactionEnabled ? onHistory : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  intelligenceText(context, 'AI Coach', 'المدرب الذكي'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const CommunityGoldBalanceAction(
                compact: true,
                showBalance: false,
                showEarn: true,
              ),
              compactActions,
            ],
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: backSize + portraitSize + 6,
              end: 8,
            ),
            child: Transform.translate(
              offset: const Offset(0, -4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  intelligenceText(
                    context,
                    'Your health partner, always with you',
                    'شريك صحتك، معك دائمًا',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                    height: 1.15,
                  ),
                ),
              ),
            ),
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
    this.size = 48,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: BilGlassPressFeedback(
      always: true,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        padding: const EdgeInsets.all(5),
        constraints: BoxConstraints.tightFor(width: size, height: size),
        icon: Icon(
          icon,
          size: 19,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
