import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'settings_store.dart';
import '../localization/bil_locale_policy.dart';
import '../localization/bil_locale_rollout_manifest.dart';

const _settingsOperationLimit = 32;
final _settingsOperationIdPattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9_:-]{0,127}$',
);

class AppSettingsOperationConflict implements Exception {
  const AppSettingsOperationConflict(this.reason);

  final String reason;

  @override
  String toString() => 'AppSettingsOperationConflict($reason)';
}

class AppSettingsOperation {
  const AppSettingsOperation({
    required this.operationId,
    required this.field,
    required this.beforeValue,
    required this.afterValue,
    required this.beforeRevision,
    required this.afterRevision,
    required this.committedAt,
    this.undoneAt,
    this.undoRevision,
  });

  final String operationId;
  final String field;
  final String beforeValue;
  final String afterValue;
  final int beforeRevision;
  final int afterRevision;
  final DateTime committedAt;
  final DateTime? undoneAt;
  final int? undoRevision;

  bool get canUndo => undoneAt == null && undoRevision == null;

  AppSettingsOperation copyWithUndo({
    required DateTime undoneAt,
    required int undoRevision,
  }) => AppSettingsOperation(
    operationId: operationId,
    field: field,
    beforeValue: beforeValue,
    afterValue: afterValue,
    beforeRevision: beforeRevision,
    afterRevision: afterRevision,
    committedAt: committedAt,
    undoneAt: undoneAt,
    undoRevision: undoRevision,
  );

  Map<String, Object?> toJson() => {
    'operationId': operationId,
    'field': field,
    'beforeValue': beforeValue,
    'afterValue': afterValue,
    'beforeRevision': beforeRevision,
    'afterRevision': afterRevision,
    'committedAt': committedAt.toUtc().toIso8601String(),
    if (undoneAt != null) 'undoneAt': undoneAt!.toUtc().toIso8601String(),
    if (undoRevision != null) 'undoRevision': undoRevision,
  };

  static AppSettingsOperation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final value = Map<String, Object?>.from(raw);
    final operationId = value['operationId'];
    final field = value['field'];
    final beforeValue = value['beforeValue'];
    final afterValue = value['afterValue'];
    final beforeRevision = value['beforeRevision'];
    final afterRevision = value['afterRevision'];
    final committedAt = DateTime.tryParse(
      value['committedAt']?.toString() ?? '',
    );
    final undoneAtRaw = value['undoneAt'];
    final undoneAt = undoneAtRaw == null
        ? null
        : DateTime.tryParse(undoneAtRaw.toString());
    final undoRevision = value['undoRevision'];
    if (operationId is! String ||
        !_settingsOperationIdPattern.hasMatch(operationId) ||
        !const {'localeCode', 'themeMode'}.contains(field) ||
        beforeValue is! String ||
        afterValue is! String ||
        beforeRevision is! int ||
        beforeRevision < 0 ||
        afterRevision is! int ||
        afterRevision <= beforeRevision ||
        committedAt == null ||
        (undoneAtRaw != null && undoneAt == null) ||
        (undoRevision != null &&
            (undoRevision is! int || undoRevision <= afterRevision))) {
      return null;
    }
    return AppSettingsOperation(
      operationId: operationId,
      field: field! as String,
      beforeValue: beforeValue,
      afterValue: afterValue,
      beforeRevision: beforeRevision,
      afterRevision: afterRevision,
      committedAt: committedAt.toUtc(),
      undoneAt: undoneAt?.toUtc(),
      undoRevision: undoRevision as int?,
    );
  }
}

class AppSettings {
  AppSettings({
    required this.localeCode,
    required this.themeMode,
    this.highContrast = false,
    this.reduceMotion = false,
    this.revision = 0,
    this.operations = const <AppSettingsOperation>[],
  });

  final String localeCode;
  final String themeMode;
  final bool highContrast;
  final bool reduceMotion;
  final int revision;
  final List<AppSettingsOperation> operations;

