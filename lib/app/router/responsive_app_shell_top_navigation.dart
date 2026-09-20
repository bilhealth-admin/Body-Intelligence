part of 'responsive_app_shell.dart';

class _GlassTopNavigation extends StatelessWidget {
  const _GlassTopNavigation({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
    required this.onProfile,
    required this.profileLabel,
  });

  final int selectedIndex;
  final List<({IconData icon, IconData selected, String label})> items;
  final ValueChanged<int> onSelected;
  final VoidCallback onProfile;
  final String profileLabel;

  @override
  Widget build(BuildContext context) {
    final profileIcons = BilNavigationIcons.forDestination(
      BilNavigationDestination.profile,
      Theme.of(context).platform,
    );
    return SafeArea(
      bottom: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 120,
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: .075),
                  const Color(0xFF52D9FF).withValues(alpha: .025),
                  const Color(0xFF775FFF).withValues(alpha: .022),
                  Colors.white.withValues(alpha: .012),
                ],
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  key: const Key('shell-identity-header'),
                  height: 48,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          key: const Key('shell-profile-control'),
                          width: 140,
                          height: 48,
                          child: _TopNavigationItem(
                            item: (
                              icon: profileIcons.icon,
                              selected: profileIcons.selected,
                              label: profileLabel,
                            ),
                            selected: false,
                            onTap: onProfile,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 150),
                        child: BilFullWordmark(
                          key: Key('shell-wordmark'),
                          height: 28,
                          alignment: Alignment.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        Flexible(
                          child: _TopNavigationItem(
                            item: items[i],
                            selected: i == selectedIndex,
                            onTap: () => onSelected(i),
                          ),
                        ),
                        if (i != items.length - 1) const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopNavigationItem extends StatelessWidget {
  const _TopNavigationItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData selected, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: selected ? colors.primaryContainer : null,
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x354CD9FF),
                        blurRadius: 22,
                        spreadRadius: -8,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? item.selected : item.icon, color: foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
