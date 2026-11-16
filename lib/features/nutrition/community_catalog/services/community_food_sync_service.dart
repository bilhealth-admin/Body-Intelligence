import 'dart:async';

import '../data/community_food_outbox_store.dart';
import '../data/supabase_community_food_catalog.dart';

class CommunityFoodSyncService {
  CommunityFoodSyncService(
    this._outbox,
    this._cloud, {
    bool Function()? isCurrent,
  }) : _isCurrent = isCurrent ?? (() => true);

  final CommunityFoodOutboxStore _outbox;
  final CommunityFoodCloudGateway? _cloud;
  final bool Function() _isCurrent;
  Future<void>? _activeFlush;

  Future<void> withdrawFood(String localFoodUuid) async {
    if (!_isCurrent()) return;
    await _outbox.enqueueDelete(localFoodUuid);
    if (_isCurrent()) unawaited(flush());
  }

  Future<void> flush() {
    if (!_isCurrent()) return Future<void>.value();
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
    if (cloud == null || !_isCurrent()) return;
    final List<CommunityFoodOutboxEntry> entries;
    try {
      entries = await _outbox.due();
    } on Object {
      // Provider disposal retires/closes the former owner's database. Its
      // pending read must not become an unhandled background flush error.
      if (!_isCurrent()) return;
      rethrow;
    }
    for (final entry in entries) {
      if (!_isCurrent()) return;
      // This service has no publication authority. A legacy or unexpected
      // upsert stays local even if an outbox implementation returns it.
      if (entry.operation != 'delete') continue;
      try {
        await cloud.withdraw(entry.localFoodUuid);
        if (!_isCurrent()) return;
        await _outbox.markSucceeded(entry.localFoodUuid);
      } catch (error) {
        if (!_isCurrent()) return;
        await _outbox.markFailed(entry, error);
      }
    }
  }
}