  AppSettings copyWith({
    String? localeCode,
    String? themeMode,
    bool? highContrast,
    bool? reduceMotion,
    int? revision,
    List<AppSettingsOperation>? operations,
  }) => AppSettings(
    localeCode: localeCode ?? this.localeCode,
    themeMode: themeMode ?? this.themeMode,
    highContrast: highContrast ?? this.highContrast,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    revision: revision ?? this.revision,
    operations: operations ?? this.operations,
  );

  String fieldValue(String field) => switch (field) {
    'localeCode' => localeCode,
    'themeMode' => themeMode,
    _ => throw ArgumentError.value(field, 'field'),
  };

  AppSettings withField(String field, String value) => switch (field) {
    'localeCode' => copyWith(localeCode: value),
    'themeMode' => copyWith(themeMode: value),
    _ => throw ArgumentError.value(field, 'field'),
  };

  Map<String, dynamic> toJson() => {
    'localeCode': localeCode,
    'themeMode': themeMode,
    'highContrast': highContrast,
    'reduceMotion': reduceMotion,
    '_settingsRevision': revision,
    '_settingsOperations': operations.map((item) => item.toJson()).toList(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final storedLocale = BilLocalePolicy.canonicalSupportedTag(
      json['localeCode']?.toString(),
    );
    final storedTheme = json['themeMode']?.toString();
    final revision = json['_settingsRevision'];
    final operationRows = json['_settingsOperations'];
    final operations = operationRows is List
        ? operationRows
              .map(AppSettingsOperation.fromJson)
              .whereType<AppSettingsOperation>()
              .toList(growable: false)
        : const <AppSettingsOperation>[];
    return AppSettings(
      localeCode:
          storedLocale != null &&
              AppSettingsService.supportedLocaleCodes.contains(storedLocale)
          ? storedLocale
          : AppSettingsService.systemLocaleCode(),
      themeMode: const {'system', 'light', 'dark'}.contains(storedTheme)
          ? storedTheme!
          : 'light',
      highContrast: json['highContrast'] == true,
      reduceMotion: json['reduceMotion'] == true,
      revision: revision is int && revision >= 0 ? revision : 0,
      operations: List<AppSettingsOperation>.unmodifiable(operations),
    );
  }
}

// Keep each queued write in its originating Zone. Chaining a static Future
// from a completed test/owner Zone can strand the next mutation (and its
// confirmation) when the previous Zone is disposed. A FIFO work queue keeps
// revision writes serialized without carrying that scheduler across owners.
final class _SettingsMutationTask {
  const _SettingsMutationTask(this.zone, this.execute);

  final Zone zone;
  final Future<void Function()> Function() execute;
}

class AppSettingsService {
  AppSettingsService({SettingsStore? store})
    : _store = store ?? createSettingsStore();

  final SettingsStore _store;

  // Multiple provider/controller instances can exist during navigation/tests.
  // Serialize writes at the process boundary so read-check-write revisions do
  // not race each other even when they share the same platform settings key.
  static final Queue<_SettingsMutationTask> _globalMutationQueue = Queue();
  static bool _globalMutationRunning = false;

  static const supportedLocaleCodes = BilLocaleRolloutManifest.releaseTargets25;

  static String systemLocaleCode() {
    // English is the product default for a fresh installation. A locale that
    // the user explicitly selects is persisted and still wins on later runs.
    return 'en';
  }

  AppSettings _defaults() =>
      AppSettings(localeCode: systemLocaleCode(), themeMode: 'light');

  Future<AppSettings> load() async {
    try {
      return await readCommitted();
    } catch (_) {
      return _defaults();
    }
  }

  /// Strict persisted read used after a mutation. Unlike [load], malformed or
  /// unavailable storage is not converted into a fake default success.
  Future<AppSettings> readCommitted() async {
    final contents = await _store.read();
    if (contents == null) return _defaults();
    final decoded = jsonDecode(contents);
    if (decoded is! Map) {
      throw const FormatException('Invalid app settings document');
    }
    return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
  }

