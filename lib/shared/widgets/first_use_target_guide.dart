import 'package:flutter/material.dart';
import 'first_use_spotlight.dart';
export 'first_use_spotlight.dart' show FirstUseGuidePlacement;

/// Tracks the actual target, including keyboard changes and parent scrolling.
class FirstUseTargetGuide extends StatefulWidget {
  const FirstUseTargetGuide({
    super.key,
    required this.child,
    this.guide,
    this.preferBelow = true,
    this.focusTarget,
    this.onTargetActivated,
  });
  final Widget child;
  final Widget? guide;
  final bool preferBelow;
  final GlobalKey? focusTarget;
  final VoidCallback? onTargetActivated;
  @override
  State<FirstUseTargetGuide> createState() => _FirstUseTargetGuideState();
}

class _FirstUseTargetGuideState extends State<FirstUseTargetGuide>
    with WidgetsBindingObserver {
  final _target = GlobalKey();
  final _portal = OverlayPortalController();
  ScrollPosition? _scroll;
  Animation<double>? _routeAnimation;
  bool _scheduled = false;
  bool _tracking = false;
  Rect? _lastTarget;

  void _trackPosition(Duration timeStamp) {
    if (!mounted || widget.guide == null) {
      _tracking = false;
      return;
    }
    final box = (widget.focusTarget ?? _target).currentContext
        ?.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect != _lastTarget) {
        _lastTarget = rect;
        setState(() {});
      }
    }
    // Observe frames scheduled by scrolling, route or keyboard animations.
    // Do not schedule animation frames of our own when the target is stationary.
    WidgetsBinding.instance.addPostFrameCallback(_trackPosition);
  }

  void _sync() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      if (widget.guide == null) {
        _portal.hide();
      } else {
        _portal.show();
        setState(() {});
        if (!_tracking) {
          _tracking = true;
          WidgetsBinding.instance.addPostFrameCallback(_trackPosition);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation != _routeAnimation) {
      _routeAnimation?.removeListener(_sync);
      _routeAnimation = animation;
      _routeAnimation?.addListener(_sync);
    }
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_sync);
      _scroll = scroll;
      _scroll?.addListener(_sync);
    }
    _sync();
  }

  @override
  void didChangeMetrics() => _sync();
  @override
  void didUpdateWidget(FirstUseTargetGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _scroll?.removeListener(_sync);
    _routeAnimation?.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    overlayLocation: OverlayChildLocation.rootOverlay,
    controller: _portal,
    overlayChildBuilder: (_) => widget.guide == null
        ? const SizedBox.shrink()
        : FirstUseSpotlight(
            target: widget.focusTarget ?? _target,
            guide: widget.guide!,
            preferBelow: widget.preferBelow,
            onTargetActivated: widget.onTargetActivated,
          ),
    child: SizedBox(key: _target, child: widget.child),
  );
}
