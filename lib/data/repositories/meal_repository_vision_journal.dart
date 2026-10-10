part of 'meal_repository.dart';

/// Per-owner, durable replay protection for a user-confirmed image request.
/// This receipt is NOT a nutrient source or a claim of image accuracy.
/// It is persisted atomically with the actual diary rows.
final class _VisionCommitIntent {
  const _VisionCommitIntent({
    required this.key,
    required this.ownerScope,
    required this.requestDigest,
    required this.payloadDigest,
  });

  final String key;
  final String ownerScope;
  final String requestDigest;
  final String payloadDigest;
}

extension _MealVisionCommitJournal on MealRepository {
  _VisionCommitIntent? _visionCommitIntent(
    String? requestId,
    DateTime date,
    String mealType,
    List<({int foodId, double quantity})> items,
    bool quantitiesInGrams,
  ) {
    if (requestId == null) return null;
    final request = requestId.trim();
    if (request.isEmpty || request.length > 128) {
      throw ArgumentError.value(requestId, 'visionRequestId');
    }
    final owner = LocalDatabaseScope.keyForOwner(_database.localOwnerId);
    final requestDigest = sha256.convert(utf8.encode(request)).toString();
    final arguments = jsonEncode({
      'dayKey': dayKeyFor(date),
      'mealType': mealType,
      'grams': quantitiesInGrams,
      'items': [
        for (final item in items)
          {'foodId': item.foodId, 'quantity': item.quantity},
      ],
    });
    final payloadDigest = sha256.convert(utf8.encode(arguments)).toString();
    return _VisionCommitIntent(
      key: 'visionMealCommitV1.$owner.$requestDigest',
      ownerScope: owner,
      requestDigest: requestDigest,
      payloadDigest: payloadDigest,
    );
  }

  /// Only call from the parent atomic diary transaction. A reused request ID
  /// with a different portion, target date, owner or food fails closed.
  Future<int?> _visionCommittedMealId(_VisionCommitIntent intent) async {
    final raw = await PreferencesRepository(_database).get(intent.key);
    if (raw == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw StateError('Invalid existing Vision commit receipt.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['schema'] != 1 ||
        decoded['ownerScope'] != intent.ownerScope ||
        decoded['requestDigest'] != intent.requestDigest ||
        decoded['payloadDigest'] != intent.payloadDigest ||
        decoded['mealId'] is! int ||
        (decoded['mealId'] as int) <= 0) {
      throw StateError('Vision request already exists with conflicting data.');
    }
    return decoded['mealId'] as int;
  }

  Future<void> _saveVisionCommitReceipt(
    _VisionCommitIntent intent,
    int mealId,
  ) => PreferencesRepository(_database).setManyInCurrentTransaction({
    intent.key: jsonEncode({
      'schema': 1,
      'ownerScope': intent.ownerScope,
      'requestDigest': intent.requestDigest,
      'payloadDigest': intent.payloadDigest,
      'mealId': mealId,
    }),
  });
}
