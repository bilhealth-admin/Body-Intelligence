enum AiWriteKind { addFood, addWater, addContext, changeTarget }

class AiWritePolicy {
  const AiWritePolicy._();

  static bool mayCommit({
    required AiWriteKind kind,
    required bool userDataConsent,
    required bool explicitConfirmation,
  }) {
    if (!userDataConsent || !explicitConfirmation) return false;
    return kind != AiWriteKind.changeTarget;
  }
}
