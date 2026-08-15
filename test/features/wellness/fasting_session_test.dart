import 'dart:convert';

import 'package:body_intelligence_log/features/wellness/domain/fasting_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('elapsed survives restart and timezone change', () {
    final session = FastingSession(
      startedAt: DateTime.parse('2026-08-10T08:00:00+02:00'),
      targetHours: 16,
    );
    expect(
      session.elapsedAt(DateTime.parse('2026-08-10T14:30:00+03:00')),
      const Duration(hours: 5, minutes: 30),
    );
    final restored = FastingSession.tryParse(jsonEncode(session.toJson()));
    expect(restored?.startedAt.toUtc(), session.startedAt.toUtc());
    expect(restored?.targetReachedAt.toUtc(), session.targetReachedAt.toUtc());
  });

  test('clock rollback cannot expose negative elapsed', () {
    final session = FastingSession(
      startedAt: DateTime.utc(2026, 8, 10, 10),
      targetHours: 12,
    );
    expect(session.elapsedAt(DateTime.utc(2026, 8, 10, 9)), Duration.zero);
    expect(session.progressAt(DateTime.utc(2026, 8, 10, 9)), 0);
  });

  test('progress caps while elapsed stays truthful', () {
    final session = FastingSession(
      startedAt: DateTime.utc(2026, 8, 10),
      targetHours: 12,
    );
    expect(session.progressAt(DateTime.utc(2026, 8, 11)), 1);
    expect(
      session.elapsedAt(DateTime.utc(2026, 8, 11)),
      const Duration(hours: 24),
    );
  });

  test('target notification has a strict one-shot boundary', () {
    final session = FastingSession(
      startedAt: DateTime.parse('2026-03-28T20:00:00+01:00'),
      targetHours: 12,
    );
    expect(
      session.targetNotificationAt(DateTime.parse('2026-03-29T07:59:59+02:00')),
      session.targetReachedAt,
    );
    expect(session.targetNotificationAt(session.targetReachedAt), isNull);
    expect(
      session.targetNotificationAt(
        session.targetReachedAt.add(const Duration(minutes: 1)),
      ),
      isNull,
    );
  });

  test('history round trips, rejects corruption, and remains bounded', () {
    final entry = FastingHistoryEntry(
      startedAt: DateTime.utc(2026, 8, 10),
      endedAt: DateTime.utc(2026, 8, 10, 14),
      targetHours: 12,
    );
    final decoded = FastingHistoryCodec.decode(
      FastingHistoryCodec.encode([entry]),
    );
    expect(decoded.single.duration, const Duration(hours: 14));
    expect(decoded.single.reachedTarget, isTrue);
    expect(FastingHistoryCodec.decode('bad-json'), isEmpty);
    expect(
      FastingHistoryCodec.prepend(entry, List.filled(150, entry)),
      hasLength(100),
    );
  });

  test('future sessions and zero-duration history fail closed', () {
    final now = DateTime.utc(2026, 8, 13, 10);
    final future = FastingSession(
      startedAt: now.add(const Duration(minutes: 1)),
      targetHours: 12,
    );
    expect(
      FastingSession.tryParse(jsonEncode(future.toJson()), now: now),
      isNull,
    );
    expect(
      FastingHistoryEntry.fromJson({
        'startedAtUtc': now.toIso8601String(),
        'endedAtUtc': now.toIso8601String(),
        'targetHours': 12,
      }),
      isNull,
    );
  });
}
