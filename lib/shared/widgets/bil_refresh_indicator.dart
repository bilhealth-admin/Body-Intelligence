import 'package:flutter/material.dart';

import 'bil_pearl_feature_welcome.dart';

/// Keeps Flutter's real refresh gesture and single in-flight callback, while
/// showing the same waiting glyph as BIL's Splash instead of Material's spinner.
class BilRefreshIndicator extends StatefulWidget {
  const BilRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final Widget child;
  final RefreshCallback onRefresh;
  final ScrollNotificationPredicate notificationPredicate;
  final RefreshIndicatorTriggerMode triggerMode;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  State<BilRefreshIndicator> createState() => _BilRefreshIndicatorState();
}

class _BilRefreshIndicatorState extends State<BilRefreshIndicator> {
  RefreshIndicatorStatus? _status;

  void _onStatusChange(RefreshIndicatorStatus? status) {
    if (mounted && status != _status) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      RefreshIndicator.noSpinner(
        onRefresh: widget.onRefresh,
        onStatusChange: _onStatusChange,
        notificationPredicate: widget.notificationPredicate,
        triggerMode: widget.triggerMode,
        semanticsLabel: widget.semanticsLabel,
        semanticsValue: widget.semanticsValue,
        child: widget.child,
      ),
      // The SDK emits done/canceled, but does not emit null after dismissal.
      // Hide at completion instead of leaving an animated glyph indefinitely.
      if (_status != null &&
          _status != RefreshIndicatorStatus.canceled &&
          _status != RefreshIndicatorStatus.done)
        Positioned(
          top: 28,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Semantics(
                value: widget.semanticsValue,
                child: SizedBox.square(
                  dimension: 24,
                  child: BilFeatureWelcomeStatus(
                    label:
                        widget.semanticsLabel ??
                        MaterialLocalizations.of(
                          context,
                        ).refreshIndicatorSemanticLabel,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
