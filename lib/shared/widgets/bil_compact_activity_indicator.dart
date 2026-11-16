import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The segmented iOS wait used by pending operations on every platform.
/// Its fixed footprint and reduced-motion state never imply real completion.
class BilCompactActivityIndicator extends StatefulWidget {
  const BilCompactActivityIndicator({super.key, this.color, this.label});

  /// Compatibility alias: data operations always use the same neutral wait.
  const BilCompactActivityIndicator.dashboard({
    super.key,
    this.color,
    this.label,
  });

  final Color? color;
  final String? label;

  @override
  State<BilCompactActivityIndicator> createState() =>
      _BilCompactActivityIndicatorState();
}

class _BilCompactActivityIndicatorState
    extends State<BilCompactActivityIndicator>
    with WidgetsBindingObserver {
  Color _segmentedColor(BuildContext context) {
    final requested = widget.color;
    if (requested != null) {
      final argb = requested.toARGB32();
      final channels = [(argb >> 16) & 255, (argb >> 8) & 255, argb & 255];
      final spread = channels.reduce(math.max) - channels.reduce(math.min);
      // Preserve a visible neutral wait on callers' filled primary surfaces.
      // Historical chromatic colors never turn operation waits blue again.
      if (spread <= 32 && requested.computeLuminance() >= 0.6) {
        return const Color(0xFFE5E7EB);
      }
    }
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFBBC4CD)
        : const Color(0xFF697178);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    role: ui.SemanticsRole.loadingSpinner,
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: 24,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: CupertinoActivityIndicator(
            radius: 12,
            color: _segmentedColor(context),
            animating:
                !MediaQuery.disableAnimationsOf(context) &&
                !View.of(
                  context,
                ).platformDispatcher.accessibilityFeatures.reduceMotion,
          ),
        ),
      ),
    ),
  );
}
