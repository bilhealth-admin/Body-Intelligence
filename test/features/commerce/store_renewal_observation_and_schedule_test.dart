import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/store_renewal_observation.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/providers/store_renewal_recheck_provider.dart';
import 'package:flutter_test/flutter_test.dart';

final end = DateTime.utc(2026, 11, 18, 14, 31);
Map<String, dynamic> row(String provider) => {
  'owner_id': 'owner',
  'provider': provider,
  'plan_id': 'premium_ai_coach',
  'lifecycle': 'active',
  'auto_renews': true,
  'started_at': end.subtract(const Duration(minutes: 30)).toIso8601String(),
  'expires_at': end.toIso8601String(),
  'verified_at': end.subtract(const Duration(minutes: 29)).toIso8601String(),
  'original_transaction_id': 'private-synthetic-lineage',
  'revision': 7,
};

void main() {
  for (final provider in ['google', 'apple']) {
    test('$provider observation has no serializer or paid authority', () {
      final hint = StoreRenewalObservation.fromCanonicalRow(
        row(provider),
        ownerId: 'owner',
      )!;
      expect(hint.provider.name, provider);
      expect(hint.hadAiAllowance, isTrue);
      expect(hint.pendingAt(end), isTrue);
      expect(
        () => jsonEncode(hint),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });
    test('$provider uses only the official grace end for read scheduling', () {
      final data = row(provider)
        ..['lifecycle'] = 'grace_period'
        ..['grace_period_ends_at'] = end
            .add(const Duration(days: 3))
            .toIso8601String();
      final hint = StoreRenewalObservation.fromCanonicalRow(
        data,
        ownerId: 'owner',
      )!;
      expect(hint.pendingAt(end), isFalse);
      expect(hint.pendingAt(end.add(const Duration(days: 3))), isTrue);
      expect(hint.periodEnd, end);
    });
  }
  for (final lifecycle in [
    'cancelled',
    'refunded',
    'revoked',
    'account_hold',
    'paused',
  ]) {
    test('$lifecycle cannot create a renewal ambiguity observation', () {
      final data = row('apple')..['lifecycle'] = lifecycle;
      expect(
        StoreRenewalObservation.fromCanonicalRow(data, ownerId: 'owner'),
        isNull,
      );
    });
  }
  test(
    'expired nonrenewing is definitive; expired renewing metadata grants no interval',
    () {
      final data = row('google')
        ..['lifecycle'] = 'expired'
        ..['auto_renews'] = false;
      expect(
        StoreRenewalObservation.fromCanonicalRow(data, ownerId: 'owner'),
        isNull,
      );
      expect(storeRenewalTerminalLifecycle('expired', false), isTrue);
      data['auto_renews'] = true;
      expect(
        StoreRenewalObservation.fromCanonicalRow(
          data,
          ownerId: 'owner',
        )!.pendingAt(end),
        isTrue,
      );
    },
  );
  test('future Apple start is pending display only, never moved to now', () {
    final data = row('apple')
      ..['started_at'] = end.add(const Duration(seconds: 13)).toIso8601String()
      ..['expires_at'] = end.add(const Duration(minutes: 3)).toIso8601String();
    final hint = StoreRenewalObservation.fromCanonicalRow(
      data,
      ownerId: 'owner',
    )!;
    expect(hint.pendingAt(end), isTrue);
    expect(hint.periodStart, end.add(const Duration(seconds: 13)));
    expect(hint.pendingAt(end.add(const Duration(seconds: 13))), isFalse);
  });
  testWidgets(
    'one bounded shared burst never overlaps refresh and retires late owner work',
    (tester) async {
      var current = true, loading = false, reads = 0, calls = 0;
      final held = Completer<void>();
      final hint = StoreRenewalObservation.fromCanonicalRow(
        row('apple'),
        ownerId: 'owner',
      )!;
      final burst = StoreRenewalReadBurst(
        ownerId: 'owner',
        now: () => end,
        current: () => current,
        relevant: (_) => true,
        loading: () => loading,
        refresh: () => reads++,
        reconcile: () {
          calls++;
          return held.future;
        },
      );
      try {
        burst.begin(hint);
        await tester.pump(Duration.zero);
        expect(calls, 1);
        loading = true;
        await tester.pump(const Duration(seconds: 10));
        expect(calls, 1);
        expect(reads, 0);
        current = false;
        held.complete();
        await tester.pump();
        expect(reads, 0);
        await tester.pump(const Duration(seconds: 30));
        expect(calls, 1);
      } finally {
        burst.dispose();
      }
    },
  );
  testWidgets(
    'timeout does not accept a late reload and requires explicit retry',
    (tester) async {
      var reads = 0, calls = 0;
      final held = Completer<void>();
      final hint = StoreRenewalObservation.fromCanonicalRow(
        row('google'),
        ownerId: 'owner',
      )!;
      final burst = StoreRenewalReadBurst(
        ownerId: 'owner',
        now: () => end,
        current: () => true,
        relevant: (_) => true,
        loading: () => false,
        refresh: () => reads++,
        reconcile: () {
          calls++;
          return held.future;
        },
      );
      try {
        burst.begin(hint);
        await tester.pump(Duration.zero);
        await tester.pump(const Duration(seconds: 25));
        expect(burst.timedOut(hint), isTrue);
        final before = reads;
        held.complete();
        await tester.pump();
        expect(reads, before);
        burst.begin(hint);
        await tester.pump(Duration.zero);
        expect(calls, 1);
      } finally {
        burst.dispose();
      }
    },
  );
  test(
    'provider is part of period identity; equal dates cannot borrow another store flight',
    () {
      final google = StoreRenewalObservation.fromCanonicalRow(
        row('google'),
        ownerId: 'owner',
      )!;
      final apple = StoreRenewalObservation.fromCanonicalRow(
        row('apple'),
        ownerId: 'owner',
      )!;
      expect(google.periodKey, isNot(apple.periodKey));
      expect(google.provider, SubscriptionProvider.google);
    },
  );
}
