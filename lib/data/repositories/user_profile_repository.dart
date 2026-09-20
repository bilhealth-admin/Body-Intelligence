import 'package:drift/drift.dart';

import '../database/app_database.dart';

class UserProfileRepository {
  final AppDatabase _database;

  UserProfileRepository(this._database);

  Future<void> save({
    required String gender,
    required int age,
    required double height,
    required double currentWeight,
    required double targetWeight,
    required String activityLevel,
    required bool exercises,
    String? medicalConditions,
    double? waist,
    double? neck,
    double? chest,
    double? arm,
    double? thigh,
  }) async {
    final existing = await getProfile();
    await _database
        .into(_database.userProfile)
        .insert(
          UserProfileCompanion(
            id: existing == null ? const Value.absent() : Value(existing.id),
            uuid: existing == null
                ? const Value.absent()
                : Value(existing.uuid),
            gender: Value(gender),
            age: Value(age),
            height: Value(height),
            currentWeight: Value(currentWeight),
            targetWeight: Value(targetWeight),
            activityLevel: Value(activityLevel),
            exercises: Value(exercises),
            medicalConditions: Value(medicalConditions),
            waist: Value(waist),
            neck: Value(neck),
            chest: Value(chest),
            arm: Value(arm),
            thigh: Value(thigh),
            createdAt: existing == null
                ? const Value.absent()
                : Value(existing.createdAt),
            updatedAt: Value(DateTime.now()),
            revision: Value((existing?.revision ?? 0) + 1),
            syncStatus: const Value('pending'),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Stream<UserProfileData?> watchProfile() {
    return (_database.select(
      _database.userProfile,
    )..limit(1)).watchSingleOrNull();
  }

  Future<UserProfileData?> getProfile() async {
    final result = await (_database.select(
      _database.userProfile,
    )..limit(1)).getSingleOrNull();

    return result;
  }

  Future<void> deleteProfile() async {
    await _database.delete(_database.userProfile).go();
  }
}
