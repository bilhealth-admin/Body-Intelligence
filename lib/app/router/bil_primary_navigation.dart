import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/bil_reference_bottom_bar.dart';

/// A stable, route-specific page identity prevents a pageless detail from
/// remaining attached when two no-transition destinations replace each other.
NoTransitionPage<T> bilNoTransitionPage<T>({
  required GoRouterState state,
  required Widget child,
}) => NoTransitionPage<T>(key: state.pageKey, child: child);

/// Primary navigation is an escape destination, not an account mutation.
/// Retire legacy Navigator.push details before selecting the canonical route,
/// including when its URI is already selected underneath a detail page.
void bilSelectPrimaryTab(BuildContext context, int index) {
  if (index < 0 || index >= BilReferenceBottomBar.routes.length || index == 2) {
    throw ArgumentError.value(index, 'index', 'Quick Add is a separate action');
  }
  bilSelectPrimaryRoute(context, BilReferenceBottomBar.routes[index]);
}

/// Select an app-owned primary route while retiring active pageless details.
/// The wide shell keeps its existing destination and origin query parameters.
void bilSelectPrimaryRoute(BuildContext context, String location) {
  final router = GoRouter.of(context);
  final navigators = <NavigatorState>[];
  final contextualNavigator = Navigator.maybeOf(context);
  if (contextualNavigator != null) {
    navigators.add(contextualNavigator);
  }

  // The dock is built outside the shell's child Navigator. Its BuildContext
  // therefore resolves to the root, while a legacy detail may sit inside the
  // active shell. On a same-tab selection go() alone leaves that detail up.
  // Walk only the active match branch, never offstage historical shells.
  var activeMatches = router.routerDelegate.currentConfiguration.matches;
  while (activeMatches.isNotEmpty && activeMatches.last is ShellRouteMatch) {
    final shell = activeMatches.last as ShellRouteMatch;
    final navigator = shell.navigatorKey.currentState;
    if (navigator != null && !navigators.contains(navigator)) {
      navigators.add(navigator);
    }
    activeMatches = shell.matches;
  }
  FocusManager.instance.primaryFocus?.unfocus();
  for (final navigator in navigators.reversed) {
    var vetoed = false;
    // Never imperatively pop a GoRouter page or bypass its route contract.
    navigator.popUntil((route) {
      if (route.settings is Page || route.isFirst) {
        return true;
      }
      if (route.popDisposition == RoutePopDisposition.doNotPop) {
        vetoed = true;
        return true;
      }
      return false;
    });
    // A pending save in a nested legacy detail must not be discarded merely
    // because the primary selector lives outside that detail's Navigator.
    if (vetoed) {
      return;
    }
  }
  router.go(location);
}
