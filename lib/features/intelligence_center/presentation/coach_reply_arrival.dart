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
      _controller.value = widget.animate ? 0 : 1;
      _syncMotionPreference();
    }
  }

  @override
  void didChangeAccessibilityFeatures() => _syncMotionPreference();

  void _syncMotionPreference() {
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;
    if (reduceMotion) {
      _controller.value = 1;
      _handledMessageId = widget.messageId;
      return;
    }
    if (_handledMessageId == widget.messageId) return;
    _handledMessageId = widget.messageId;
    if (widget.animate && _animatedMessageIds.add(widget.messageId)) {
      _controller.forward(from: 0);
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
