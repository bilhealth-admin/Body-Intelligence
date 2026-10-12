import 'dart:async';

import 'package:flutter/material.dart';

/// Own externally supplied text controllers until the dialog overlay is gone.
/// A pop result is available before the reverse animation finishes; disposing
/// on that result (or after one frame) leaves closing TextFields using dead
/// controllers. Saving can start immediately, independently of decoration.
Future<T?> showBilControllerDialog<T>({
  required BuildContext context,
  required Iterable<TextEditingController> controllers,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  final owned = List<TextEditingController>.of(controllers);
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    barrierColor:
        DialogTheme.of(context).barrierColor ??
        Theme.of(context).dialogTheme.barrierColor ??
        Colors.black54,
    barrierDismissible: barrierDismissible,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  void retire() {
    for (final controller in owned) {
      controller.dispose();
    }
  }

  var installed = false;
  try {
    final result = navigator.push(route);
    installed = true;
    return await result;
  } finally {
    if (installed) {
      unawaited(route.completed.then((_) => retire()));
    } else {
      retire();
    }
  }
}
