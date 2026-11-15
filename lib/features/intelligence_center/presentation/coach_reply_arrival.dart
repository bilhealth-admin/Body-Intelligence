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
    this.keepPlatformSurfaceComposed = false,
    super.key,
  });

  final String messageId;
  final bool animate;
  final Widget child;
  final VoidCallback? onPresentationReady;
  final bool keepPlatformSurfaceComposed;

  @override
  State<CoachReplyArrival> createState() => _CoachReplyArrivalState();
}

class _CoachReplyArrivalState extends State<CoachReplyArrival>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static final _animatedMessageIds = <String>{};

  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _platformOpacity;
  late final Animation<Offset> _position;
  String? _handledMessageId;
  String? _awaitingLayoutFor;
  int _layoutGeneration = 0;
  bool _awaitingFirstPaint = false;
  String? _lastMetricsSignature;
  String? _lastNonKeyboardMetricsSignature;
  Timer? _metricLayoutDebounce;
  String? _reportedVisibleFor;
  ({String messageId, int generation})? _queuedVisibilityNotice;

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
    // Alpha zero skips Flutter platform-view composition. UIKit already keeps
    // unmeasured native text at alpha zero until its geometry/owner gate opens.
    // One 8-bit alpha step keeps that surface composed during the same entrance
    // without exposing its text or adding another layout frame before creation.
    _platformOpacity = Tween<double>(begin: 1 / 255, end: 1).animate(_opacity);
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
        _reportedVisibleFor == widget.messageId ||
        _awaitingFirstPaint ||
        _opacity.value < .99) {
      return;
    }
    final notice = (messageId: widget.messageId, generation: _layoutGeneration);
    if (_queuedVisibilityNotice == notice) return;
    _queuedVisibilityNotice = notice;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A retired message must not clear or consume its replacement's notice.
      if (_queuedVisibilityNotice != notice) return;
      _queuedVisibilityNotice = null;
      if (!mounted ||
          widget.messageId != notice.messageId ||
          _layoutGeneration != notice.generation ||
          _awaitingFirstPaint ||
          _opacity.value < .99) {
        return;
      }
      if (_reportedVisibleFor != notice.messageId) {
        _reportedVisibleFor = notice.messageId;
        widget.onPresentationReady?.call();
      }
    });
    // Reduced motion can finish without a ticker or another widget rebuild.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lastMetricsSignature ??= _metricsSignature();
    _lastNonKeyboardMetricsSignature ??= _metricsSignature(
      includeKeyboardInset: false,
    );
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
    _lastMetricsSignature = signature;
    _lastNonKeyboardMetricsSignature = nonKeyboardSignature;
    if (previousSignature == null ||
        previousSignature == signature ||
        !_awaitingFirstPaint) {
      return;
    }

    // The viewport maintains the reading anchor while the IME opens or closes.
    // Restarting opacity on those metrics can keep a complete reply hidden
    // indefinitely, even though its text and first glyphs are already laid out.
    // Only an actual screen or safe-area change needs a fresh reading layout.
    if (previousNonKeyboardSignature == nonKeyboardSignature) {
      return;
    }

    // Coalesce actual screen and safe-area changes for the reading layout.
    // Keyboard-only metrics above retain the existing entrance instead.
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
      // A post-frame callback alone cannot wake an idle pipeline after the
      // entrance was paused. Request the layout frame this gate waits for.
      WidgetsBinding.instance.ensureVisualUpdate();
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
        _noticeVisibleAfterPaint();
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
    _queuedVisibilityNotice = null;
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
      opacity: widget.keepPlatformSurfaceComposed ? _platformOpacity : _opacity,
      child: SlideTransition(position: _position, child: widget.child),
    );
  }
}
