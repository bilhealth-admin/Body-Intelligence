import 'dart:convert';

import '../../../data/repositories/preferences_repository.dart';
import '../domain/fasting_session.dart';

/// One immutable preference revision. Occurrence identity includes this exact
/// snapshot, not just timestamps (legacy records have no persistent ID).
final class FastingHistorySnapshot {
  FastingHistorySnapshot._(this._owner, this.encoded, this.lastMinutes) {
    try {
      final value = encoded == null ? <Object?>[] : jsonDecode(encoded!);
      if (value is List) {
        _rows = List<Object?>.of(value);
        readable = true;
      }
    } on Object {
      // Unreadable history must never be silently replaced by a delete.
    }
  }
  final FastingHistoryRepository _owner;
  final String? encoded, lastMinutes;
  List<Object?> _rows = const [];
  bool readable = false;

  List<FastingHistoryRecord> get records {
    final result = <FastingHistoryRecord>[];
    for (var index = 0; index < _rows.length; index++) {
      final value = _rows[index];
      if (value is! Map<String, dynamic>) continue;
      final entry = FastingHistoryEntry.fromJson(value);
      if (entry != null) result.add(FastingHistoryRecord._(this, index, entry));
    }
    return List.unmodifiable(result);
  }
}

final class FastingHistoryRecord {
  FastingHistoryRecord._(this.snapshot, this.occurrence, this.entry);
  final FastingHistorySnapshot snapshot;
  final int occurrence;
  final FastingHistoryEntry entry;
}

/// History and its last-duration summary commit together. Active timer keys,
/// notification settings and independent start-context facts are not touched.
class FastingHistoryRepository {
  FastingHistoryRepository(this.preferences);
  final PreferencesRepository preferences;
  static const historyKey = 'wellness_fasting_history_v1';
  static const lastMinutesKey = 'wellness_fasting_last_minutes';

  Stream<FastingHistorySnapshot> watch() => preferences
      .watchSnapshot(const [historyKey, lastMinutesKey])
      .map(
        (values) => FastingHistorySnapshot._(
          this,
          values[historyKey],
          values[lastMinutesKey],
        ),
      );

  Future<FastingHistorySnapshot> read({bool Function()? isCurrent}) async {
    void check() {
      if (isCurrent?.call() == false) throw StateError('fasting_owner_changed');
    }

    check();
    final history = await preferences.get(historyKey);
    check();
    final last = await preferences.get(lastMinutesKey);
    check();
    return FastingHistorySnapshot._(this, history, last);
  }

  bool owns(FastingHistoryRecord record) =>
      identical(record.snapshot._owner, this);

  Future<FastingHistorySnapshot?> delete(
    FastingHistoryRecord record, {
    required bool Function() isCurrent,
  }) async {
    final before = record.snapshot;
    if (!owns(record) || !before.readable || !isCurrent()) {
      throw StateError('fasting_history_retired');
    }
    final rows = List<Object?>.of(before._rows)..removeAt(record.occurrence);
    final encoded = jsonEncode(rows);
    final next = FastingHistorySnapshot._(this, encoded, null);
    final remaining = next.records;
    final last = remaining.isEmpty
        ? null
        : '${remaining.first.entry.duration.inMinutes}';
    final updates = <String, String>{historyKey: encoded};
    if (last != null) updates[lastMinutesKey] = last;
    final committed = await preferences.mutateIfUnchanged(
      expected: {
        historyKey: before.encoded,
        lastMinutesKey: before.lastMinutes,
      },
      set: updates,
      remove: [if (last == null) lastMinutesKey],
      isCurrent: isCurrent,
    );
    if (!isCurrent()) throw StateError('fasting_owner_changed');
    return committed ? FastingHistorySnapshot._(this, encoded, last) : null;
  }
}
