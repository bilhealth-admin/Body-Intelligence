import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return selectedIndexForUri(GoRouterState.of(context).uri);
  }

  static int selectedIndexForUri(Uri uri) {
    final location = uri.path;
    // My Nutrition is reachable both as a Discover surface and from More.
    // Preserve the visible navigation context of the entry point instead of
    // highlighting Today while the user is still inside a More workflow.
    if (location == '/nutrition' && uri.queryParameters['from'] == 'settings') {
      return paths.indexOf('/settings');
    }
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
    final immersiveCoach = currentPath == '/intelligence-center';
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
        photoAsset:
            'assets/images/onboarding_2026/bil_onboarding_meal_quick_add_photo_v1.webp',
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
      ),
    );

    final quickButton = _GlassQuickAdd(
      key: const Key('shell-quick-add'),
      onTap: quickAdd,
      size: wide ? 62 : 56,
    );

    if (!wide) {
      final mobileItems = [
        (
          icon: BilSemanticIcons.today,
          selected: BilSemanticIcons.todaySelected,
          label: context.strings.get('dashboard'),
        ),
        items[5],
      ];
      final mobileIndex = switch (index) {
        0 => 0,
        5 => 1,
        _ => null,
      };
      return PopScope(
        canPop: !isDashboard,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || !isDashboard || kIsWeb) return;
          if (defaultTargetPlatform == TargetPlatform.android) {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          // The dock owns real layout space, so the centered action never covers
          // a page-owned control or the final row of a compact screen.
          extendBody: false,
          body: child,
          bottomNavigationBar: immersiveCoach
              ? null
              : Semantics(
                  label: context.strings.get('primary_navigation'),
                  child: _GlassBottomNavigation(
                    key: const Key('glass-bottom-navigation'),
                    selectedIndex: mobileIndex,
                    items: mobileItems,
                    quickAdd: quickButton,
                    onSelected: (next) {
                      context.go(next == 0 ? paths[0] : paths[5]);
                    },
                  ),
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
      body: immersiveCoach
          ? child
          : Column(
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
    required this.quickAdd,
    required this.onSelected,
  }) : assert(items.length == 2);

  final int? selectedIndex;
  final List<({IconData icon, IconData selected, String label})> items;
  final Widget quickAdd;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final dockHeight = 90.0 + (textScale - 1).clamp(0.0, 1.0) * 20;
    final radius = BorderRadius.circular(28);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: dark ? .26 : .12),
              blurRadius: 30,
              spreadRadius: -10,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: dockHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [Color(0xF20B1725), Color(0xEA0C2234)]
                      : const [Color(0xF7FFFFFF), Color(0xEEF2F8FC)],
                ),
                borderRadius: radius,
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: .13)
                      : colors.outlineVariant.withValues(alpha: .7),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _GlassBottomDestination(
                      key: const Key('shell-dashboard-destination'),
                      item: items[0],
                      selected: selectedIndex == 0,
                      onTap: () => onSelected(0),
                    ),
                  ),
                  Expanded(
                    child: _GlassBottomQuickAdd(
                      label: context.strings.text('Quick Add'),
                      child: quickAdd,
                    ),
                  ),
                  Expanded(
                    child: _GlassBottomDestination(
                      key: const Key('shell-more-destination'),
                      item: items[1],
                      selected: selectedIndex == 1,
                      onTap: () => onSelected(1),
                    ),
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

class _GlassBottomDestination extends StatelessWidget {
  const _GlassBottomDestination({
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
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary.withValues(alpha: .11)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? item.selected : item.icon,
                    color: foreground,
                    size: 25,
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        height: 1.05,
                      ),
                    ),
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

class _GlassBottomQuickAdd extends StatelessWidget {
  const _GlassBottomQuickAdd({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .28),
                blurRadius: 22,
                spreadRadius: -5,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
        const SizedBox(height: 3),
        Flexible(
          child: ExcludeSemantics(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassQuickAdd extends StatelessWidget {
  const _GlassQuickAdd({super.key, required this.onTap, this.size = 62});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF087FCE),
        boxShadow: const [],
      ),
      child: IconButton(
        tooltip: context.strings.text('Quick Add'),
        onPressed: onTap,
        icon: Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: size >= 60 ? 30 : 28,
        ),
      ),
    );
  }
}
