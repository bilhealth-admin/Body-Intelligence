/// Repository adapters for health tools executed by the existing native Coach
/// transaction and journal. These adapters never own a second operation log.
///
/// [checkAccess] is attempt scoped. The caller checks it before and after every
/// await and before the transaction commits; an owner/permission epoch cannot
/// become valid again through an A -> B -> A transition.
abstract interface class CoachHealthCommandAdapter {
  bool supports(String toolId);

  /// Resolve an immutable proposal. This method must not mutate health data.
  Future<Map<String, Object?>> resolve({
    required String toolId,
    required String operationId,
    required Map<String, Object?> arguments,
    required DateTime now,
    required void Function() checkAccess,
  });

  /// Read the exact fields affected by a proposal, including a bounded receipt.
  /// The result must be stable until persisted state changes (no running clock).
  Future<Map<String, Object?>> snapshot({
    required Map<String, Object?> resolved,
    required void Function() checkAccess,
  });

  /// Called inside the native journal's database transaction after its stale
  /// proposal comparison. Network/device effects must run after commit.
  Future<void> apply({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required void Function() checkAccess,
  });

  /// Compensation is reached only through the existing native Undo boundary,
  /// after owner, permission, identity and after-snapshot checks have passed.
  Future<void> compensate({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required void Function() checkAccess,
  });
}

final class CoachHealthAdapters implements CoachHealthCommandAdapter {
  CoachHealthAdapters(Iterable<CoachHealthCommandAdapter> adapters)
    : adapters = List.unmodifiable(adapters);

  final List<CoachHealthCommandAdapter> adapters;

  @override
  bool supports(String toolId) => adapters.any((a) => a.supports(toolId));

  CoachHealthCommandAdapter _for(String toolId) {
    final matches = adapters.where((a) => a.supports(toolId)).toList();
    if (matches.length != 1) {
      throw StateError('Health command adapter unavailable or ambiguous');
    }
    return matches.single;
  }

  CoachHealthCommandAdapter _resolved(Map<String, Object?> resolved) =>
      _for(resolved['healthToolId']! as String);

  @override
  Future<Map<String, Object?>> resolve({
    required String toolId,
    required String operationId,
    required Map<String, Object?> arguments,
    required DateTime now,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final value = await _for(toolId).resolve(
      toolId: toolId,
      operationId: operationId,
      arguments: arguments,
      now: now,
      checkAccess: checkAccess,
    );
    checkAccess();
    return {...value, 'healthToolId': toolId};
  }

  @override
  Future<Map<String, Object?>> snapshot({
    required Map<String, Object?> resolved,
    required void Function() checkAccess,
  }) => _resolved(
    resolved,
  ).snapshot(resolved: resolved, checkAccess: checkAccess);

  @override
  Future<void> apply({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required void Function() checkAccess,
  }) => _resolved(
    resolved,
  ).apply(resolved: resolved, before: before, checkAccess: checkAccess);

  @override
  Future<void> compensate({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required void Function() checkAccess,
  }) => _resolved(resolved).compensate(
    resolved: resolved,
    before: before,
    after: after,
    checkAccess: checkAccess,
  );
}

Future<T> checkedHealthAwait<T>(
  Future<T> Function() action,
  void Function() checkAccess,
) async {
  checkAccess();
  try {
    return await action();
  } finally {
    checkAccess();
  }
}

bool healthJsonEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every(
          (key) => b.containsKey(key) && healthJsonEquals(a[key], b[key]),
        );
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(
          a.length,
          (index) => index,
        ).every((index) => healthJsonEquals(a[index], b[index]));
  }
  return a == b;
}

/// Dates identify local calendar days. Adding an elapsed 24 hours is unsafe at
/// DST boundaries; callers enumerate days with this civil-date constructor.
DateTime healthCivilDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime parseHealthDay(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw ArgumentError.value(value, 'date', 'Use an exact local date');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      parsed.year != int.parse(value.substring(0, 4)) ||
      parsed.month != int.parse(value.substring(5, 7)) ||
      parsed.day != int.parse(value.substring(8, 10))) {
    throw ArgumentError.value(value, 'date', 'Invalid calendar day');
  }
  return healthCivilDay(parsed);
}
