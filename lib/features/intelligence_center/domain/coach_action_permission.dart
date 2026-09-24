import 'bil_tool_registry.dart';

enum CoachActionPermissionMode { readOnly, askBeforeWrite, writeAllowed }

final class CoachActionPermissionGate {
  const CoachActionPermissionGate();

  bool allows({
    required CoachActionPermissionMode mode,
    required BilToolDescriptor descriptor,
  }) {
    if (descriptor.risk == BilToolRisk.readOnly ||
        descriptor.trustBoundary == BilToolTrustBoundary.clientNavigation) {
      return true;
    }
    return mode != CoachActionPermissionMode.readOnly;
  }

  bool requiresConfirmation({
    required CoachActionPermissionMode mode,
    required BilToolDescriptor descriptor,
  }) {
    if (descriptor.risk == BilToolRisk.sensitive ||
        descriptor.risk == BilToolRisk.destructive) {
      return true;
    }
    return mode == CoachActionPermissionMode.askBeforeWrite &&
        descriptor.risk == BilToolRisk.reversibleWrite;
  }
}
