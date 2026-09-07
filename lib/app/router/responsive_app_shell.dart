import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations.dart';
import '../theme/premium_motion_tokens.dart';
import '../theme/bil_navigation_icons.dart';
import '../../shared/widgets/bil_wordmark.dart';
import 'bil_quick_add_sheet.dart';

part 'responsive_app_shell_top_navigation.dart';

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

  /// Accept only exact shell roots as a post-Quick-Add return destination.
  /// This preserves Discover, Progress, Insights, and More without allowing a
  /// caller-controlled URL or an arbitrary internal route to become a redirect.
  static String? safeQuickAddReturnPath(String? value) =>
      paths.contains(value) ? value : null;

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
    // A ShellRoute widget can inherit the shell page's GoRouterState instead
    // of the active child route. Read the delegate's complete configuration so
    // root-back and selected-navigation behavior follow the route the user is
    // actually viewing on phones and wide layouts alike.
    final currentUri = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri;
    final currentPath = currentUri.path;
    final index = selectedIndexForUri(currentUri);
    final isDashboard =
        currentPath == '/dashboard' || currentPath.startsWith('/dashboard/');
    final isDashboardRoot = currentPath == '/dashboard';
    final hasRouteHistory = context.canPop();
    final immersiveCoach = currentPath == '/intelligence-center';
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final platform = Theme.of(context).platform;
    final systemUiOverlayStyle = SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
    ({IconData icon, IconData selected, String label}) navigationItem(
      BilNavigationDestination destination,
      String label,
    ) {
      final icons = BilNavigationIcons.forDestination(destination, platform);
      return (icon: icons.icon, selected: icons.selected, label: label);
    }

    final items = <({IconData icon, IconData selected, String label})>[
      navigationItem(
        BilNavigationDestination.today,
        context.strings.text('Today'),
      ),
      navigationItem(
        BilNavigationDestination.diary,
        context.strings.text('Diary'),
      ),
      navigationItem(
        BilNavigationDestination.discover,
        context.strings.text('Discover'),
      ),
      navigationItem(
        BilNavigationDestination.progress,
        context.strings.text('Progress'),
      ),
      navigationItem(
        BilNavigationDestination.insights,
        context.strings.text('Insights'),
      ),
      navigationItem(
        BilNavigationDestination.more,
        context.strings.text('More'),
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

    Future<void> quickAdd() async {
      final action = await showModalBottomSheet<String>(
        context: context,
        // Keep the sheet dismissible from the dimmed area and draggable from
        // the handle/content on both iOS and Android. The custom sheet owns
        // its visual handle, so the framework handle is intentionally
        // disabled.
        isDismissible: true,
        enableDrag: true,
        showDragHandle: false,
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
        builder: (sheetContext) {
          return BilQuickAddSheet(
            photoAsset:
                'assets/images/onboarding_2026/bil_onboarding_meal_quick_add_photo_v1.webp',
            onFood: () {
              Navigator.of(sheetContext).pop('food');
            },
            onBarcode: () {
              Navigator.of(sheetContext).pop('barcode');
            },
            onVoice: () {
              Navigator.of(sheetContext).pop('voice');
            },
            onPhoto: () {
              Navigator.of(sheetContext).pop('photo');
            },
            onExercise: () {
              Navigator.of(sheetContext).pop('exercise');
            },
            onNotes: () {
              Navigator.of(sheetContext).pop('notes');
            },
            onSearch: () {
              Navigator.of(sheetContext).pop('search');
            },
          );
        },
      );

      // Navigate only after showModalBottomSheet has completed its reverse
      // animation. Starting a shell route from inside the sheet can race its
      // teardown on iOS and leave a blank child, which also prevents Quick Add
      // barcode/photo actions from opening their capture surfaces.
      if (!context.mounted || action == null) return;
      final origin = Uri.encodeComponent(paths[index]);
      switch (action) {
        case 'food':
          final hour = DateTime.now().hour;
          final meal = hour < 11
              ? 'breakfast'
              : hour < 16
              ? 'lunch'
              : hour < 21
              ? 'dinner'
              : 'snack';
          context.go('/daily-log?focus=meal&meal=$meal&from=$origin');
          break;
        case 'barcode':
          context.go('/daily-log?action=barcode&from=$origin');
          break;
        case 'voice':
          context.go('/daily-log?action=voice&from=$origin');
          break;
        case 'photo':
          context.push('/intelligence-center?vision=capture&from=$origin');
          break;
        case 'exercise':
          context.push('/wellness/workouts');
          break;
        case 'notes':
          context.go('/daily-log/body-context?from=$origin');
          break;
        case 'search':
          if (currentPath != '/nutrition') context.push('/nutrition');
          break;
      }
    }

    final quickButton = _GlassQuickAdd(
      key: const Key('shell-quick-add'),
      onTap: quickAdd,
      size: wide ? 62 : 56,
    );

    void handleSystemBack(bool didPop) {
      if (didPop || kIsWeb) return;
      // Bottom-navigation destinations are reached with `go`, so they may not
      // have a route beneath them. Android back from such a destination must
      // return to Today before a second back exits the app. The iOS root has
      // no system-back action and therefore remains in place.
      if (!isDashboardRoot) {
        context.go('/dashboard');
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        SystemNavigator.pop();
      }
    }

    if (!wide) {
      final mobileItems = [
        navigationItem(
          BilNavigationDestination.today,
          context.strings.get('dashboard'),
        ),
        items[5],
      ];
      final mobileIndex = switch (index) {
        0 => 0,
        5 => 1,
        _ => null,
      };
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemUiOverlayStyle,
        child: PopScope(
          key: const Key('responsive-app-shell-pop-scope'),
          canPop: hasRouteHistory,
          onPopInvokedWithResult: (didPop, _) => handleSystemBack(didPop),
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
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: PopScope(
        key: const Key('responsive-app-shell-pop-scope'),
        // Android's root-back contract must not disappear merely because a
        // phone rotates or a tablet crosses the wide-layout breakpoint.
        canPop: hasRouteHistory,
        onPopInvokedWithResult: (didPop, _) => handleSystemBack(didPop),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          // Quick Add belongs to the Today dashboard. Mounting it on every wide
          // route could cover page-owned controls such as the AI Coach composer.
          floatingActionButton: isDashboard ? quickButton : null,
          body: immersiveCoach
              ? child
              : Column(
                  children: [
                    Semantics(
                      container: true,
                      label: context.strings.get('primary_navigation'),
                      child: _GlassTopNavigation(
                        key: const Key('glass-top-navigation'),
                        selectedIndex: index,
                        items: items,
                        onSelected: navigate,
                        onProfile: () => context.push('/profile-settings'),
                        profileLabel: AppLocalizations.of(
                          context,
                        ).get('profile'),
                      ),
                    ),
                    // Keep the nested Navigator's route-level BlockSemantics
                    // inside its own boundary, so it cannot hide the tab bar
                    // painted earlier in this Column from screen readers.
                    Expanded(child: Semantics(container: true, child: child)),
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
      container: true,
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
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
          BilNavigationIcons.quickAdd(Theme.of(context).platform),
          color: Colors.white,
          size: size >= 60 ? 30 : 28,
        ),
      ),
    );
  }
}
