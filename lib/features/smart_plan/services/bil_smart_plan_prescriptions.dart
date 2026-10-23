import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../domain/bil_smart_plan.dart';
import '../domain/bil_smart_plan_engine.dart';
import '../../wellness/repositories/gym_six_month_plan_repository.dart';

final class BilPlanExercisePrescription {
  const BilPlanExercisePrescription({
    required this.exerciseId,
    required this.sets,
    required this.repetitions,
    required this.restSeconds,
  });
  final String exerciseId, repetitions;
  final int sets, restSeconds;
}

/// An extracted projection of the exact source pinned by BIL's Gym runtime.
/// It does not promote model-created doses, raw chat or edited cloud payloads.
final class BilSmartPlanPrescriptions {
  const BilSmartPlanPrescriptions();
  static const assetPath =
      'artifacts/workout_media/smart_plan_prescriptions_v1.json';
  static const artifactSha256 =
      'cd2d3c9ab280116c3a0b13f8c9271426cb414c9429d6f20a7e30af012b38dae3';
  static Future<Map<String, dynamic>>? _cached;
  static Map<String, dynamic>? _data;
  Future<Map<String, dynamic>> _load() => _data != null
      ? Future.value(_data!)
      : _cached ??= _loadOnce().catchError((Object error) {
          _cached = null;
          throw error;
        });
  Future<Map<String, dynamic>> _loadOnce() async {
    final bytes = await rootBundle.load(assetPath);
    final exact = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    if (sha256.convert(exact).toString() != artifactSha256) {
      throw StateError('smart_plan_source_changed');
    }
    final source = jsonDecode(utf8.decode(exact)) as Map<String, dynamic>;
    if (source['schema'] != 'bil.smart-plan.source-prescriptions.v1' ||
        source['sourceSha256'] != GymSixMonthPlanRepository.sourceSha256 ||
        source['sourceContractId'] !=
            GymSixMonthPlanRepository.sourceContractId) {
      throw StateError('smart_plan_source_changed');
    }
    _data = source;
    return source;
  }

  Future<List<BilVerifiedPlanPhase>> phases() async => List.unmodifiable([
    for (final row in (await _load())['phases'] as List)
      BilVerifiedPlanPhase(
        month: row['month'] as int,
        sessionIds: List<String>.unmodifiable(row['sessionIds'] as List),
      ),
  ]);

  /// A source-backed lower bound, not an invented total duration: rests
  /// between sets alone must leave some of the member's budget for movement.
  Future<int> minimumRestSeconds(String templateId) async {
    final rows = ((await _load())['sessions'] as List).where(
      (row) => row['id'] == templateId,
    );
    if (rows.length != 1) throw StateError('smart_plan_source_changed');
    return (rows.single['exercises'] as List).fold<int>(
      0,
      (total, row) =>
          total + ((row['sets'] as int) - 1) * (row['restSeconds'] as int),
    );
  }

  Future<List<BilPlanExercisePrescription>> session(
    BilPlanWorkout workout,
  ) async {
    if (workout.templateId.startsWith('home-')) return const [];
    final rows = ((await _load())['sessions'] as List).where(
      (row) => row['id'] == workout.templateId,
    );
    if (rows.length != 1) throw StateError('smart_plan_source_changed');
    final exercises = rows.single['exercises'] as List;
    if (exercises.length != workout.exerciseIds.length ||
        exercises.indexed.any(
          (row) => row.$2['exerciseId'] != workout.exerciseIds[row.$1],
        )) {
      throw StateError('smart_plan_source_changed');
    }
    return List.unmodifiable(
      exercises.map(
        (row) => BilPlanExercisePrescription(
          exerciseId: row['exerciseId'] as String,
          sets: row['sets'] as int,
          repetitions: row['repetitions'] as String,
          restSeconds: row['restSeconds'] as int,
        ),
      ),
    );
  }

  Future<Map<String, String>?> phase(String id) async {
    if (!id.startsWith('gym-month-')) return null;
    final month = int.tryParse(id.substring('gym-month-'.length));
    final phases = ((await _load())['phases'] as List).where(
      (row) => row['month'] == month,
    );
    if (phases.length != 1) return null;
    final row = phases.single;
    return {
      for (final key in const ['name', 'progression', 'deload'])
        key: row[key] as String,
    };
  }
}
