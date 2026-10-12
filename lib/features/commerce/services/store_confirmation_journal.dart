import 'dart:convert';
import '../../../data/repositories/preferences_repository.dart';
import '../domain/store_benefit_delivery.dart';

/// Visual receipt journal only; never changes a balance or grants access.
/// Reserving suppresses replay after a crash, even if painting did not finish.
/// Purchase rights remain in the server ledger independently of this policy.
final class StoreConfirmationJournal {
  StoreConfirmationJournal(this.preferences, this.isCurrent);
  final PreferencesRepository preferences;
  final bool Function() isCurrent;
  String key(StoreBenefitDelivery event) =>
      'experience.store_confirmation.v1.${event.eventKey}';

  Future<bool> enqueue(
    StoreBenefitDelivery event, {
    required bool userInitiated,
  }) async {
    if (!isCurrent() || !event.active) return false;
    final raw = await preferences.get(key(event));
    if (!isCurrent()) return false;
    if (raw != null) {
      final previous = _decode(raw);
      final created = DateTime.tryParse('${previous?['created_at']}');
      return previous?['state'] == 'waiting' &&
          previous?['owner_id'] == event.ownerId &&
          previous?['environment'] == event.environment &&
          created != null &&
          DateTime.now().toUtc().difference(created).inHours < 24;
    }
    if (!userInitiated) return false;
    return preferences.mutateIfUnchanged(
      expected: {key(event): null},
      set: {
        key(event): jsonEncode({
          'state': 'waiting',
          'owner_id': event.ownerId,
          'environment': event.environment,
          'product_id': event.productId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
      },
      isCurrent: isCurrent,
    );
  }

  Future<bool> reserve(StoreBenefitDelivery event) =>
      _transition(event, 'waiting', 'reserved');
  Future<bool> painted(StoreBenefitDelivery event) =>
      _transition(event, 'reserved', 'shown');
  Future<bool> cancel(StoreBenefitDelivery event) async {
    final raw = await preferences.get(key(event));
    final status = _decode(raw)?['state'];
    if (status != 'waiting' && status != 'reserved') return false;
    return _transition(event, status as String, 'cancelled');
  }

  Future<bool> _transition(
    StoreBenefitDelivery event,
    String from,
    String to,
  ) async {
    if (!isCurrent()) return false;
    final raw = await preferences.get(key(event));
    final row = _decode(raw);
    if (!isCurrent() ||
        row?['state'] != from ||
        row?['owner_id'] != event.ownerId ||
        row?['environment'] != event.environment) {
      return false;
    }
    return preferences.mutateIfUnchanged(
      expected: {key(event): raw},
      set: {
        key(event): jsonEncode({...row!, 'state': to}),
      },
      isCurrent: isCurrent,
    );
  }

  Map<String, Object?>? _decode(String? raw) {
    try {
      final decoded = jsonDecode(raw ?? '');
      return decoded is Map ? Map<String, Object?>.from(decoded) : null;
    } on Object {
      return null;
    }
  }
}
