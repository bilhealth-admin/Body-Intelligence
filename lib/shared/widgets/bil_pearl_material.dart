import 'package:flutter/material.dart';

import '../../app/theme/bil_pearl_finish.dart';

/// Uses Material's own sizing, scrolling, actions and accessibility unchanged.
/// Only the final dialog surface receives the shared pearl finish.
class BilPearlMaterialAlertDialog extends AlertDialog {
  const BilPearlMaterialAlertDialog({
    super.key,
    super.icon,
    super.iconPadding,
    super.iconColor,
    super.title,
    super.titlePadding,
    super.titleTextStyle,
    super.content,
    super.contentPadding,
    super.contentTextStyle,
    super.actions,
    super.actionsPadding,
    super.actionsAlignment,
    super.actionsOverflowAlignment,
    super.actionsOverflowDirection,
    super.actionsOverflowButtonSpacing,
    super.buttonPadding,
    super.backgroundColor,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.semanticLabel,
    super.insetPadding,
    super.clipBehavior,
    super.shape,
    super.alignment,
    super.constraints,
    super.scrollable,
  });

  @override
  Widget build(BuildContext context) =>
      _pearlDialog(context, super.build(context) as Dialog);
}

Dialog _pearlDialog(BuildContext context, Dialog original) => Dialog(
  backgroundColor: Colors.transparent,
  elevation: 0,
  surfaceTintColor: Colors.transparent,
  insetAnimationDuration: original.insetAnimationDuration,
  insetAnimationCurve: original.insetAnimationCurve,
  insetPadding: original.insetPadding,
  clipBehavior: original.clipBehavior,
  shape: original.shape,
  alignment: original.alignment,
  constraints: original.constraints,
  semanticsRole: original.semanticsRole,
  child: BilFrostedPanel(
    radius: original.shape is RoundedRectangleBorder
        ? (original.shape! as RoundedRectangleBorder).borderRadius.resolve(
            Directionality.of(context),
          )
        : const BorderRadius.all(Radius.circular(24)),
    child: original.child ?? const SizedBox.shrink(),
  ),
);

class BilPearlMaterialSimpleDialog extends SimpleDialog {
  const BilPearlMaterialSimpleDialog({
    super.key,
    super.title,
    super.titlePadding,
    super.titleTextStyle,
    super.children,
    super.contentPadding,
    super.contentTextStyle,
    super.backgroundColor,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.semanticLabel,
    super.insetPadding,
    super.clipBehavior,
    super.shape,
    super.alignment,
    super.constraints,
  });

  @override
  Widget build(BuildContext context) =>
      _pearlDialog(context, super.build(context) as Dialog);
}

class BilPearlMaterialDialog extends Dialog {
  const BilPearlMaterialDialog({
    super.key,
    super.backgroundColor,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.insetAnimationDuration,
    super.insetAnimationCurve,
    super.insetPadding,
    super.clipBehavior,
    super.shape,
    super.alignment,
    super.constraints,
    super.child,
    super.semanticsRole,
  });

  @override
  Widget build(BuildContext context) => _pearlDialog(context, this);
}

/// No backdrop filter per scrolling card. Ink keeps taps visible over the finish.
/// Explicit semantic/status colors stay intact; neutral surfaces share pearl.
class BilPearlMaterialCard extends Card {
  const BilPearlMaterialCard({
    super.key,
    super.color,
    super.shadowColor,
    super.surfaceTintColor,
    super.elevation,
    super.shape,
    super.borderOnForeground,
    super.margin,
    super.clipBehavior,
    super.child,
    super.semanticContainer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final neutral =
        color == null ||
        <Color>{
          Colors.white,
          Colors.transparent,
          scheme.surface,
          scheme.surfaceContainer,
          scheme.surfaceContainerLow,
          scheme.surfaceContainerLowest,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
        }.contains(color);
    final resolvedShape =
        shape ??
        theme.cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    return Card(
      color: neutral ? Colors.transparent : color,
      surfaceTintColor: Colors.transparent,
      elevation: elevation ?? 0,
      shadowColor: shadowColor,
      shape: resolvedShape,
      borderOnForeground: borderOnForeground,
      margin: margin,
      clipBehavior: clipBehavior,
      semanticContainer: semanticContainer,
      child: neutral
          ? Ink(
              decoration: ShapeDecoration(
                gradient: BilPearlFinish.panel(context).gradient,
                // Card owns the border. Ink must not add its dimensions again:
                // duplicate border padding shrinks compact action tiles.
                shape: resolvedShape is OutlinedBorder
                    ? resolvedShape.copyWith(side: BorderSide.none)
                    : resolvedShape,
              ),
              child: child,
            )
          : child,
    );
  }
}

/// Same native route options and navigator ownership as showModalBottomSheet.
/// Existing guarded presenters keep their own lifecycle/reentrancy rules.
Future<T?> showBilPearlBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  String? barrierLabel,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = false,
  double scrollControlDisabledMaxHeightRatio = 9 / 16,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  AnimationStyle? sheetAnimationStyle,
  bool? requestFocus,
}) => showModalBottomSheet<T>(
  context: context,
  builder: (context) {
    final content = builder(context);
    return content is BilFrostedPanel
        ? content
        : BilFrostedPanel(
            radius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: content,
          );
  },
  backgroundColor: Colors.transparent,
  barrierLabel: barrierLabel,
  elevation: elevation ?? 0,
  shape: shape,
  clipBehavior: clipBehavior,
  constraints: constraints,
  barrierColor: barrierColor,
  isScrollControlled: isScrollControlled,
  scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
  useRootNavigator: useRootNavigator,
  isDismissible: isDismissible,
  enableDrag: enableDrag,
  showDragHandle: showDragHandle,
  useSafeArea: useSafeArea,
  routeSettings: routeSettings,
  transitionAnimationController: transitionAnimationController,
  anchorPoint: anchorPoint,
  sheetAnimationStyle: sheetAnimationStyle,
  requestFocus: requestFocus,
);
