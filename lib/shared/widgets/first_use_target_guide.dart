import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An optional guide follows the real control without changing its layout.
/// The overlay occupies only the bubble; its target remains directly usable.
class FirstUseTargetGuide extends StatefulWidget {
  const FirstUseTargetGuide({
    super.key,
    required this.child,
    this.guide,
    this.preferBelow = true,
  });

  final Widget child;
  final Widget? guide;
  final bool preferBelow;

  @override
  State<FirstUseTargetGuide> createState() => _FirstUseTargetGuideState();
}

class _FirstUseTargetGuideState extends State<FirstUseTargetGuide> {
  final _target = GlobalKey();
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  void _sync() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (widget.guide == null) {
      _portal.hide();
    } else {
      _portal.show();
    }
  });

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(FirstUseTargetGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: (overlayContext) {
      final box = _target.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || widget.guide == null) {
        return const SizedBox.shrink();
      }
      final media = MediaQuery.of(overlayContext);
      final overlay = Overlay.of(overlayContext).context.findRenderObject();
      final position = box.localToGlobal(Offset.zero, ancestor: overlay);
      final width = math.min(340.0, media.size.width - 24);
      final top = media.padding.top + 8;
      final bottom = media.size.height - media.viewInsets.bottom - 8;
      final above = math.max(0.0, position.dy - top - 8);
      final below = math.max(0.0, bottom - position.dy - box.size.height - 8);
      final useBelow = widget.preferBelow
          ? below >= 180 || below >= above
          : above < 180 && below > above;
      final left = (position.dx + box.size.width / 2 - width / 2).clamp(
        12.0,
        math.max(12.0, media.size.width - width - 12),
      );
      final height = math.max(48.0, useBelow ? below : above);
      return Positioned(
        left: 0,
        top: 0,
        width: width,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: useBelow ? Alignment.bottomLeft : Alignment.topLeft,
          followerAnchor: useBelow ? Alignment.topLeft : Alignment.bottomLeft,
          offset: Offset(left - position.dx, useBelow ? 8 : -8),
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height),
              child: SingleChildScrollView(
                child: FirstUseGuidePlacement(
                  below: useBelow,
                  pointerAlignment: Alignment(
                    ((position.dx + box.size.width / 2 - left) / width * 2 - 1)
                        .clamp(-.88, .88),
                    0,
                  ),
                  child: widget.guide!,
                ),
              ),
            ),
          ),
        ),
      );
    },
    child: CompositedTransformTarget(
      key: _target,
      link: _link,
      child: widget.child,
    ),
  );
}

class FirstUseGuidePlacement extends InheritedWidget {
  const FirstUseGuidePlacement({
    super.key,
    required this.below,
    required this.pointerAlignment,
    required super.child,
  });
  final bool below;
  final Alignment pointerAlignment;
  static FirstUseGuidePlacement? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FirstUseGuidePlacement>();
  static bool belowOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FirstUseGuidePlacement>()
          ?.below ??
      false;
  @override
  bool updateShouldNotify(FirstUseGuidePlacement oldWidget) =>
      below != oldWidget.below ||
      pointerAlignment != oldWidget.pointerAlignment;
}
