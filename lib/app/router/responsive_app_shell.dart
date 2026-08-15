import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations.dart';
import '../theme/premium_motion_tokens.dart';
import '../theme/bil_semantic_icons.dart';
import '../../shared/widgets/bil_wordmark.dart';
import 'bil_quick_add_sheet.dart';

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
    final currentPath = GoRouterState.of(context).uri.path;
    final index = selectedIndex(context);
    final isDashboard =
        currentPath == '/dashboard' || currentPath.startsWith('/dashboard/');
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final items = <({IconData icon, IconData selected, String label})>[
      (
        icon: BilSemanticIcons.today,
        selected: BilSemanticIcons.todaySelected,
        label: context.strings.text('Today'),
      ),
      (
        icon: BilSemanticIcons.diary,
        selected: BilSemanticIcons.diarySelected,
        label: context.strings.text('Diary'),
      ),
      (
        icon: BilSemanticIcons.discover,
        selected: BilSemanticIcons.discoverSelected,
        label: context.strings.text('Discover'),
      ),
      (
        icon: BilSemanticIcons.progress,
        selected: BilSemanticIcons.progressSelected,
        label: context.strings.text('Progress'),
      ),
      (
        icon: BilSemanticIcons.insights,
        selected: BilSemanticIcons.insightsSelected,
        label: context.strings.text('Insights'),
      ),
      (
        icon: BilSemanticIcons.more,
        selected: BilSemanticIcons.moreSelected,
        label: context.strings.text('More'),
      ),
    ];

    void navigate(int next) {
      if (next == 1 && index != 1) {
        final origin = Uri.encodeComponent(paths[index]);
        context.go('/daily-log?from=$origin');
        return;
      }
      context.go(paths[next]);
    }

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
      builder: (sheetContext) => BilQuickAddSheet(
        onWeight: () {
          Navigator.pop(sheetContext);
          context.push('/daily-check-in');
        },
        onFood: () {
          Navigator.pop(sheetContext);
          final origin = Uri.encodeComponent(paths[index]);
          context.go('/daily-log?focus=meal&from=$origin');
        },
        onBarcode: () {
          Navigator.pop(sheetContext);
          final origin = Uri.encodeComponent(paths[index]);
          context.go('/daily-log?action=barcode&from=$origin');
        },
        onVoice: () {
          Navigator.pop(sheetContext);
          final origin = Uri.encodeComponent(paths[index]);
          context.go('/daily-log?action=voice&from=$origin');
        },
        onPhoto: () {
          Navigator.pop(sheetContext);
          final origin = Uri.encodeComponent(paths[index]);
          context.go('/daily-log?action=photo&from=$origin');
        },
        onWater: () {
          Navigator.pop(sheetContext);
          final origin = Uri.encodeComponent(paths[index]);
          context.go('/daily-log?action=water&from=$origin');
        },
        onExercise: () {
          Navigator.pop(sheetContext);
          context.push('/wellness/workouts');
        },
        onNotes: () {
          Navigator.pop(sheetContext);
          final origin = Uri.encodeComponent(paths[index]);
          context.go('/daily-log/body-context?from=$origin');
        },
        onSearch: () {
          Navigator.pop(sheetContext);
          context.go('/nutrition');
        },
        onQuickMacros: () {
          Navigator.pop(sheetContext);
          final origin = Uri.encodeComponent(paths[index]);
          context.go('/daily-log?action=quick-macros&from=$origin');
        },
      ),
    );

    final quickButton = _GlassQuickAdd(
      key: const Key('shell-quick-add'),
      onTap: quickAdd,
    );

    if (!wide) {
      final mobileItems = [items[0], items[1], items[3], items[5]];
      final mobilePaths = [paths[0], paths[1], paths[3], paths[5]];
      final mobileIndex = switch (index) {
        1 => 1,
        3 || 4 => 2,
        5 => 3,
        _ => 0,
      };
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // The navigation surface owns real layout space. Extending content
        // behind it made nested page FABs and final rows impossible to tap.
        extendBody: false,
        body: child,
        bottomNavigationBar: Semantics(
          label: context.strings.get('primary_navigation'),
          child: _GlassBottomNavigation(
            key: const Key('glass-bottom-navigation'),
            selectedIndex: mobileIndex,
            items: mobileItems,
            showQuickAdd: isDashboard,
            onQuickAdd: quickAdd,
            onSelected: (next) {
              if (next == 1 && index != 1) {
                final origin = Uri.encodeComponent(paths[index]);
                context.go('/daily-log?from=$origin');
                return;
              }
              context.go(mobilePaths[next]);
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Quick Add belongs to the Today dashboard. Keeping it mounted on every
      // wide route lets it cover page-owned controls such as the AI Coach
      // composer, even though the compact shell already scopes it correctly.
      floatingActionButton: isDashboard ? quickButton : null,
      body: Column(
        children: [
          Semantics(
            label: context.strings.get('primary_navigation'),
            child: _GlassTopNavigation(
              key: const Key('glass-top-navigation'),
              selectedIndex: index,
              items: items,
              onSelected: navigate,
              onProfile: () => context.push('/profile-settings'),
              profileLabel: AppLocalizations.of(context).get('profile'),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
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
          child: Row(
            children: [
              const BilFullWordmark(
                height: 28,
                alignment: AlignmentDirectional.centerStart,
              ),
              const SizedBox(width: 26),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
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
                    const SizedBox(width: 8),
                    Flexible(
                      child: _TopNavigationItem(
                        key: const Key('shell-profile-control'),
                        item: (
                          icon: Icons.account_circle_outlined,
                          selected: Icons.account_circle_rounded,
                          label: profileLabel,
                        ),
                        selected: false,
                        onTap: onProfile,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopNavigationItem extends StatelessWidget {
  const _TopNavigationItem({
    super.key,
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.selected : item.icon,
                color: selected
                    ? const Color(0xFFF0F4F7)
                    : const Color(0xFF91A1B1),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFE2E9EF)
                        : const Color(0xFF91A1B1),
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
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
    required this.showQuickAdd,
    required this.onQuickAdd,
  });

  final int selectedIndex;
  final List<({IconData icon, IconData selected, String label})> items;
  final ValueChanged<int> onSelected;
  final bool showQuickAdd;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: NavigationBar(
        height: 72,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xB807111D)
            : const Color(0xB8F4F8FC),
        indicatorColor: Theme.of(context).colorScheme.primary.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? .18 : .12,
        ),
        selectedIndex: showQuickAdd && selectedIndex == 3 ? 4 : selectedIndex,
        onDestinationSelected: (next) {
          if (showQuickAdd && next == 3) {
            onQuickAdd();
            return;
          }
          onSelected(showQuickAdd && next > 3 ? next - 1 : next);
        },
        destinations: [
          for (var index = 0; index < items.length; index++) ...[
            if (showQuickAdd && index == 3)
              NavigationDestination(
                icon: const Icon(Icons.add_circle_outline_rounded),
                selectedIcon: const Icon(Icons.add_circle_rounded),
                label: context.strings.text('Quick Add navigation'),
              ),
            NavigationDestination(
              icon: Icon(items[index].icon),
              selectedIcon: Icon(items[index].selected),
              label: items[index].label,
            ),
          ],
        ],
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
        color: const Color(0xFF087FCE),
        boxShadow: const [],
      ),
      child: IconButton(
        tooltip: context.strings.text('Quick Add'),
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}
