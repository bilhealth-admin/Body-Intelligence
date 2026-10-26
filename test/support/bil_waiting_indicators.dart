import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

export 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart'
    show BilFeatureWelcomeStatus;

/// Waiting only: determinate nutrition/session/progress values are excluded.
/// Include legacy waiting widgets so negative assertions cannot pass vacuously
/// if an old widget accidentally returns. Positive tests require the BIL class.
Finder bilWaitingIndicators() => find.byWidgetPredicate(
  (widget) =>
      widget is BilFeatureWelcomeStatus ||
      (widget is CircularProgressIndicator && widget.value == null) ||
      (widget is LinearProgressIndicator && widget.value == null),
  description: 'BIL or legacy indeterminate waiting indicator',
);
