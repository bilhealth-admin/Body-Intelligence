import 'package:flutter/material.dart';
import '../../app/theme/bil_pearl_finish.dart';

final _activeBilSheets = Expando<bool>('active-bil-sheet');

/// Completes only after the modal overlay has actually left the navigator.
/// Navigator.push/showModalBottomSheet complete at pop, before reverse animation.
/// Starting another route in that interval can strand a barrier on iOS.
Future<T?> showBilModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool? showDragHandle,
  Color? backgroundColor,
  BoxConstraints? constraints,
  AnimationStyle? sheetAnimationStyle,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (_activeBilSheets[navigator] == true) return null;
  _activeBilSheets[navigator] = true;
  try {
    final route = ModalBottomSheetRoute<T>(
      builder: (context) => backgroundColor == null
          ? BilFrostedPanel(
              radius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: builder(context),
            )
          : builder(context),
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor ?? Colors.transparent,
      constraints: constraints,
      sheetAnimationStyle: sheetAnimationStyle,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      modalBarrierColor:
          Theme.of(context).bottomSheetTheme.modalBarrierColor ??
          Colors.black54,
      isDismissible: true,
      enableDrag: true,
    );
    final selection = await navigator.push(route);
    await route.completed;
    return selection;
  } finally {
    _activeBilSheets[navigator] = false;
  }
}
