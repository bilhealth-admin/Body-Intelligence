import 'dart:convert';

import '../../data/database/app_database.dart';

class LocalDataLifecycleService {
  const LocalDataLifecycleService(this.database);

  final AppDatabase database;

  Future<String> exportJson({required String displayUnits}) async {
    final profile = await database
        .select(database.userProfile)
        .getSingleOrNull();
    final tables = <String, Future<List<dynamic>>>{
      'goals': database.select(database.goals).get(),
      'planSettings': database.select(database.planSettings).get(),
      'weights': database.select(database.weightEntries).get(),
      'dailyLogs': database.select(database.dailyLogs).get(),
      'foods': database.select(database.foods).get(),
      'favorites': database.select(database.favorites).get(),
      'recentFoods': database.select(database.recentFoods).get(),
      'meals': database.select(database.meals).get(),
      'mealItems': database.select(database.mealItems).get(),
      'waterEntries': database.select(database.waterEntries).get(),
      'lifeContext': database.select(database.lifeContextEntries).get(),
      'decisionMemory': database.select(database.decisionMemories).get(),
      'decisionOutcomeTransitions': database
          .select(database.decisionOutcomeTransitions)
          .get(),
      'personalExperiments': database
          .select(database.personalExperiments)
          .get(),
      'challenges': database.select(database.challenges).get(),
      'preferences': database.select(database.preferences).get(),
    };
    final resolved = <String, Object?>{};
    for (final entry in tables.entries) {
      final rows = await entry.value;
      resolved[entry.key] = rows
          .map((row) => (row as dynamic).toJson() as Map<String, dynamic>)
          .toList();
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'BIL local export v3',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'schemaVersion': database.schemaVersion,
      'canonicalUnits': const {
        'weight': 'kg',
        'height': 'cm',
        'water': 'ml',
        'nutrientMass': 'g or mg as identified by field',
      },
      'selectedDisplayUnits': displayUnits,
      'profile': profile?.toJson(),
      ...resolved,
    });
  }

  Future<void> clearAll() => database.transaction(() async {
    await database.delete(database.decisionOutcomeTransitions).go();
    await database.delete(database.decisionMemories).go();
    await database.delete(database.lifeContextEntries).go();
    await database.delete(database.personalExperiments).go();
    await database.delete(database.challenges).go();
    await database.delete(database.mealItems).go();
    await database.delete(database.meals).go();
    await database.delete(database.favorites).go();
    await database.delete(database.recentFoods).go();
    await database.delete(database.waterEntries).go();
    await database.delete(database.planSettings).go();
    await database.delete(database.goals).go();
    await database.delete(database.weightEntries).go();
    await database.delete(database.dailyLogs).go();
    await database.delete(database.userProfile).go();
    await database.delete(database.foods).go();
    await database.delete(database.preferences).go();
  });
}
