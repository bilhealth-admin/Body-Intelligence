import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_engine.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_transport.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/supabase_cloud_restore_v2_transport.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_http_client.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/recipe_import/repositories/trusted_recipe_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../test/features/cloud_platform/support/cloud_nutrition_fixture.dart';
import '../../../test/features/community/support/community_rewards_rpc_fixture.dart';
import 'cloud_restore_readers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real PostgreSQL encrypted A to empty independent B then CAS edits deletions and retry',
    (tester) async {
      final configPath = Platform.environment['BIL_LOCAL_RESTORE_CONFIG'];
      if (configPath == null) {
        throw StateError('Use the explicit isolated cycle runner');
      }
      final config = jsonDecode(File(configPath).readAsStringSync()) as Map;
      final url = config['url']! as String;
      if (Uri.parse(url).host != '127.0.0.1' ||
          Uri.parse(url).scheme != 'http') {
        throw StateError('Loopback-only fixture');
      }
      final realSupabase = config['mode'] == 'supabase_local';
      if (config['mode'] != null && !realSupabase) {
        throw StateError('Unsupported isolated fixture mode');
      }
      final owner = config['owner_a']! as String;
      final root = Directory(File(configPath).parent.path);
      late SupabaseClient client;
      late AppDatabase a, b, viewDatabase;
      // SDK JSON-isolate initialization and native I/O belong to the real
      // async zone, not the fake widget clock. Only loopback is unmocked.
      final initialized = await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(() async {
          client = SupabaseClient(
            url,
            realSupabase
                ? config['anon_key']! as String
                : 'synthetic-public-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: CommunityOwnerHttpClient(http.Client()),
          );
          a = AppDatabase.forTesting(
            NativeDatabase(File('${root.path}/device-a.sqlite')),
            localOwnerId: owner,
          );
          b = AppDatabase.forTesting(
            NativeDatabase(File('${root.path}/device-b.sqlite')),
            localOwnerId: owner,
          );
          viewDatabase = AppDatabase.forTesting(
            NativeDatabase(File('${root.path}/b-render.sqlite')),
            localOwnerId: owner,
          );
          await client.auth.setInitialSession(
            jsonEncode(
              realSupabase
                  ? config['auth_session']
                  : {
                      ...RewardsRpcFixture.session(owner),
                      'access_token':
                          'e30.${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800, 'role': 'authenticated'}))).replaceAll('=', '')}.synthetic',
                    },
            ),
          );
          if (realSupabase) {
            final identity = await client.auth.getUser().timeout(
              const Duration(seconds: 20),
            );
            expect(
              identity.user?.id,
              owner,
              reason: 'The local Auth server must validate the signed owner',
            );
          }
          await LocalDataAccountBoundary(a).bindAuthenticatedOwner(owner);
          await LocalDataAccountBoundary(b).bindAuthenticatedOwner(owner);
          await LocalDataAccountBoundary(
            viewDatabase,
          ).bindAuthenticatedOwner(owner);
          return true;
        }, _RealLoopbackNetwork()),
      );
      expect(initialized, true, reason: 'Native test clients must initialize');
      addTearDown(
        () => tester.runAsync(() async {
          await client.dispose();
          await a.close();
          await b.close();
          await viewDatabase.close();
        }),
      );
      late CloudNutritionFixtureData fixture;
      final reports = <Map<String, Object?>>[];
      final base = SupabaseCloudRestoreV2Transport(client, ownerId: owner);
      final loss = _LoseOneResponse(base);
      CloudRestoreV2Engine engine(
        AppDatabase db,
        String device, {
        CloudRestoreV2Transport? transport,
      }) => CloudRestoreV2Engine(
        database: db,
        ownerId: owner,
        deviceId: device,
        keyId: 'synthetic-key-0-31',
        cipher: _RealSyntheticGcm(),
        transport: transport ?? base,
        ownerIsCurrent: () => client.auth.currentUser?.id == owner,
        pageSize: 1,
      );
      final ea = engine(a, 'logical-a', transport: loss),
          eb = engine(b, 'logical-b');
      Future<CloudRestoreV2Report> run(
        String label,
        CloudRestoreV2Engine e,
      ) async {
        final report = await e.run({'nutrition', 'goals'});
        debugPrint(
          'Cycle stage: $label completed=${report.completed} reason=${report.reason} pending=${report.pending} conflicts=${report.conflicts}',
        );
        reports.add({
          'stage': label,
          'pushed': report.pushed,
          'pulled': report.pulled,
          'applied': report.applied,
          'pending': report.pending,
          'conflicts': report.conflicts,
          'reason': report.reason,
          'completed': report.completed,
        });
        return report;
      }

      final restoredSuccessfully = await tester.runAsync(() async {
        debugPrint('Cycle: explicit test consents and seed');
        if (realSupabase) {
          await client
              .rpc(
                'bil_record_consent',
                params: {
                  'p_purpose': 'cloud_sync',
                  'p_policy_version': '1',
                  'p_granted': true,
                },
              )
              .timeout(const Duration(seconds: 20));
        }
        for (final scope in ['nutrition', 'goals']) {
          await client
              .rpc(
                'bil_record_cloud_restore_consent_v2',
                params: {
                  'p_scope': scope,
                  'p_granted': true,
                  'p_policy_version': '1',
                },
              )
              .timeout(const Duration(seconds: 20));
        }
        await LocalDataAccountBoundary(b).bindAuthenticatedOwner(owner);
        for (final table in ['foods', 'meals', 'meal_items']) {
          await b.customStatement(
            'INSERT INTO sqlite_sequence(name,seq) VALUES(?,?)',
            [table, 100],
          );
        }
        expect(await b.select(b.meals).get(), isEmpty);
        expect(await b.select(b.foods).get(), isEmpty);
        fixture = await seedCloudNutritionFixture(a, ownerId: owner);
        final original = await ea.codec.capture(scopes: {'nutrition', 'goals'});
        loss.lose = true;
        expect(
          (await run('response lost after PG commit', ea)).completed,
          isFalse,
        );
        // Retry uses saved ciphertext/opIDs from real SQLite; PG receipt proves
        // replay and no duplicate effects after an ambiguous transport failure.
        expect(
          (await run('A replay', engine(a, 'logical-a'))).completed,
          isTrue,
        );
        expect((await run('B restoration pages', eb)).completed, isTrue);
        final restored = await eb.codec.capture(scopes: {'nutrition', 'goals'});
        expect(
          {for (final r in restored) r.key: snapshotFingerprint(r)},
          {for (final r in original) r.key: snapshotFingerprint(r)},
        );
        final itemsA = await a.select(a.mealItems).get(),
            itemsB = await b.select(b.mealItems).get();
        for (final before in itemsA) {
          final after = itemsB.singleWhere((r) => r.uuid == before.uuid);
          expect(after.id, isNot(before.id));
          expect(after.mealId, isNot(before.mealId));
          expect(after.foodId, isNot(before.foodId));
          for (final nutrient in FoodNutrient.values) {
            expect(
              MealFoodEvidence.read(after).fullValue(nutrient),
              MealFoodEvidence.read(before).fullValue(nutrient),
              reason: nutrient.name,
            );
          }
          expect(
            MealFoodEvidence.read(after).fullValue(FoodNutrient.transFat),
            isNull,
          );
          expect(
            MealFoodEvidence.read(after).fullValue(FoodNutrient.cholesterol),
            0,
          );
        }
        expect(
          await PreferencesRepository(b).get(firstMealCelebrationPreferenceKey),
          'done',
        );
        expect(
          await PreferencesRepository(b).get('commerce.purchaseCelebration.v1'),
          isNull,
        );
        expect((await run('B idempotent', eb)).pushed, 0);
        // A separate renderer connection restores the SAME server snapshot,
        // never a SQLite copy. Native sync transactions are tested before
        // entering the widget clock; UI stream retirement cannot stall them.
        expect(
          (await run(
            'B renderer restoration',
            engine(viewDatabase, 'logical-b-render'),
          )).completed,
          isTrue,
        );
        expect(
          {
            for (final r in await engine(
              viewDatabase,
              'logical-b-render',
            ).codec.capture(scopes: {'nutrition', 'goals'}))
              r.key: snapshotFingerprint(r),
          },
          {for (final r in original) r.key: snapshotFingerprint(r)},
        );
        return true;
      });
      expect(
        restoredSuccessfully,
        true,
        reason: 'Cloud restoration must finish before rendering',
      );
      final mutationsVerified = await tester.runAsync(() async {
        final pa = PreferencesRepository(a), pb = PreferencesRepository(b);
        await pa.setMany({'goal.calories': '2000', 'goal.proteinGrams': '100'});
        await pb.setMany({'goal.calories': '1500', 'goal.proteinGrams': '75'});
        expect((await run('A goal edit', ea)).completed, isTrue);
        final conflict = await run('B goal conflict', eb);
        expect(conflict.completed, isFalse);
        expect(conflict.conflicts, 1);
        expect(await pb.get('goal.calories'), '1500');
        expect(await pb.get('goal.proteinGrams'), '75');
        final row = (await eb.conflicts({'goals'})).single;
        await eb.resolveConflict(
          row.key,
          keepLocal: true,
          expectedToken: await eb.conflictToken(row),
        );
        expect(
          (await run('B explicit local CAS resolution', eb)).completed,
          isTrue,
        );
        expect((await run('A remote resolved goal', ea)).completed, isTrue);
        expect(await pa.get('goal.calories'), '1500');
        final meal = (await a.select(a.meals).get()).singleWhere(
          (r) => r.uuid == fixture.mealUuid,
        );
        await MealRepository(a).deleteMealCascade(meal.id);
        await TrustedRecipeRepository(pa).delete(fixture.recipeId);
        expect((await run('A deletes meal recipe', ea)).completed, isTrue);
        expect((await run('B receives tombstones', eb)).completed, isTrue);
        expect(
          (await MealRepository(
            b,
          ).watchMealsForDate(DateTime(2026, 10, 12)).first).length,
          1,
        );
        expect(await TrustedRecipeRepository(pb).load(), isEmpty);
        expect((await run('B repeated deletion replay', eb)).pushed, 0);
        expect(await pb.get(firstMealCelebrationPreferenceKey), 'done');
        final after = await eb.codec.capture(scopes: {'nutrition', 'goals'});
        expect(
          after.singleWhere((r) => r.id == fixture.mealUuid).deleted,
          isTrue,
        );
        await File('${root.path}/cycle-proof.json').writeAsString(
          jsonEncode({
            'source_count': (await ea.codec.capture(
              scopes: {'nutrition', 'goals'},
            )).length,
            'relations_use_global_ids': true,
            'local_ids_differ': true,
            'nineteen_nutrients': true,
            'unknown_transFat': true,
            'known_zero_cholesterol': true,
            'historical_first_food': 'done',
            'reports': reports,
            'scope': realSupabase
                ? 'real SQLite A/B, local Supabase Auth/PostgREST/PostgreSQL and .NET AES; synthetic user, no phone/Production'
                : 'real SQLite and PostgreSQL, synthetic auth and .NET AES, no phone/Production',
          }),
        );
        return true;
      });
      expect(
        mutationsVerified,
        true,
        reason: 'Native edit/delete/conflict cycle must finish',
      );
      await verifyRestoredNutritionReaders(
        tester,
        viewDatabase,
        ownerId: owner,
      );
    },
  );
}

