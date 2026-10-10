part of 'analytics_page.dart';

/// Presentation-only confidence copy, separate from chart and data states.
String _localizedProgressConfidence(
  BuildContext context,
  ProgressConfidence confidence,
) {
  return analyticsText(context, confidence.name, switch (confidence) {
    ProgressConfidence.insufficient => 'غير كافية',
    ProgressConfidence.low => 'منخفضة',
    ProgressConfidence.medium => 'متوسطة',
    ProgressConfidence.high => 'مرتفعة',
  });
}