  /// Backward-compatible save API. The committed state is independently read
  /// back and receives a monotonic revision even for ordinary Settings edits.
  Future<void> save(AppSettings settings) async {
    await saveVerified(settings);
  }

  Future<AppSettings> saveVerified(AppSettings settings) =>
      _serialize(() async {
        final current = await readCommitted();
        final candidate = settings.copyWith(
          revision: current.revision + 1,
          operations: current.operations,
        );
        await _store.write(jsonEncode(candidate.toJson()));
        final readback = await readCommitted();
        _verifySettingsReadback(candidate, readback);
        return readback;
      });

  Future<AppSettingsOperation> commitCoachSetting({
    required String operationId,
    required String field,
    required String value,
    bool Function()? checkWritePermission,
  }) => _serialize(() async {
    void checkPermission() {
      if (checkWritePermission?.call() == false) {
        throw const AppSettingsOperationConflict('write_permission_revoked');
      }
    }

    checkPermission();
    _validateCoachMutation(
      operationId: operationId,
      field: field,
      value: value,
    );
    final current = await readCommitted();
    checkPermission();
    final prior = current.operations.where(
      (operation) => operation.operationId == operationId,
    );
    if (prior.isNotEmpty) {
      final operation = prior.single;
      if (operation.field != field || operation.afterValue != value) {
        throw const AppSettingsOperationConflict('operation_mismatch');
      }
      if (!operation.canUndo) {
        throw const AppSettingsOperationConflict('operation_already_undone');
      }
      return operation;
    }
    final before = current.fieldValue(field);
    final afterRevision = current.revision + 1;
    final operation = AppSettingsOperation(
      operationId: operationId,
      field: field,
      beforeValue: before,
      afterValue: value,
      beforeRevision: current.revision,
      afterRevision: afterRevision,
      committedAt: DateTime.now().toUtc(),
    );
    final operations = <AppSettingsOperation>[
      operation,
      ...current.operations,
    ].take(_settingsOperationLimit).toList(growable: false);
    final candidate = current
        .withField(field, value)
        .copyWith(revision: afterRevision, operations: operations);
    checkPermission();
    await _store.write(jsonEncode(candidate.toJson()));
    try {
      checkPermission();
    } on Object {
      await _restoreSettingsSnapshot(current);
      rethrow;
    }
    final readback = await readCommitted();
    _verifySettingsReadback(candidate, readback);
    final stored = readback.operations.where(
      (item) => item.operationId == operationId,
    );
    if (stored.length != 1 ||
        stored.single.afterRevision != afterRevision ||
        readback.fieldValue(field) != value) {
      throw StateError('Coach setting readback failed');
    }
    return stored.single;
  });

  Future<AppSettingsOperation?> readCoachSettingOperation(
    String operationId,
  ) async {
    if (!_settingsOperationIdPattern.hasMatch(operationId)) return null;
    final settings = await readCommitted();
    final matches = settings.operations.where(
      (operation) => operation.operationId == operationId,
    );
    return matches.isEmpty ? null : matches.single;
  }

