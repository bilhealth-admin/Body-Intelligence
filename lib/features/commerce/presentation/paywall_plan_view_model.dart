import '../domain/commerce_plan.dart';

/// Presentation-only projection for one plan shown by the commerce paywall.
///
/// This model intentionally carries stable identifiers and display-ready copy,
/// while access checks remain entitlement-driven outside the UI layer.
final class PaywallPlanViewModel {
  PaywallPlanViewModel({
    required this.plan,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.billingPeriodLabel,
    required List<String> highlights,
    required this.isCurrent,
    required this.isRecommended,
    required this.isEligible,
    this.ineligibilityReason,
  }) : highlights = List.unmodifiable(highlights) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (priceLabel.trim().isEmpty) {
      throw ArgumentError.value(priceLabel, 'priceLabel', 'must not be empty');
    }
    if (!isEligible &&
        (ineligibilityReason == null || ineligibilityReason!.trim().isEmpty)) {
      throw ArgumentError(
        'An ineligible plan must explain why it is unavailable.',
      );
    }
  }

  final CommercePlan plan;
  final String title;
  final String subtitle;
  final String priceLabel;
  final String billingPeriodLabel;
  final List<String> highlights;
  final bool isCurrent;
  final bool isRecommended;
  final bool isEligible;
  final String? ineligibilityReason;

  bool get canSelect => isEligible && !isCurrent;
}
