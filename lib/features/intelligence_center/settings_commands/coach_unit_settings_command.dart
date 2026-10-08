import 'dart:convert';

import '../../../data/repositories/preferences_repository.dart';

const _unitJournalKey = 'coachUnitPreferenceJournalV1';
const _unitJournalLimit = 24;
final _operationIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_:-]{0,127}$');

class CoachSettingsCommandConflict implements Exception {
  const CoachSettingsCommandConflict(this.reason);
  final String reason;

  @override
  String toString() => 'CoachSettingsCommandConflict($reason)';
}

enum CoachUnitDimension { weight, height, distance, energy, water }

extension CoachUnitDimensionPolicy on CoachUnitDimension {
  String get preferenceKey => 'units.$name';

  Set<String> get allowedValues => switch (this) {
    CoachUnitDimension.weight => const {'Pounds', 'Kilograms', 'Stone'},
    CoachUnitDimension.height => const {'Feet/Inches', 'Centimeters'},
    CoachUnitDimension.distance => const {'Miles', 'Kilometers'},
    CoachUnitDimension.energy => const {'Calories', 'Kilojoules'},
    CoachUnitDimension.water => const {'Cups', 'Milliliters', 'Fluid ounces'},
  };
}

class CoachUnitOperation {
  const CoachUnitOperation({
    required this.operationId,
    required this.dimension,
    required this.beforeValue,
    required this.afterValue,
    required this.committedAt,
    this.beforeLegacySystem,
    this.afterLegacySystem,
    this.undoneAt,
  });

  final String operationId;
  final CoachUnitDimension dimension;
  final String? beforeValue;
  final String afterValue;
  final String? beforeLegacySystem;
  final String? afterLegacySystem;
  final DateTime committedAt;
  final DateTime? undoneAt;

  bool get canUndo => undoneAt == null;

  CoachUnitOperation markUndone(DateTime at) => CoachUnitOperation(
    operationId: operationId,
    dimension: dimension,
    beforeValue: beforeValue,
    afterValue: afterValue,
    beforeLegacySystem: beforeLegacySystem,
    afterLegacySystem: afterLegacySystem,
    committedAt: committedAt,
    undoneAt: at.toUtc(),
  );

  Map<String, Object?> toJson() => {
    'operationId': operationId,
    'dimension': dimension.name,
    'beforeValue': beforeValue,
    'afterValue': afterValue,
    'beforeLegacySystem': beforeLegacySystem,
    'afterLegacySystem': afterLegacySystem,
    'committedAt': committedAt.toUtc().toIso8601String(),
    if (undoneAt != null) 'undoneAt': undoneAt!.toUtc().toIso8601String(),
  };

  static CoachUnitOperation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final row = Map<String, Object?>.from(raw);
    final operationId = row['operationId'];
    final dimensionName = row['dimension'];
    final before = row['beforeValue'];
    final after = row['afterValue'];
    final committedAt = DateTime.tryParse(row['committedAt']?.toString() ?? '');
    final undoneRaw = row['undoneAt'];
    final undoneAt = undoneRaw == null
        ? null
        : DateTime.tryParse(undoneRaw.toString());
    final dimension = CoachUnitDimension.values
        .where((value) => value.name == dimensionName)
        .firstOrNull;
    if (operationId is! String ||
        !_operationIdPattern.hasMatch(operationId) ||
        dimension == null ||
        (before != null && before is! String) ||
        after is! String ||
        !dimension.allowedValues.contains(after) ||
        committedAt == null ||
        (undoneRaw != null && undoneAt == null)) {
      return null;
    }
    return CoachUnitOperation(
      operationId: operationId,
      dimension: dimension,
      beforeValue: before as String?,
      afterValue: after,
      beforeLegacySystem: row['beforeLegacySystem'] as String?,
      afterLegacySystem: row['afterLegacySystem'] as String?,
      committedAt: committedAt.toUtc(),
      undoneAt: undoneAt?.toUtc(),
    );
  }
}

class CoachUnitSettingsCommandService {
  const CoachUnitSettingsCommandService(this.preferences);

  final PreferencesRepository preferences;

