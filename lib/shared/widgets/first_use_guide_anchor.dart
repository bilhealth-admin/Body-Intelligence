import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A shell-local anchor. It neither stores an account nor owns meal data.
class FirstUseGuideAnchor {
  final link = LayerLink();
  VoidCallback? startFoodGuide;

  static FirstUseGuideAnchor? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AnchorScope>()?.anchor;
}

class FirstUseGuideAnchorHost extends StatefulWidget {
  const FirstUseGuideAnchorHost({super.key, required this.builder});
  final Widget Function(BuildContext, FirstUseGuideAnchor) builder;
  @override
  State<FirstUseGuideAnchorHost> createState() => _AnchorHostState();
}

class _AnchorHostState extends State<FirstUseGuideAnchorHost> {
  final anchor = FirstUseGuideAnchor();
  @override
  Widget build(BuildContext context) => _AnchorScope(
    anchor: anchor,
    child: Builder(builder: (context) => widget.builder(context, anchor)),
  );
}

class _AnchorScope extends InheritedWidget {
  const _AnchorScope({required this.anchor, required super.child});
  final FirstUseGuideAnchor anchor;
  @override
  bool updateShouldNotify(_AnchorScope oldWidget) => oldWidget.anchor != anchor;
}

/// Follows the real Quick Add target without moving the Home content.
/// The bubble alone accepts taps; navigation and the rest of Home stay usable.
class FirstUseAnchoredGuide extends StatefulWidget {
  const FirstUseAnchoredGuide({
    super.key,
    required this.anchor,
    required this.onStart,
    required this.guide,
    required this.child,
  });
  final FirstUseGuideAnchor anchor;
  final VoidCallback onStart;
  final Widget guide;
  final Widget child;
  @override
  State<FirstUseAnchoredGuide> createState() => _AnchoredGuideState();
}

class _AnchoredGuideState extends State<FirstUseAnchoredGuide> {
  final portal = OverlayPortalController();
  void start() => widget.onStart();
  @override
  void initState() {
    super.initState();
    widget.anchor.startFoodGuide = start;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) portal.show();
    });
  }

  @override
  void didUpdateWidget(FirstUseAnchoredGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchor != widget.anchor) {
      if (oldWidget.anchor.startFoodGuide == start) {
        oldWidget.anchor.startFoodGuide = null;
      }
      widget.anchor.startFoodGuide = start;
    }
  }

  @override
  void dispose() {
    if (widget.anchor.startFoodGuide == start) {
      widget.anchor.startFoodGuide = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    overlayLocation: OverlayChildLocation.rootOverlay,
    controller: portal,
    overlayChildBuilder: (context) {
      final media = MediaQuery.of(context);
      return Positioned(
        top: 0,
        left: 0,
        width: math.min(360, media.size.width - 32),
        child: CompositedTransformFollower(
          link: widget.anchor.link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -12),
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: SizedBox(
              width: math.min(360, media.size.width - 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(
                    120,
                    media.size.height -
                        media.padding.vertical -
                        media.viewInsets.bottom -
                        130,
                  ),
                ),
                child: SingleChildScrollView(child: widget.guide),
              ),
            ),
          ),
        ),
      );
    },
    child: widget.child,
  );
}
