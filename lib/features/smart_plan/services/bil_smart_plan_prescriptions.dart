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
    this.homeGuidance = false,
    this.titleAr,
  });
  final String exerciseId, repetitions;
  final int sets, restSeconds;
  final bool homeGuidance;
  final String? titleAr;
}

final class BilPlanWarmupStep {
  const BilPlanWarmupStep({
    required this.title,
    required this.dose,
    this.titleAr,
    this.doseAr,
    this.exerciseId,
  });
  final String title, dose;
  final String? titleAr, doseAr, exerciseId;
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
  static const homeAssetPath =
      'artifacts/workout_media/home_smart_plan_prescriptions_v1.json';
  static const homeArtifactSha256 =
      '6c9489fdf0dd54e837c148ee8eb635304c09a5eb2086dade4d00549b8a0e05c6';
  static Future<Map<String, dynamic>>? _homeCached;
  static Map<String, dynamic>? _homeData;

  /// Called only after catalog validation has loaded the pinned projection.
  /// Missing translations fall back to the existing released catalog label.
  String? exerciseTitle(String id, {required String locale}) {
    for (final source in [_homeData, _data]) {
      if (source == null) continue;
      for (final session in source['sessions'] as List) {
        for (final row in session['exercises'] as List) {
          if (row['exerciseId'] == id) {
            return (locale == 'ar' ? row['titleAr'] : row['sourceName'])
                as String?;
          }
        }
      }
    }
    return null;
  }

  static const warmupAssetPath =
      'artifacts/workout_media/smart_plan_warmups_v1.json';
  static const warmupArtifactSha256 =
      '0c45ae85862797907d4c8352e929883bbf0770150d4187417599f8d67c44ae0f';
  static Future<Map<String, dynamic>>? _warmupCached;
  static Map<String, dynamic>? _warmupData;
  Future<Map<String, dynamic>> _loadWarmups() => _warmupData != null
      ? Future.value(_warmupData!)
      : _warmupCached ??= _loadWarmupsOnce().catchError((Object error) {
          _warmupCached = null;
          throw error;
        });

  Future<Map<String, dynamic>> _loadWarmupsOnce() async {
    final bytes = await rootBundle.load(warmupAssetPath);
    final exact = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    if (sha256.convert(exact).toString() != warmupArtifactSha256) {
      throw StateError('smart_plan_warmup_source_changed');
    }
    final source = jsonDecode(utf8.decode(exact)) as Map<String, dynamic>;
    if (source['schema'] != 'bil.smart-plan.warmups.v1' ||
        source['gymSourceSha256'] != GymSixMonthPlanRepository.sourceSha256) {
      throw StateError('smart_plan_warmup_source_changed');
    }
    _warmupData = source;
    return source;
  }

  Future<List<BilPlanWarmupStep>> warmup(BilPlanWorkout workout) async {
    // Validate the entire saved resistance session first, before attaching
    // trusted preparation to an unrecognized or edited cloud template.
    final doses = await session(workout);
    if (doses.isEmpty) return const [];
    final source = await _loadWarmups();
    final home = workout.templateId.startsWith('home-strength-v1-');
    final rows = home
        ? source['home'] as List
        : (source['gym'] as Map)[workout.templateId.split('-').first] as List;
    return List.unmodifiable(
      rows.map(
        (row) => BilPlanWarmupStep(
          title: row['title'] as String,
          dose: row['dose'] as String,
          titleAr: row['titleAr'] as String?,
          doseAr: row['doseAr'] as String?,
          exerciseId: row['exerciseId'] as String?,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadHome() => _homeData != null
      ? Future.value(_homeData!)
      : _homeCached ??= _loadHomeOnce().catchError((Object error) {
          _homeCached = null;
          throw error;
        });

  Future<Map<String, dynamic>> _loadHomeOnce() async {
    final bytes = await rootBundle.load(homeAssetPath);
    final exact = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    if (sha256.convert(exact).toString() != homeArtifactSha256) {
      throw StateError('smart_plan_home_source_changed');
    }
    final source = jsonDecode(utf8.decode(exact)) as Map<String, dynamic>;
    if (source['schema'] != 'bil.smart-plan.home-prescriptions.v1' ||
        source['sourceContractId'] != 'bil-home-strength-general-adult-v1') {
      throw StateError('smart_plan_home_source_changed');
    }
    _homeData = source;
    return source;
  }

  /// Every selection resolves to an approved Home release and the member's
  /// equipment. An immutable template pins level, order and dose across sync.
  Future<List<BilVerifiedWorkout>> homeWorkouts({
    required BilPlanSetup setup,
    required Map<String, Set<String>> equipmentByExercise,
  }) async {
    if (setup.environment != BilPlanEnvironment.home) {
      throw ArgumentError('smart_plan_home_environment_required');
    }
    final result = <BilVerifiedWorkout>[];
    for (final row in (await _loadHome())['sessions'] as List) {
      if (row['experience'] != setup.experience.name) continue;
      final exercises = row['exercises'] as List;
      var available = true;
      for (final exercise in exercises) {
        final required = equipmentByExercise[exercise['exerciseId']];
        final source = (exercise['equipment'] as List).cast<String>().toSet();
        if (required == null ||
            required.length != source.length ||
            !required.containsAll(source)) {
          throw StateError('smart_plan_home_catalog_changed');
        }
        if (required.any(
          (item) => item != 'none' && !setup.equipment.contains(item),
        )) {
          available = false;
        }
      }
      if (!available) continue;
      final rests =
          _restFloor(exercises) +
          await minimumWarmupSeconds(row['id'] as String);
      if (setup.sessionMinutes * 60 <= rests) continue;
      result.add(
        BilVerifiedWorkout(
          id: row['id'] as String,
          exerciseIds: exercises.map((row) => row['exerciseId'] as String),
          minutes: setup.sessionMinutes,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  int _restFloor(List exercises) => exercises.fold<int>(
    0,
    (total, row) =>
        total + ((row['sets'] as int) - 1) * (row['restSeconds'] as int),
  );

  Future<List<dynamic>> _sessionsFor(String id) async =>
      (id.startsWith('home-strength-v1-')
              ? await _loadHome()
              : await _load())['sessions']
          as List;
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
    final rows = (await _sessionsFor(
      templateId,
    )).where((row) => row['id'] == templateId);
    if (rows.length != 1) throw StateError('smart_plan_source_changed');
    return _restFloor(rows.single['exercises'] as List);
  }

  /// Preparation is separate from working sets and is never a diary entry.
  Future<int> minimumWarmupSeconds(String templateId) async =>
      templateId.startsWith('home-strength-v1-')
      ? (await _loadWarmups())['homeMinimumSeconds'] as int
      : 0;

  Future<List<BilPlanExercisePrescription>> session(
    BilPlanWorkout workout,
  ) async {
    // Legacy approved plans are never silently replaced with new doses. Their
    // existing review warning stays until the member approves a new draft.
    if (workout.templateId.startsWith('home-') &&
        !workout.templateId.startsWith('home-strength-v1-')) {
      return const [];
    }
    final rows = (await _sessionsFor(
      workout.templateId,
    )).where((row) => row['id'] == workout.templateId);
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
          homeGuidance: workout.templateId.startsWith('home-strength-v1-'),
          titleAr: row['titleAr'] as String?,
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
