import 'dart:async';

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
    this.onPresentationReady,
    super.key,
  });

  final String messageId;
  final bool animate;
  final Widget child;
  final VoidCallback? onPresentationReady;

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
  String? _lastMetricsSignature;
  String? _lastNonKeyboardMetricsSignature;
  double? _lastKeyboardInset;
  Timer? _metricLayoutDebounce;
  String? _reportedVisibleFor;
  bool _visibilityNoticeQueued = false;

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
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _noticeVisibleAfterPaint();
    });
  }

  void _noticeVisibleAfterPaint() {
    if (widget.onPresentationReady == null ||
        _visibilityNoticeQueued ||
        _reportedVisibleFor == widget.messageId) {
      return;
    }
    _visibilityNoticeQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityNoticeQueued = false;
      if (!mounted || _awaitingFirstPaint || _opacity.value < .99) {
        return;
      }
      if (_reportedVisibleFor != widget.messageId) {
        _reportedVisibleFor = widget.messageId;
        widget.onPresentationReady?.call();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lastMetricsSignature ??= _metricsSignature();
    _lastNonKeyboardMetricsSignature ??= _metricsSignature(
      includeKeyboardInset: false,
    );
    _lastKeyboardInset ??= View.of(context).viewInsets.bottom;
    _syncMotionPreference();
  }

  @override
  void didUpdateWidget(covariant CoachReplyArrival oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId ||
        oldWidget.animate != widget.animate) {
      _metricLayoutDebounce?.cancel();
      _metricLayoutDebounce = null;
      _handledMessageId = null;
      _reportedVisibleFor = null;
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
    if (!mounted) return;
    final signature = _metricsSignature();
    final previousSignature = _lastMetricsSignature;
    final nonKeyboardSignature = _metricsSignature(includeKeyboardInset: false);
    final previousNonKeyboardSignature = _lastNonKeyboardMetricsSignature;
    final keyboardInset = View.of(context).viewInsets.bottom;
    final previousKeyboardInset = _lastKeyboardInset;
    _lastMetricsSignature = signature;
    _lastNonKeyboardMetricsSignature = nonKeyboardSignature;
    _lastKeyboardInset = keyboardInset;
    if (previousSignature == null ||
        previousSignature == signature ||
        !_awaitingFirstPaint) {
      return;
    }

    // A retracting IME expands the existing reading viewport. Restarting the
    // fade on every closing frame can keep a fully laid-out reply transparent,
    // especially when native debug frames are slow. Keep the current entrance;
    // genuine viewport contractions and other geometry changes still re-gate.
    if (previousNonKeyboardSignature == nonKeyboardSignature &&
        previousKeyboardInset != null &&
        keyboardInset < previousKeyboardInset) {
      return;
    }

    // Only real viewport changes restart the entrance. Duplicate native
    // notifications are ignored; changing IME metrics are coalesced until the
    // viewport has been quiet long enough to lay out the reading anchor.
    _scheduleMetricLayoutGate();
  }

  String _metricsSignature({bool includeKeyboardInset = true}) {
    final view = View.of(context);
    final size = view.physicalSize;
    final insets = view.viewInsets;
    // Computed padding changes as the keyboard consumes the bottom safe area.
    // Only raw viewPadding distinguishes a real safe-area change from IME motion.
    final padding = includeKeyboardInset ? view.padding : view.viewPadding;
    return <double>[
      view.devicePixelRatio,
      size.width,
      size.height,
      insets.left,
      insets.top,
      insets.right,
      if (includeKeyboardInset) insets.bottom,
      padding.left,
      padding.top,
      padding.right,
      padding.bottom,
    ].join('|');
  }

  void _scheduleMetricLayoutGate() {
    final messageId = widget.messageId;
    final generation = ++_layoutGeneration;
    _awaitingLayoutFor = messageId;
    _awaitingFirstPaint = true;
    _controller.stop();
    _controller.value = 0;
    _metricLayoutDebounce?.cancel();
    _metricLayoutDebounce = Timer(const Duration(milliseconds: 64), () {
      _metricLayoutDebounce = null;
      if (!mounted ||
          generation != _layoutGeneration ||
          _awaitingLayoutFor != messageId) {
        return;
      }
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
    });
  }

  void _waitForReadingLayout() {
    _metricLayoutDebounce?.cancel();
    _metricLayoutDebounce = null;
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
    _metricLayoutDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _noticeVisibleAfterPaint();
    return FadeTransition(
      key: ValueKey('coach-reply-arrival-fade-${widget.messageId}'),
      alwaysIncludeSemantics: true,
      opacity: _opacity,
      child: SlideTransition(position: _position, child: widget.child),
    );
  }
}
