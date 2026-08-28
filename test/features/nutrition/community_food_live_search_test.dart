import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/community_catalog/data/community_food_outbox_store.dart';
import 'package:body_intelligence_log/features/nutrition/community_catalog/data/supabase_community_food_catalog.dart';
import 'package:body_intelligence_log/features/nutrition/community_catalog/services/community_food_sync_service.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late FoodRepository foods;
  late CommunityFoodOutboxStore outbox;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    foods = FoodRepository(database);
    outbox = CommunityFoodOutboxStore(database);
  });

  tearDown(() => database.close());

  test(
    'custom food is durably published with its language and evidence',
    () async {
      final foodId = await foods.addFood(
        name: 'عدس منزلي',
        arabicName: 'عدس منزلي',
        category: 'custom',
        servingSize: 180,
        servingUnit: 'g',
        calories: 210,
        protein: 14,
        carbs: 36,
        fats: 1,
        fiber: 15,
      );
      final cloud = _FakeCommunityCloud();
      final service = CommunityFoodSyncService(database, outbox, cloud);

      await service.publishFood(foodId, localeCode: 'ar-EG');
      await service.flush();

      expect(cloud.upserts, hasLength(1));
      expect(cloud.upserts.single['canonical_name'], 'عدس منزلي');
      expect(
        (cloud.upserts.single['localized_names'] as Map)['ar'],
        'عدس منزلي',
      );
      expect(cloud.upserts.single['fiber_g'], 15);
      expect(await outbox.pendingCount(), 0);
    },
  );

  test('failed cloud publication remains in the durable retry outbox', () async {
    final foodId = await foods.addFood(
      name: 'Offline oats',
      category: 'custom',
      servingSize: 50,
      servingUnit: 'g',
      calories: 190,
      protein: 6,
      carbs: 32,
      fats: 4,
    );
    final cloud = _FakeCommunityCloud(failWrites: true);
    final service = CommunityFoodSyncService(database, outbox, cloud);

    await service.publishFood(foodId, localeCode: 'en-US');
    await service.flush();

    expect(await outbox.pendingCount(), 1);
    final row = await database
        .customSelect(
          'SELECT operation, attempt_count, last_error FROM community_food_outbox',
        )
        .getSingle();
    expect(row.read<String>('operation'), 'upsert');
    expect(row.read<int>('attempt_count'), 1);
    expect(row.read<String>('last_error'), contains('offline'));
  });

  test(
    'community result is searchable but never promoted as verified',
    () async {
      await foods.addFood(
        name: 'Chicken breast',
        category: 'foundation',
        calories: 165,
        protein: 31,
        carbs: 0,
        fats: 3.6,
        source: 'foundation',
        isCustom: false,
        verified: true,
      );
      final authority = FoodRuntimeSearchAuthority(
        foods,
        catalogResolver: () async => null,
        communitySearchResolver: (query, {limit = 10}) async => <UnifiedFood>[
          _communityFood(name: 'Chicken family casserole'),
        ],
      );

      final result = await authority.searchDetailed('chicken');

      expect(result.foods.map((food) => food.name), <String>[
        'Chicken breast',
        'Chicken family casserole',
      ]);
      final contribution = result.foods.last;
      expect(contribution.verified, isFalse);
      expect(contribution.source, 'BIL community — unreviewed');
      expect(result.source, FoodRuntimeSearchSource.catalogAndLocal);
    },
  );

  test('community search cannot inject a food unrelated to the query', () async {
    final authority = FoodRuntimeSearchAuthority(
      foods,
      catalogResolver: () async => null,
      communitySearchResolver: (query, {limit = 10}) async => <UnifiedFood>[
        _communityFood(name: 'Apple juice with added vitamin C'),
      ],
    );

    final result = await authority.searchDetailed('chicken');

    expect(result.foods, isEmpty);
    expect(result.source, FoodRuntimeSearchSource.localOnly);
  });

  test('migration exposes authenticated upsert, withdraw and search RPCs', () {
    final sql = File(
      'supabase/migrations/20260821054046_community_food_live_search.sql',
    ).readAsStringSync();

    expect(sql, contains('bil_upsert_community_food_contribution'));
    expect(sql, contains('bil_withdraw_community_food_contribution'));
    expect(sql, contains('bil_search_community_foods'));
    expect(sql, contains("status in ('pending', 'approved')"));
    expect(sql, contains('grant execute'));
    expect(sql, contains('to authenticated'));
    expect(sql, contains('from public, anon'));
  });
}

UnifiedFood _communityFood({required String name}) {
  return UnifiedFood(
    id: 'community:11111111-1111-4111-8111-111111111111',
    name: name,
    category: 'community',
    serving: const FoodServing(amount: 250, unit: 'g', grams: 250),
    nutrients: const <FoodNutrient, NutrientAmount>{
      FoodNutrient.calories: NutrientAmount.known(320),
      FoodNutrient.protein: NutrientAmount.known(24),
      FoodNutrient.carbohydrates: NutrientAmount.known(28),
      FoodNutrient.fat: NutrientAmount.known(12),
    },
    source: FoodDataSource.custom,
    sourceLabel: 'BIL community — unreviewed',
    verified: false,
    isCustom: false,
  );
}

class _FakeCommunityCloud implements CommunityFoodCloudGateway {
  _FakeCommunityCloud({this.failWrites = false});

  final bool failWrites;
  final List<Map<String, dynamic>> upserts = <Map<String, dynamic>>[];

  @override
  Future<List<UnifiedFood>> search(String query, {int limit = 10}) async =>
      const <UnifiedFood>[];

  @override
  Future<void> upsert(Map<String, dynamic> payload) async {
    if (failWrites) throw StateError('offline');
    upserts.add(payload);
  }

  @override
  Future<void> withdraw(String localFoodUuid) async {
    if (failWrites) throw StateError('offline');
  }
}
