import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations.dart';
import '../theme/premium_motion_tokens.dart';

class ResponsiveAppShell extends StatelessWidget {
  const ResponsiveAppShell({super.key, required this.child});

  final Widget child;

  static const paths = <String>[
    '/dashboard',
    '/daily-log',
    '/nutrition',
    '/history',
    '/analytics',
    '/settings',
  ];

  int selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (location == path || location.startsWith('$path/')) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = selectedIndex(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final arabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    final items = <({IconData icon, IconData selected, String label})>[
      (
        icon: Icons.dashboard_outlined,
        selected: Icons.dashboard_rounded,
        label: context.strings.text('Today'),
      ),
      (
        icon: Icons.edit_note_outlined,
        selected: Icons.edit_note_rounded,
        label: context.strings.text('Diary'),
      ),
      (
        icon: Icons.restaurant_menu_outlined,
        selected: Icons.restaurant_menu_rounded,
        label: context.strings.text('Discover'),
      ),
      (
        icon: Icons.monitor_weight_outlined,
        selected: Icons.monitor_weight_rounded,
        label: context.strings.text('Progress'),
      ),
      (
        icon: Icons.analytics_outlined,
        selected: Icons.analytics_rounded,
        label: context.strings.text('Insights'),
      ),
      (
        icon: Icons.settings_outlined,
        selected: Icons.settings_rounded,
        label: context.strings.text('More'),
      ),
    ];

    void navigate(int next) => context.go(paths[next]);

    void quickAdd() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AnimationStyle(
        duration: PremiumMotionTokens.durationFor(
          context,
          PremiumMotionTokens.navigationDuration,
        ),
        reverseDuration: PremiumMotionTokens.durationFor(
          context,
          PremiumMotionTokens.stateChangeDuration,
        ),
      ),
      builder: (sheetContext) => _QuickAddSheet(
        arabic: arabic,
        onWeight: () {
          Navigator.pop(sheetContext);
          context.go('/daily-check-in');
        },
        onFood: () {
          Navigator.pop(sheetContext);
          context.go('/daily-log');
        },
        onWater: () {
          Navigator.pop(sheetContext);
          context.go('/daily-log');
        },
        onSearch: () {
          Navigator.pop(sheetContext);
          context.go('/nutrition');
        },
      ),
    );

    final quickButton = _GlassQuickAdd(
      key: const Key('shell-quick-add'),
      onTap: quickAdd,
    );

    if (!wide) {
      return Scaffold(
        backgroundColor: const Color(0xFF01050D),
        body: child,
        floatingActionButton: quickButton,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: Semantics(
          label: arabic ? 'التنقل الرئيسي' : 'Primary navigation',
          child: _GlassBottomNavigation(
            key: const Key('glass-bottom-navigation'),
            selectedIndex: index,
            items: items,
            onSelected: navigate,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF01050D),
      floatingActionButton: quickButton,
      body: Row(
        children: [
          Semantics(
            label: arabic ? 'التنقل الرئيسي' : 'Primary navigation',
            child: _GlassNavigationRail(
              key: const Key('glass-navigation-rail'),
              selectedIndex: index,
              items: items,
              onSelected: navigate,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _GlassNavigationRail extends StatelessWidget {
  const _GlassNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<({IconData icon, IconData selected, String label})> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 104,
          padding: const EdgeInsets.fromLTRB(10, 24, 10, 90),
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
              const Text(
                'BIL®',
                style: TextStyle(
                  color: Color(0xFFE8EEF3),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 30),
              for (var i = 0; i < items.length; i++) ...[
                _RailItem(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
                const SizedBox(height: 9),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData selected, String label}) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: selected
                ? LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: .14),
                      const Color(0xFF54D9FF).withValues(alpha: .07),
                      const Color(0xFF765FFF).withValues(alpha: .06),
                    ],
                  )
                : null,
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
          child: Column(
            children: [
              Icon(
                selected ? item.selected : item.icon,
                color: selected
                    ? const Color(0xFFF0F4F7)
                    : const Color(0xFF91A1B1),
              ),
              const SizedBox(height: 5),
              Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFE2E9EF)
                      : const Color(0xFF91A1B1),
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassBottomNavigation extends StatelessWidget {
  const _GlassBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<({IconData icon, IconData selected, String label})> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: NavigationBar(
          height: 76,
          backgroundColor: const Color(0xC407111D),
          indicatorColor: Colors.white.withValues(alpha: .12),
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          destinations: [
            for (final item in items)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selected),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassQuickAdd extends StatelessWidget {
  const _GlassQuickAdd({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: .22),
            const Color(0xFF54D9FF).withValues(alpha: .13),
            const Color(0xFF765FFF).withValues(alpha: .12),
          ],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x704BD8FF), blurRadius: 28, spreadRadius: -7),
        ],
      ),
      child: IconButton(
        tooltip: context.strings.text('Quick Add'),
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, color: Color(0xFFF1F5F8), size: 30),
      ),
    );
  }
}

class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet({
    required this.arabic,
    required this.onWeight,
    required this.onFood,
    required this.onWater,
    required this.onSearch,
  });

  final bool arabic;
  final VoidCallback onWeight;
  final VoidCallback onFood;
  final VoidCallback onWater;
  final VoidCallback onSearch;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xF20A1522),
                    const Color(0xE9131B2D),
                    const Color(0xEC0A111C),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('Quick Add', 'إضافة سريعة'),
                    style: const TextStyle(
                      color: Color(0xFFE8EEF3),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _QuickAction(
                    icon: Icons.monitor_weight_outlined,
                    label: tr('Daily weight check-in', 'قياس الوزن اليومي'),
                    onTap: onWeight,
                  ),
                  _QuickAction(
                    icon: Icons.restaurant_menu_rounded,
                    label: tr('Add food', 'إضافة طعام'),
                    onTap: onFood,
                  ),
                  _QuickAction(
                    icon: Icons.water_drop_outlined,
                    label: tr('Add water', 'إضافة ماء'),
                    onTap: onWater,
                  ),
                  _QuickAction(
                    icon: Icons.search_rounded,
                    label: tr('Search or create food', 'البحث أو إنشاء طعام'),
                    onTap: onSearch,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: .075),
                const Color(0xFF54D9FF).withValues(alpha: .025),
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFDCE5EC)),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFDCE5EC),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9BAAB9)),
            ],
          ),
        ),
      ),
    );
  }
}
