import 'first_use_target_guide.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A shell-local anchor. It neither stores an account nor owns meal data.
class FirstUseGuideAnchor {
  final link = LayerLink();
  final target = GlobalKey();
  VoidCallback? startFoodGuide;
  VoidCallback? openMenu;
  VoidCallback? skipFoodGuide;
  final menuOpen = ValueNotifier<bool>(false);

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
    this.onSkip,
    required this.guide,
    required this.child,
  });
  final FirstUseGuideAnchor anchor;
  final VoidCallback onStart;
  final VoidCallback? onSkip;
  final Widget guide;
  final Widget child;
  @override
  State<FirstUseAnchoredGuide> createState() => _AnchoredGuideState();
}

class _AnchoredGuideState extends State<FirstUseAnchoredGuide> {
  final portal = OverlayPortalController();
  void menuChanged() {
    if (!mounted) return;
    if (widget.anchor.menuOpen.value) {
      portal.hide();
    } else {
      portal.show();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.anchor.menuOpen.addListener(menuChanged);
    widget.anchor.startFoodGuide = widget.onStart;
    widget.anchor.skipFoodGuide = widget.onSkip;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.anchor.menuOpen.value) portal.show();
    });
  }

  @override
  void didUpdateWidget(FirstUseAnchoredGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchor != widget.anchor) {
      oldWidget.anchor.menuOpen.removeListener(menuChanged);
      oldWidget.anchor.startFoodGuide = null;
      oldWidget.anchor.skipFoodGuide = null;
      widget.anchor.menuOpen.addListener(menuChanged);
    }
    widget.anchor.startFoodGuide = widget.onStart;
    widget.anchor.skipFoodGuide = widget.onSkip;
  }

  @override
  void dispose() {
    if (widget.anchor.startFoodGuide == widget.onStart) {
      widget.anchor.startFoodGuide = null;
    }
    widget.anchor.menuOpen.removeListener(menuChanged);
    widget.anchor.skipFoodGuide = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    overlayLocation: OverlayChildLocation.rootOverlay,
    controller: portal,
    overlayChildBuilder: (context) {
      final media = MediaQuery.of(context);
      final width = math.min(360.0, media.size.width - 32);
      final target = widget.anchor.target.currentContext?.findRenderObject();
      final overlay = Overlay.of(
        context,
        rootOverlay: true,
      ).context.findRenderObject();
      if (target is! RenderBox || !target.hasSize)
        return const SizedBox.shrink();
      final position = target.localToGlobal(Offset.zero, ancestor: overlay);
      final center = position.dx + target.size.width / 2;
      final left = (center - width / 2).clamp(
        16.0,
        media.size.width - width - 16,
      );
      return Positioned(
        top: 0,
        left: 0,
        width: math.min(360, media.size.width - 32),
        child: CompositedTransformFollower(
          link: widget.anchor.link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: Offset(left + width / 2 - center, -12),
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
                    position.dy - media.padding.top - 12,
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: SingleChildScrollView(
                    child: FirstUseGuidePlacement(
                      below: false,
                      pointerAlignment: Alignment(
                        ((center - left) / width * 2 - 1).clamp(-.88, .88),
                        0,
                      ),
                      child: widget.guide,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    child: widget.child,
  );
}
