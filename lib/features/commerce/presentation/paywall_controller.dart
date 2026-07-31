import 'paywall_plan_view_model.dart';
import 'paywall_state.dart';

/// Deterministic UI controller boundary for the future commerce paywall.
///
/// It does not perform purchases, restore receipts, or call a network. Instead,
/// it validates local UI intent and emits commands through explicit callbacks.
final class PaywallController {
  PaywallController({required PaywallState initialState})
    : _state = initialState;

  PaywallState _state;

  PaywallState get state => _state;

  PaywallPlanViewModel? select(String planId) {
    if (_state.isBusy) {
      return null;
    }
    for (final plan in _state.plans) {
      if (plan.plan.name == planId) {
        if (!plan.canSelect) {
          return null;
        }
        _state = PaywallState(
          plans: _state.plans,
          isRestoring: false,
          isPurchasing: false,
          selectedPlanId: planId,
          message: null,
        );
        return plan;
      }
    }
    return null;
  }

  void beginPurchase() {
    if (_state.selectedPlanId == null || _state.isBusy) {
      return;
    }
    _state = PaywallState(
      plans: _state.plans,
      isRestoring: false,
      isPurchasing: true,
      selectedPlanId: _state.selectedPlanId,
      message: null,
    );
  }

  void beginRestore() {
    if (_state.isBusy) {
      return;
    }
    _state = PaywallState(
      plans: _state.plans,
      isRestoring: true,
      isPurchasing: false,
      selectedPlanId: _state.selectedPlanId,
      message: null,
    );
  }

  void complete({String? message}) {
    _state = PaywallState(
      plans: _state.plans,
      isRestoring: false,
      isPurchasing: false,
      selectedPlanId: _state.selectedPlanId,
      message: message,
    );
  }
}
