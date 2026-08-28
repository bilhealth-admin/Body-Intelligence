import 'dart:async';

import '../../../../data/database/app_database.dart';
import '../data/community_food_outbox_store.dart';
import '../data/supabase_community_food_catalog.dart';
import '../domain/community_food_contribution.dart';

class CommunityFoodSyncService {
  CommunityFoodSyncService(this._database, this._outbox, this._cloud);

  final AppDatabase _database;
  final CommunityFoodOutboxStore _outbox;
  final CommunityFoodCloudGateway? _cloud;
  Future<void>? _activeFlush;

  Future<void> publishFood(
    int localFoodId, {
    required String localeCode,
  }) async {
    final food = await (_database.select(
      _database.foods,
    )..where((row) => row.id.equals(localFoodId))).getSingle();
    if (!food.isCustom || food.deletedAt != null) return;
    await _outbox.enqueueUpsert(
      CommunityFoodContribution.fromFood(food, localeCode: localeCode),
    );
    unawaited(flush());
  }

  Future<void> withdrawFood(String localFoodUuid) async {
    await _outbox.enqueueDelete(localFoodUuid);
    unawaited(flush());
  }

  Future<void> flush() {
    final active = _activeFlush;
    if (active != null) return active;
    final run = _flushPending();
    _activeFlush = run;
    return run.whenComplete(() {
      if (identical(_activeFlush, run)) _activeFlush = null;
    });
  }

  Future<void> _flushPending() async {
    final cloud = _cloud;
    if (cloud == null) return;
    final entries = await _outbox.due();
    for (final entry in entries) {
      try {
        if (entry.operation == 'delete') {
          await cloud.withdraw(entry.localFoodUuid);
        } else {
          await cloud.upsert(entry.payload);
        }
        await _outbox.markSucceeded(entry.localFoodUuid);
      } catch (error) {
        await _outbox.markFailed(entry, error);
      }
    }
  }
}
