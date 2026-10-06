part of 'coach_food_v2.dart';

final class CoachFoodItemVersion {
  CoachFoodItemVersion({
    required String ownerKey,
    required int localId,
    required String uuid,
    required int revision,
  }) : ownerKey = _foodText(ownerKey, 'item.ownerKey', 128),
       localId = _foodRevision(localId),
       uuid = _foodText(uuid, 'item.uuid', 128),
       revision = _foodRevision(revision);

  final String ownerKey;
  final int localId;
  final String uuid;
  final int revision;

  Map<String, Object?> toJson() => {
    'ownerKey': ownerKey,
    'localId': localId,
    'uuid': uuid,
    'revision': revision,
  };
}

/// Absolute replacement data at one stable item/version. This is a proposal,
/// never a standalone ledger, database writer or successful-save receipt.
final class CoachFoodReplacement {
  CoachFoodReplacement({
    required String operationId,
    required this.expected,
    required this.replacement,
  }) : operationId = _foodText(operationId, 'operationId', 128) {
    if (!RegExp(
      r'^[A-Za-z0-9][A-Za-z0-9_:-]{0,127}$',
    ).hasMatch(this.operationId)) {
      _foodReject('invalid_operation_id');
    }
    for (final source in [
      replacement.food.source,
      if (replacement.quantity.evidence.conversion != null)
        replacement.quantity.evidence.conversion!.source,
    ]) {
      if (source.ownerKey != null && source.ownerKey != expected.ownerKey) {
        _foodReject('evidence_owner_mismatch');
      }
    }
  }

  factory CoachFoodReplacement.quantity({
    required String operationId,
    required CoachFoodItemVersion expected,
    required CoachFoodPortion original,
    required CoachFoodQuantity quantity,
  }) => CoachFoodReplacement(
    operationId: operationId,
    expected: expected,
    replacement: CoachFoodPortion(
      food: original.food,
      quantity: quantity,
      identityConfidence: original.identityConfidence,
    ),
  );

  final String operationId;
  final CoachFoodItemVersion expected;
  final CoachFoodPortion replacement;

  String get argumentsDigest => _foodDigest({
    'expected': expected.toJson(),
    'replacement': replacement.toJson(),
  });

  /// Call with a fresh row read INSIDE the existing repository transaction.
  /// Undo must compare the committed after-version again, then restore the
  /// saved before-snapshot with a new revision through that same boundary.
  void checkCurrent({
    required CoachFoodItemVersion actual,
    required CoachFoodOwnerScope scope,
  }) {
    scope.check();
    if (scope.captured.ownerKey != expected.ownerKey ||
        actual.ownerKey != expected.ownerKey) {
      _foodReject('owner_changed');
    }
    if (actual.localId != expected.localId ||
        actual.uuid != expected.uuid ||
        actual.revision != expected.revision) {
      _foodReject('item_revision_conflict');
    }
    scope.checkEvidence(replacement.food.source);
    final conversion = replacement.quantity.evidence.conversion;
    if (conversion != null) scope.checkEvidence(conversion.source);
  }
}
