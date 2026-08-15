import 'dart:convert';

/// Anchored to instants so elapsed time survives restart, backgrounding, and
/// timezone changes without relying on an in-memory ticking counter.
class FastingSession {
  const FastingSession({required this.startedAt, required this.targetHours});
  final DateTime startedAt;
  final int targetHours;

  DateTime get targetReachedAt => startedAt.add(Duration(hours: targetHours));

  /// Returns the one-shot notification instant only while it is still useful.
  /// A scheduler must not roll a missed fasting target into the next day.
  DateTime? targetNotificationAt(DateTime now) =>
      targetReachedAt.toUtc().isAfter(now.toUtc()) ? targetReachedAt : null;
  Duration elapsedAt(DateTime now) {
    final value = now.toUtc().difference(startedAt.toUtc());
    return value.isNegative ? Duration.zero : value;
  }

  double progressAt(DateTime now) =>
      (elapsedAt(now).inMilliseconds /
              Duration(hours: targetHours).inMilliseconds)
          .clamp(0.0, 1.0);

  Map<String, Object> toJson() => {
    'startedAtUtc': startedAt.toUtc().toIso8601String(),
    'targetHours': targetHours,
  };

  static FastingSession? tryParse(String? encoded, {DateTime? now}) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final hours = value['targetHours'] as int;
      if (hours < 1 || hours > 48) return null;
      final startedAt = DateTime.parse(value['startedAtUtc'] as String);
      if (startedAt.toUtc().isAfter((now ?? DateTime.now()).toUtc())) {
        return null;
      }
      return FastingSession(startedAt: startedAt, targetHours: hours);
    } on Object {
      return null;
    }
  }
}

class FastingHistoryEntry {
  const FastingHistoryEntry({
    required this.startedAt,
    required this.endedAt,
    required this.targetHours,
  });
  final DateTime startedAt;
  final DateTime endedAt;
  final int targetHours;

  Duration get duration {
    final value = endedAt.toUtc().difference(startedAt.toUtc());
    return value.isNegative ? Duration.zero : value;
  }

  bool get reachedTarget => duration >= Duration(hours: targetHours);
  Map<String, Object> toJson() => {
    'startedAtUtc': startedAt.toUtc().toIso8601String(),
    'endedAtUtc': endedAt.toUtc().toIso8601String(),
    'targetHours': targetHours,
  };

  static FastingHistoryEntry? fromJson(Map<String, dynamic> value) {
    try {
      final start = DateTime.parse(value['startedAtUtc'] as String);
      final end = DateTime.parse(value['endedAtUtc'] as String);
      final hours = value['targetHours'] as int;
      if (hours < 1 || hours > 48 || !end.toUtc().isAfter(start.toUtc())) {
        return null;
      }
      return FastingHistoryEntry(
        startedAt: start,
        endedAt: end,
        targetHours: hours,
      );
    } on Object {
      return null;
    }
  }
}

abstract final class FastingHistoryCodec {
  static String encode(Iterable<FastingHistoryEntry> entries) =>
      jsonEncode(entries.map((entry) => entry.toJson()).toList());
  static List<FastingHistoryEntry> decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(FastingHistoryEntry.fromJson)
          .whereType<FastingHistoryEntry>()
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  static List<FastingHistoryEntry> prepend(
    FastingHistoryEntry entry,
    List<FastingHistoryEntry> history, {
    int limit = 100,
  }) => [entry, ...history].take(limit).toList(growable: false);
}
