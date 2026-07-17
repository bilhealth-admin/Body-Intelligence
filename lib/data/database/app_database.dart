import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daily_logs.dart';
import 'user_profile.dart';
import 'weight_entries.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    DailyLogs,
    UserProfile,
    WeightEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(userProfile);
      }

      if (from < 3) {
        await migrator.createTable(weightEntries);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();

    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final file = File(
      p.join(
        directory.path,
        'body_intelligence.sqlite',
      ),
    );

    return NativeDatabase.createInBackground(file);
  });
}