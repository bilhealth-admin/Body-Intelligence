import 'package:flutter/material.dart';

/// Gives a newly received Coach reply a short, stable, cloud-soft entrance.
///
/// The complete, already-validated reply is present in the first layout frame;
/// only its opacity and a few pixels of vertical position are animated. This
/// avoids the repeated text-layout changes that made older Coach replies jump.
class CoachReplyArrival extends StatefulWidget {
  const CoachReplyArrival({
    required this.messageId,
    required this.animate,
    required this.child,
    super.key,
  });

  final String messageId;
  final bool animate;
  final Widget child;

  @override
  State<CoachReplyArrival> createState() => _CoachReplyArrivalState();
}

class _CoachReplyArrivalState extends State<CoachReplyArrival>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static final _animatedMessageIds = <String>{};

  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;
  String? _handledMessageId;
  String? _awaitingLayoutFor;
  int _layoutGeneration = 0;
  bool _awaitingFirstPaint = false;

  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.animate ? 0 : 1,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _position = Tween<Offset>(
      begin: const Offset(0, .008),
      end: Offset.zero,
    ).animate(_opacity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionPreference();
  }

  @override
  void didUpdateWidget(covariant CoachReplyArrival oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId ||
        oldWidget.animate != widget.animate) {
      _handledMessageId = null;
      _awaitingLayoutFor = null;
      _awaitingFirstPaint = false;
      _layoutGeneration++;
      _controller.value = widget.animate ? 0 : 1;
      _syncMotionPreference();
    }
  }

  @override
  void didChangeAccessibilityFeatures() => _syncMotionPreference();

  @override
  void didChangeMetrics() {
    if (!mounted || !_awaitingFirstPaint) return;
    // IME metrics can arrive after the old reading offset was measured but
    // before the first positive-opacity frame. Keep that frame transparent
    // until the viewport's post-layout pin has been laid out at the new size.
    // Once any entrance frame has painted, never restart or hide the reply.
    _waitForReadingLayout();
  }

  void _waitForReadingLayout() {
    final messageId = widget.messageId;
    final generation = ++_layoutGeneration;
    _awaitingLayoutFor = messageId;
    _awaitingFirstPaint = true;
    _controller.stop();
    _controller.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _layoutGeneration ||
          _awaitingLayoutFor != messageId) {
        return;
      }
      _awaitingLayoutFor = null;
      if (_reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
      _observeFirstPaint(generation);
    });
  }

  void _observeFirstPaint(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _layoutGeneration) return;
      if (_opacity.value > 0) {
        _awaitingFirstPaint = false;
      } else {
        _observeFirstPaint(generation);
      }
    });
  }

  void _syncMotionPreference() {
    if (_reduceMotion) {
      if (_awaitingLayoutFor == widget.messageId) return;
      final firstLayout =
          widget.animate &&
          _handledMessageId != widget.messageId &&
          _animatedMessageIds.add(widget.messageId);
      _controller.stop();
      _handledMessageId = widget.messageId;
      if (!firstLayout && !_awaitingFirstPaint) {
        _controller.value = 1;
        return;
      }
      // The reversed viewport measures a long reply's reading start during
      // its first layout. Skip motion, but let that anchor settle before
      // painting; otherwise reduced motion briefly exposes the reply's end.
      _waitForReadingLayout();
      return;
    }
    if (_handledMessageId == widget.messageId) return;
    _handledMessageId = widget.messageId;
    if (widget.animate && _animatedMessageIds.add(widget.messageId)) {
      // Keep the established 320ms entrance when layout is stable. Only an
      // actual metric change before its first paint needs the layout gate.
      _awaitingFirstPaint = true;
      _controller.forward(from: 0);
      _observeFirstPaint(++_layoutGeneration);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    key: ValueKey('coach-reply-arrival-fade-${widget.messageId}'),
    alwaysIncludeSemantics: true,
    opacity: _opacity,
    child: SlideTransition(position: _position, child: widget.child),
  );
}
