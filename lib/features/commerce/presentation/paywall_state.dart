import 'paywall_plan_view_model.dart';

/// Immutable local paywall state.
final class PaywallState {
  PaywallState({
    required List<PaywallPlanViewModel> plans,
    required this.isRestoring,
    required this.isPurchasing,
    this.selectedPlanId,
    this.message,
  }) : plans = List.unmodifiable(plans) {
    if (isRestoring && isPurchasing) {
      throw ArgumentError('Restore and purchase cannot run concurrently.');
    }
  }

  final List<PaywallPlanViewModel> plans;
  final bool isRestoring;
  final bool isPurchasing;
  final String? selectedPlanId;
  final String? message;

  bool get isBusy => isRestoring || isPurchasing;
}
