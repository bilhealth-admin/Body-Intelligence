import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final bilRootNavigationFocusObserver = BilNavigationFocusObserver();
final bilShellNavigationFocusObserver = BilNavigationFocusObserver();

/// Retire the outgoing input connection before a new route acquires focus.
/// No delayed callbacks: a destination's own autofocus remains usable.
class BilNavigationFocusObserver extends RouteObserver<ModalRoute<dynamic>> {
  void _dismissInput() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissInput();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissInput();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _dismissInput();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
