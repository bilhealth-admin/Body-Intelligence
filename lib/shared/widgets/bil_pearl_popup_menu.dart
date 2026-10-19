import 'package:flutter/material.dart';

import '../../app/theme/bil_pearl_finish.dart';

/// Native popup positioning, focus, selection, cancellation and semantics.
/// Only each entry's backdrop uses the app's shared, opaque pearl gradient.
PopupMenuButton<T> bilPearlPopupMenuButton<T>({
  Key? key,
  required PopupMenuItemBuilder<T> itemBuilder,
  T? initialValue,
  VoidCallback? onOpened,
  PopupMenuItemSelected<T>? onSelected,
  PopupMenuCanceled? onCanceled,
  String? tooltip,
  double? elevation,
  Color? shadowColor,
  Color? surfaceTintColor,
  EdgeInsetsGeometry padding = const EdgeInsets.all(8),
  EdgeInsetsGeometry? menuPadding,
  Widget? child,
  BorderRadius? borderRadius,
  double? splashRadius,
  Widget? icon,
  double? iconSize,
  Offset offset = Offset.zero,
  bool enabled = true,
  ShapeBorder? shape,
  Color? color,
  Color? iconColor,
  bool? enableFeedback,
  BoxConstraints? constraints,
  PopupMenuPosition? position,
  Clip clipBehavior = Clip.antiAlias,
  bool useRootNavigator = false,
  AnimationStyle? popUpAnimationStyle,
  RouteSettings? routeSettings,
  ButtonStyle? style,
  bool? requestFocus,
}) => PopupMenuButton<T>(
  key: key,
  itemBuilder: (context) => [
    for (final entry in itemBuilder(context)) _PearlMenuEntry<T>(entry),
  ],
  initialValue: initialValue,
  onOpened: onOpened,
  onSelected: onSelected,
  onCanceled: onCanceled,
  tooltip: tooltip,
  elevation: elevation,
  shadowColor: shadowColor,
  surfaceTintColor: Colors.transparent,
  padding: padding,
  menuPadding: EdgeInsets.zero,
  borderRadius: borderRadius,
  splashRadius: splashRadius,
  icon: icon,
  iconSize: iconSize,
  offset: offset,
  enabled: enabled,
  shape: shape,
  color: Colors.transparent,
  iconColor: iconColor,
  enableFeedback: enableFeedback,
  constraints: constraints,
  position: position,
  clipBehavior: clipBehavior,
  useRootNavigator: useRootNavigator,
  popUpAnimationStyle: popUpAnimationStyle,
  routeSettings: routeSettings,
  style: style,
  requestFocus: requestFocus,
  child: child,
);

class _PearlMenuEntry<T> extends PopupMenuEntry<T> {
  const _PearlMenuEntry(this.entry);
  final PopupMenuEntry<T> entry;
  @override
  double get height => entry.height;
  @override
  bool represents(T? value) => entry.represents(value);
  @override
  State<_PearlMenuEntry<T>> createState() => _PearlMenuEntryState<T>();
}

class _PearlMenuEntryState<T> extends State<_PearlMenuEntry<T>> {
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Ink(
      decoration: BoxDecoration(
        gradient: BilPearlFinish.panel(context, shadow: false).gradient,
      ),
      child: widget.entry,
    ),
  );
}