  Future<AppSettingsOperation> undoCoachSetting({
    required String operationId,
    bool Function()? checkWritePermission,
  }) => _serialize(() async {
    void checkPermission() {
      if (checkWritePermission?.call() == false) {
        throw const AppSettingsOperationConflict('write_permission_revoked');
      }
    }

    checkPermission();
    final current = await readCommitted();
    checkPermission();
    final matches = current.operations.where(
      (operation) => operation.operationId == operationId,
    );
    if (matches.length != 1) {
      throw const AppSettingsOperationConflict('operation_missing');
    }
    final operation = matches.single;
    if (!operation.canUndo) {
      throw const AppSettingsOperationConflict('operation_already_undone');
    }
    // Revision is intentionally global rather than value-only. A later A→B→A
    // edit from Settings or another Coach visit must still block this Undo.
    if (current.revision != operation.afterRevision ||
        current.fieldValue(operation.field) != operation.afterValue) {
      throw const AppSettingsOperationConflict('newer_setting_change');
    }
    checkPermission();
    final undoRevision = current.revision + 1;
    final undone = operation.copyWithUndo(
      undoneAt: DateTime.now().toUtc(),
      undoRevision: undoRevision,
    );
    final operations = [
      for (final item in current.operations)
        if (item.operationId == operationId) undone else item,
    ];
    final candidate = current
        .withField(operation.field, operation.beforeValue)
        .copyWith(revision: undoRevision, operations: operations);
    checkPermission();
    await _store.write(jsonEncode(candidate.toJson()));
    try {
      checkPermission();
    } on Object {
      await _restoreSettingsSnapshot(current);
      rethrow;
    }
    final readback = await readCommitted();
    _verifySettingsReadback(candidate, readback);
    final verified = readback.operations.singleWhere(
      (item) => item.operationId == operationId,
    );
    if (verified.canUndo ||
        verified.undoRevision != undoRevision ||
        readback.fieldValue(operation.field) != operation.beforeValue) {
      throw StateError('Coach setting undo readback failed');
    }
    return verified;
  });

  Future<void> _restoreSettingsSnapshot(AppSettings snapshot) async {
    await _store.write(jsonEncode(snapshot.toJson()));
    final rollback = await readCommitted();
    _verifySettingsReadback(snapshot, rollback);
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _globalMutationQueue.add(
      _SettingsMutationTask(Zone.current, () async {
        try {
          final value = await action();
          return () => completer.complete(value);
        } on Object catch (error, stackTrace) {
          return () => completer.completeError(error, stackTrace);
        }
      }),
    );
    _startQueuedMutation();
    return completer.future;
  }

  static void _startQueuedMutation() {
    if (_globalMutationRunning || _globalMutationQueue.isEmpty) return;
    _globalMutationRunning = true;
    final next = _globalMutationQueue.removeFirst();
    // Run in the caller's own Zone, not the Zone that processed the prior
    // write. This matters for FakeAsync tests and for independent app owners.
    next.zone.run(() => unawaited(_performQueuedMutation(next)));
  }

  static Future<void> _performQueuedMutation(_SettingsMutationTask task) async {
    final finish = await task.execute();
    // Release the lock *before* waking the caller: no completed test can
    // leave an unresolved static callback blocking a future login/session.
    _globalMutationRunning = false;
    _startQueuedMutation();
    finish();
  }

  void _validateCoachMutation({
    required String operationId,
    required String field,
    required String value,
  }) {
    if (!_settingsOperationIdPattern.hasMatch(operationId)) {
      throw ArgumentError.value(operationId, 'operationId');
    }
    switch (field) {
      case 'localeCode':
        final canonical = BilLocalePolicy.canonicalSupportedTag(value);
        if (canonical == null || canonical != value) {
          throw ArgumentError.value(value, 'value');
        }
      case 'themeMode':
        if (!const {'system', 'light', 'dark'}.contains(value)) {
          throw ArgumentError.value(value, 'value');
        }
      default:
        throw ArgumentError.value(field, 'field');
    }
  }

  void _verifySettingsReadback(AppSettings expected, AppSettings actual) {
    if (expected.localeCode != actual.localeCode ||
        expected.themeMode != actual.themeMode ||
        expected.highContrast != actual.highContrast ||
        expected.reduceMotion != actual.reduceMotion ||
        expected.revision != actual.revision ||
        jsonEncode(expected.operations.map((item) => item.toJson()).toList()) !=
            jsonEncode(
              actual.operations.map((item) => item.toJson()).toList(),
            )) {
      throw StateError('App settings were not verified after persistence.');
    }
  }
}
