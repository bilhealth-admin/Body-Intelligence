import 'dart:convert';
import '../../../data/repositories/preferences_repository.dart';
import '../domain/store_benefit_delivery.dart';

/// Visual receipt journal only; never changes a balance or grants access.
/// Reservations in this process prevent duplicate presentation. An unpainted
/// dialog may recover just once after a process restart. This is only a visual
/// event journal; verified subscription rights and balances are independent.
/// Purchase rights remain in the server ledger independently of this policy.
final class StoreConfirmationJournal {
  StoreConfirmationJournal(
    this.preferences,
    this.isCurrent, {
    String? processSession,
    DateTime Function()? clock,
  }) : _session = processSession ?? _defaultProcessSession,
       _now = clock ?? DateTime.now;

  static final String _defaultProcessSession = DateTime.now()
      .microsecondsSinceEpoch
      .toRadixString(36);
  final PreferencesRepository preferences;
  final bool Function() isCurrent;
  final String _session;
  final DateTime Function() _now;
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
      final created = DateTime.tryParse('${previous?['created_at']}')?.toUtc();
      final age = created == null ? null : _now().toUtc().difference(created);
      if (previous == null ||
          previous['owner_id'] != event.ownerId ||
          previous['environment'] != event.environment ||
          previous['product_id'] != event.productId ||
          age == null ||
          age.isNegative ||
          age >= const Duration(hours: 24)) {
        return false;
      }
      if (previous['state'] == 'waiting') return true;

      // No replay while the same Flutter process may still be painting a
      // dialog. Recovery requires a different process and is one-time only.
      if (previous['state'] != 'reserved' ||
          previous['recovery_used'] == true ||
          previous['reservation_session'] == _session) {
        return false;
      }
      if (previous['reservation_session'] == null &&
          age < const Duration(minutes: 2)) {
        // Older versions have no process identifier. Give their potentially
        // live presentation a safe cooldown before any one-time recovery.
        return false;
      }
      return preferences.mutateIfUnchanged(
        expected: {key(event): raw},
        set: {
          key(event): jsonEncode({
            ...previous,
            'state': 'waiting',
            'recovery_used': true,
          }),
        },
        isCurrent: isCurrent,
      );
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
          'created_at': _now().toUtc().toIso8601String(),
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
        key(event): jsonEncode({
          ...row!,
          'state': to,
          if (to == 'reserved') 'reservation_session': _session,
        }),
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
