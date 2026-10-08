import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/repositories/life_context_repository.dart';
import 'coach_health_adapter.dart';

typedef CoachLifeContextReader =
    Future<LifeContextEntry?> Function(String uuid);
typedef CoachLifeContextAdder =
    Future<int> Function({
      required String uuid,
      required DateTime occurredAt,
      required String type,
      required String details,
      required bool useInInsights,
    });

/// Explicit diary context stays separate from general Coach memory. Insight
/// consent is a distinct boolean and defaults to false in the tool contract.
final class CoachLifeContextCommandAdapter
    implements CoachHealthCommandAdapter {
  CoachLifeContextCommandAdapter({
    required this.repository,
    required this.readByUuid,
    required this.addWithUuid,
  });

  final LifeContextRepository repository;
  final CoachLifeContextReader readByUuid;
  final CoachLifeContextAdder addWithUuid;

  @override
  bool supports(String toolId) => toolId == 'save_life_context';

  @override
  Future<Map<String, Object?>> resolve({
    required String toolId,
    required String operationId,
    required Map<String, Object?> arguments,
    required DateTime now,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    if (!supports(toolId)) throw ArgumentError.value(toolId, 'toolId');
    final date = parseHealthDay(arguments['date']);
    final type = arguments['type'];
    final details = arguments['text'];
    final consent = arguments['useInInsights'];
    if (!LifeContextRepository.allowedTypes.contains(type) ||
        details is! String ||
        details.trim().isEmpty ||
        details.length > 1000 ||
        consent is! bool ||
        date.isAfter(healthCivilDay(now))) {
      throw ArgumentError('Invalid explicit life context');
    }
    return {
      'healthToolId': toolId,
      'uuid': const Uuid().v5(
        Namespace.url.value,
        'bil:life-context:$operationId',
      ),
      'occurredAt': date.toIso8601String(),
      'recordedAt': now.toUtc().toIso8601String(),
      'timeZoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      'type': type,
      'text': details.trim(),
      'useInInsights': consent,
    };
  }

  @override
  Future<Map<String, Object?>> snapshot({
    required Map<String, Object?> resolved,
    required void Function() checkAccess,
  }) async {
    final row = await checkedHealthAwait(
      () => readByUuid(resolved['uuid']! as String),
      checkAccess,
    );
    return {
      'record': row?.toJson(),
      'receipt': {
        'exists': row != null && row.deletedAt == null,
        'entity_id': row?.uuid ?? resolved['uuid'],
        'date': row?.dayKey,
        'type': row?.type,
        'text': row?.details,
        'use_in_insights': row?.useInInsights,
        'source': 'manual',
      },
    };
  }

  @override
  Future<void> apply({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required void Function() checkAccess,
  }) async {
    if (before['record'] != null) {
      throw StateError('Life-context identity exists');
    }
    await checkedHealthAwait(
      () => addWithUuid(
        uuid: resolved['uuid']! as String,
        occurredAt: DateTime.parse(resolved['occurredAt']! as String),
        type: resolved['type']! as String,
        details: resolved['text']! as String,
        useInInsights: resolved['useInInsights']! as bool,
      ),
      checkAccess,
    );
    final saved = await checkedHealthAwait(
      () => readByUuid(resolved['uuid']! as String),
      checkAccess,
    );
    final expectedAt = DateTime.parse(resolved['occurredAt']! as String);
    if (saved == null ||
        saved.uuid != resolved['uuid'] ||
        saved.occurredAt.toUtc() != expectedAt.toUtc() ||
        saved.dayKey != dayKeyFor(expectedAt) ||
        saved.deletedAt != null ||
        saved.type != resolved['type'] ||
        saved.details != resolved['text'] ||
        saved.useInInsights != resolved['useInInsights']) {
      throw StateError('Life-context write readback did not match');
    }
  }

  @override
  Future<void> compensate({
    required Map<String, Object?> resolved,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required void Function() checkAccess,
  }) async {
    final row = await checkedHealthAwait(
      () => readByUuid(resolved['uuid']! as String),
      checkAccess,
    );
    if (row == null || row.deletedAt != null) {
      throw StateError('Life-context record no longer exists');
    }
    await checkedHealthAwait(() => repository.delete(row.id), checkAccess);
    final saved = await checkedHealthAwait(
      () => readByUuid(resolved['uuid']! as String),
      checkAccess,
    );
    if (saved == null || saved.uuid != row.uuid || saved.deletedAt == null) {
      throw StateError('Life-context compensation readback did not match');
    }
  }
}