final class _RealSyntheticGcm implements CloudPayloadCipher {
  @override
  bool get isAvailable => true;
  Future<Map<String, Object?>> _process(
    String mode,
    Map<String, Object?> value,
  ) async {
    final executable = Platform.environment['BIL_TEST_PWSH'];
    if (executable == null) {
      throw StateError('Synthetic native AES runner is required');
    }
    final process = await Process.start(executable, [
      '-NoProfile',
      '-File',
      'tools/qa/bil_synthetic_gcm_fixture.ps1',
      mode,
    ]);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.write(jsonEncode(value));
    await process.stdin.close();
    final result = await output;
    if (await process.exitCode != 0) {
      await errors;
      throw const FormatException('Synthetic AES operation failed');
    }
    await errors;
    return Map<String, Object?>.from(jsonDecode(result) as Map);
  }

  @override
  Future<Map<String, Object?>> encrypt(Map<String, Object?> cleartext) =>
      _process('encrypt', cleartext);
  @override
  Future<Map<String, Object?>> decrypt(Map<String, Object?> ciphertext) =>
      _process('decrypt', ciphertext);
}

final class _RealLoopbackNetwork extends HttpOverrides {}

final class _LoseOneResponse implements CloudRestoreV2Transport {
  _LoseOneResponse(this.inner);
  final CloudRestoreV2Transport inner;
  bool lose = false;
  @override
  Future<Map<String, Object?>> capabilities() => inner.capabilities();
  @override
  Future<Map<String, Object?>> consent() => inner.consent();
  @override
  Future<Map<String, Object?>> exchange({
    required String deviceId,
    required String scope,
    required int cursor,
    required List<Map<String, Object?>> operations,
    required int limit,
  }) async {
    final result = await inner.exchange(
      deviceId: deviceId,
      scope: scope,
      cursor: cursor,
      operations: operations,
      limit: limit,
    );
    if (lose && operations.isNotEmpty) {
      lose = false;
      throw StateError('Synthetic transport loss AFTER real PG commit');
    }
    return result;
  }
}
