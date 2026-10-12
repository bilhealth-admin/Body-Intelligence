import 'package:flutter/material.dart';

final bilAppNavigatorKey = GlobalKey<NavigatorState>();
final bilStorePresentationRouteObserver = BilStorePresentationRouteObserver();

/// Respect another Flutter dialog/sheet. A confirmation never pops that route.
class BilStorePresentationRouteObserver extends NavigatorObserver {
  final changed = ValueNotifier<int>(0);
  final List<Route<dynamic>> _routes = [];
  bool get blocked {
    _routes.removeWhere((route) => route.navigator == null);
    return _routes.isNotEmpty && _routes.last is PopupRoute;
  }

  void _notify() => changed.value++;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _notify();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _notify();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _notify();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _notify();
  }
}