  Future<CoachUnitOperation> commit({
    required String operationId,
    required CoachUnitDimension dimension,
    required String value,
    bool Function()? isCurrentOwner,
    bool Function()? checkWritePermission,
  }) async {
    _checkOwner(isCurrentOwner);
    _checkPermission(checkWritePermission);
    if (!_operationIdPattern.hasMatch(operationId)) {
      throw ArgumentError.value(operationId, 'operationId');
    }
    if (!dimension.allowedValues.contains(value)) {
      throw ArgumentError.value(value, 'value');
    }
    final key = dimension.preferenceKey;
    final before = await preferences.get(key);
    final journalRaw = await preferences.get(_unitJournalKey);
    final beforeLegacy = dimension == CoachUnitDimension.weight
        ? await preferences.get('units')
        : null;
    _checkOwner(isCurrentOwner);
    final journal = _decodeJournal(journalRaw);
    final prior = journal.where((item) => item.operationId == operationId);
    if (prior.isNotEmpty) {
      final operation = prior.single;
      if (operation.dimension != dimension || operation.afterValue != value) {
        throw const CoachSettingsCommandConflict('operation_mismatch');
      }
      if (!operation.canUndo) {
        throw const CoachSettingsCommandConflict('operation_already_undone');
      }
      return operation;
    }
    final afterLegacy = dimension == CoachUnitDimension.weight
        ? _legacySystemForWeight(value)
        : null;
    final operation = CoachUnitOperation(
      operationId: operationId,
      dimension: dimension,
      beforeValue: before,
      afterValue: value,
      beforeLegacySystem: beforeLegacy,
      afterLegacySystem: afterLegacy,
      committedAt: DateTime.now().toUtc(),
    );
    final nextJournal = <CoachUnitOperation>[
      operation,
      ...journal,
    ].take(_unitJournalLimit).toList(growable: false);
    final expected = <String, String?>{
      key: before,
      _unitJournalKey: journalRaw,
      if (dimension == CoachUnitDimension.weight) 'units': beforeLegacy,
    };
    final set = <String, String>{
      key: value,
      _unitJournalKey: _encodeJournal(nextJournal),
    };
    if (afterLegacy != null) set['units'] = afterLegacy;
    _checkOwner(isCurrentOwner);
    _checkPermission(checkWritePermission);
    final changed = await preferences.mutateIfUnchanged(
      expected: expected,
      set: set,
    );
    if (!changed) {
      throw const CoachSettingsCommandConflict('newer_unit_change');
    }
    _checkOwner(isCurrentOwner);
    if (await preferences.get(key) != value) {
      throw StateError('Unit preference readback failed');
    }
    final verified = _decodeJournal(
      await preferences.get(_unitJournalKey),
    ).where((item) => item.operationId == operationId);
    if (verified.length != 1) {
      throw StateError('Unit operation journal readback failed');
    }
    return verified.single;
  }

  Future<CoachUnitOperation?> readOperation(String operationId) async {
    if (!_operationIdPattern.hasMatch(operationId)) return null;
    final matches = _decodeJournal(
      await preferences.get(_unitJournalKey),
    ).where((item) => item.operationId == operationId);
    return matches.isEmpty ? null : matches.single;
  }

  Future<CoachUnitOperation> undo({
    required String operationId,
    bool Function()? isCurrentOwner,
    bool Function()? checkWritePermission,
  }) async {
    _checkOwner(isCurrentOwner);
    _checkPermission(checkWritePermission);
    final journalRaw = await preferences.get(_unitJournalKey);
    final journal = _decodeJournal(journalRaw);
    final matches = journal.where((item) => item.operationId == operationId);
    if (matches.length != 1) {
      throw const CoachSettingsCommandConflict('operation_missing');
    }
    final operation = matches.single;
    if (!operation.canUndo) {
      throw const CoachSettingsCommandConflict('operation_already_undone');
    }
    final key = operation.dimension.preferenceKey;
    final current = await preferences.get(key);
    final currentLegacy = operation.dimension == CoachUnitDimension.weight
        ? await preferences.get('units')
        : null;
    if (current != operation.afterValue ||
        (operation.dimension == CoachUnitDimension.weight &&
            currentLegacy != operation.afterLegacySystem)) {
      throw const CoachSettingsCommandConflict('newer_unit_change');
    }
    _checkOwner(isCurrentOwner);
    _checkPermission(checkWritePermission);
    final undone = operation.markUndone(DateTime.now());
    final nextJournal = [
      for (final item in journal)
        if (item.operationId == operationId) undone else item,
    ];
    final set = <String, String>{
      _unitJournalKey: _encodeJournal(nextJournal),
      if (operation.beforeValue != null) key: operation.beforeValue!,
      if (operation.beforeLegacySystem != null)
        'units': operation.beforeLegacySystem!,
    };
    final remove = <String>[
      if (operation.beforeValue == null) key,
      if (operation.dimension == CoachUnitDimension.weight &&
          operation.beforeLegacySystem == null)
        'units',
    ];
    final expected = <String, String?>{
      key: operation.afterValue,
      _unitJournalKey: journalRaw,
      if (operation.dimension == CoachUnitDimension.weight)
        'units': operation.afterLegacySystem,
    };
    _checkPermission(checkWritePermission);
    final changed = await preferences.mutateIfUnchanged(
      expected: expected,
      set: set,
      remove: remove,
    );
    if (!changed) {
      throw const CoachSettingsCommandConflict('newer_unit_change');
    }
    _checkOwner(isCurrentOwner);
    if (await preferences.get(key) != operation.beforeValue) {
      throw StateError('Unit Undo readback failed');
    }
    return _decodeJournal(
      await preferences.get(_unitJournalKey),
    ).singleWhere((item) => item.operationId == operationId);
  }

  static String _legacySystemForWeight(String value) =>
      value == 'Pounds' || value == 'Stone' ? 'imperial' : 'metric';

  static void _checkOwner(bool Function()? isCurrentOwner) {
    if (isCurrentOwner?.call() == false) {
      throw const CoachSettingsCommandConflict('owner_changed');
    }
  }

  static void _checkPermission(bool Function()? checkWritePermission) {
    if (checkWritePermission?.call() == false) {
      throw const CoachSettingsCommandConflict('write_permission_revoked');
    }
  }

  static List<CoachUnitOperation> _decodeJournal(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <CoachUnitOperation>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <CoachUnitOperation>[];
      return decoded
          .map(CoachUnitOperation.fromJson)
          .whereType<CoachUnitOperation>()
          .toList(growable: false);
    } on Object {
      return <CoachUnitOperation>[];
    }
  }

  static String _encodeJournal(List<CoachUnitOperation> operations) =>
      jsonEncode(operations.map((item) => item.toJson()).toList());
}
