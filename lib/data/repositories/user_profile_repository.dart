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
    await _database.into(_database.userProfile).insert(
      UserProfileCompanion.insert(
        gender: gender,
        age: age,
        height: height,
        currentWeight: currentWeight,
        targetWeight: targetWeight,
        activityLevel: activityLevel,
        exercises: exercises,
        medicalConditions: Value(medicalConditions),
        waist: Value(waist),
        neck: Value(neck),
        chest: Value(chest),
        arm: Value(arm),
        thigh: Value(thigh),
      ),
      mode: InsertMode.replace,
    );
  }

  Stream<UserProfileData?> watchProfile() {
    return (_database.select(_database.userProfile)
      ..limit(1))
        .watchSingleOrNull();
  }

  Future<UserProfileData?> getProfile() async {
    final result = await (_database.select(_database.userProfile)
      ..limit(1))
        .getSingleOrNull();

    return result;
  }

  Future<void> deleteProfile() async {
    await _database.delete(_database.userProfile).go();
  }
}