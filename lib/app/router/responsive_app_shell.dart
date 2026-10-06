import '../../features/community/presentation/community_attention_scope.dart';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations.dart';
import '../theme/bil_navigation_icons.dart';
import '../../shared/widgets/bil_wordmark.dart';
import '../../shared/widgets/bil_reference_bottom_bar.dart';
import 'bil_quick_add_presenter.dart';

part 'responsive_app_shell_top_navigation.dart';

class ResponsiveAppShell extends StatelessWidget {
  const ResponsiveAppShell({super.key, required this.child, this.currentUri});

  final Widget child;

  /// The URI of the active child supplied by [ShellRoute]. Keeping this on
  /// the shell page avoids relying on the delegate's configuration, which can
  /// briefly describe the parent shell while an imperative push is settling.
  final Uri? currentUri;

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
      safeBilQuickAddReturnPath(value);

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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: GoRouter.of(context).routerDelegate,
    builder: (context, _) => _buildShell(context),
  );

  Widget _buildShell(BuildContext context) {
    // Prefer the URI captured by ShellRoute. The router delegate can briefly
    // describe the parent shell while an imperative push is settling, which
    // used to remount the bottom dock over the immersive AI Coach route.
    final activeUri =
        currentUri ??
        GoRouter.of(context).routerDelegate.currentConfiguration.uri;
    final currentPath = activeUri.path;
    final index = selectedIndexForUri(activeUri);
    final isDashboard =
        currentPath == '/dashboard' || currentPath.startsWith('/dashboard/');
    final isDashboardRoot = currentPath == '/dashboard';
    final hasRouteHistory = context.canPop();
    // Keep the coach immersive for the route and any future coach sub-route;
    // the dashboard dock must never consume space inside the conversation.
    final immersiveCoach =
        currentPath == '/intelligence-center' ||
        currentPath.startsWith('/intelligence-center/');
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final platform = Theme.of(context).platform;
    final systemUiOverlayStyle = SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
    ({
      IconData icon,
      IconData selected,
      String label,
      BilNavigationDestination destination,
    })
    navigationItem(BilNavigationDestination destination, String label) {
      final icons = BilNavigationIcons.forDestination(destination, platform);
      return (
        icon: icons.icon,
        selected: icons.selected,
        label: label,
        destination: destination,
      );
    }

    final items =
        <
          ({
            IconData icon,
            IconData selected,
            String label,
            BilNavigationDestination destination,
          })
        >[
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

    Future<void> quickAdd() =>
        showBilQuickAdd(context, originPath: paths[index]);

    final quickButton = _GlassQuickAdd(
      key: const Key('shell-quick-add'),
      onTap: quickAdd,
      size: wide ? 62 : 64,
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
      final mobileIndex = switch (index) {
        0 => 0,
        5 => 4,
        _ => -1,
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
                    child: BilReferenceBottomBar(
                      key: const Key('glass-bottom-navigation'),
                      selected: mobileIndex,
                      moreAttentionCount:
                          CommunityAttentionScope.controllerOf(
                            context,
                          )?.value.total ??
                          0,
                      destinationKeys: const {
                        0: Key('shell-dashboard-destination'),
                        1: Key('shell-coach-destination'),
                        2: Key('shell-quick-add'),
                        3: Key('shell-community-destination'),
                        4: Key('shell-more-destination'),
                      },
                      onSelected: (next) {
                        if (next == 2) {
                          quickAdd();
                          return;
                        }
                        final target = BilReferenceBottomBar.routes[next];
                        final activePath = GoRouter.of(
                          context,
                        ).routerDelegate.currentConfiguration.uri.path;
                        // Tabs select the canonical shell root. Replacing the
                        // top imperative route can retain an external/detail
                        // stack and a stale tab closure after a modal return.
                        if (activePath == target) return;
                        FocusManager.instance.primaryFocus?.unfocus();
                        context.go(target);
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

class _GlassQuickAdd extends StatelessWidget {
  const _GlassQuickAdd({super.key, required this.onTap, this.size = 62});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF08A6F7), Color(0xFF176CF5), Color(0xFF7048F6)],
          stops: [0, .56, 1],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? .55 : .92),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF126CF5).withValues(alpha: dark ? .38 : .30),
            blurRadius: 22,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF7048F6).withValues(alpha: dark ? .24 : .18),
            blurRadius: 16,
            spreadRadius: -6,
            offset: const Offset(7, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            tooltip: context.strings.text('Quick Add'),
            onPressed: onTap,
            icon: Icon(
              BilNavigationIcons.quickAdd(Theme.of(context).platform),
              key: const Key('shell-quick-add-icon'),
              color: Colors.white,
              size: size >= 60 ? 31 : 28,
            ),
          ),
          Positioned(
            top: size * .16,
            right: size * .14,
            child: ExcludeSemantics(
              child: Icon(
                Icons.auto_awesome_rounded,
                key: const Key('shell-quick-add-sparkle'),
                size: size * .17,
                color: Colors.white.withValues(alpha: .94),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
