import 'package:flutter/material.dart';

import '../../../app/theme/premium_motion_tokens.dart';

/// A calm, accessibility-aware entrance for the composed Dashboard experience.
///
/// The child remains fully laid out for semantics and measurement. When the
/// platform requests reduced motion, the animation is skipped completely.
class DashboardMotionReveal extends StatefulWidget {
  const DashboardMotionReveal({super.key, required this.child});

  final Widget child;

  @override
  State<DashboardMotionReveal> createState() => _DashboardMotionRevealState();
}

class _DashboardMotionRevealState extends State<DashboardMotionReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PremiumMotionTokens.dashboardEntranceDuration,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: PremiumMotionTokens.dashboardEntranceCurve,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _offset = Tween<Offset>(
      begin: PremiumMotionTokens.dashboardEntranceOffset,
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (PremiumMotionTokens.prefersReducedMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
