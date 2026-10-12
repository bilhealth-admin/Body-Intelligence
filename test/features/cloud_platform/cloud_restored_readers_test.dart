import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_nutrition_snapshot_codec.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools/qa/flutter/cloud_restore_readers.dart';
import 'support/cloud_nutrition_fixture.dart';

void main() {
  testWidgets(
    'restored SQLite drives actual Today Goals Analytics and Coach readers',
    (tester) async {
      const owner = 'synthetic-reader-owner';
      final a = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      final b = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      addTearDown(
        () => tester.runAsync(() async {
          await a.close();
          await b.close();
        }),
      );
      final seeded = await tester.runAsync(() async {
        await seedCloudNutritionFixture(a, ownerId: owner);
        await LocalDataAccountBoundary(b).bindAuthenticatedOwner(owner);
        final source = CloudNutritionSnapshotCodec(
          a,
          ownerId: owner,
          ownerIsCurrent: () => true,
        );
        final target = CloudNutritionSnapshotCodec(
          b,
          ownerId: owner,
          ownerIsCurrent: () => true,
        );
        for (final record in await source.capture(
          scopes: {'nutrition', 'goals'},
        )) {
          await target.apply(record);
        }
        return true;
      });
      expect(seeded, true);
      await verifyRestoredNutritionReaders(tester, b, ownerId: owner);
    },
  );
}
