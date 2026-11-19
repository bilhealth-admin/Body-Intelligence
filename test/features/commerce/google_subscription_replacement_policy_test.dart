import 'dart:async';

import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'store_native_purchase_completion_test.dart' as billing;

class _UnusedNative extends Fake implements InAppPurchase {}

const _owner = 'synthetic-owner';
const _old = StoreCatalogConfiguration.premiumAiCoachMonthly;
const _new = StoreCatalogConfiguration.premiumAiCoachAnnual;
final _now = DateTime.utc(2026, 11, 18, 12);
Map<String, dynamic> _row() => {
  'owner_id': _owner,
  'provider': 'google',
  'product_id': _old,
  'plan_id': 'premium_ai_coach',
  'lifecycle': 'active',
  'latest_transaction_id': 'synthetic-fresh-token',
  'revision': 1,
  'verified_at': _now.toIso8601String(),
  'started_at': _now.subtract(const Duration(minutes: 1)).toIso8601String(),
  'expires_at': _now.add(const Duration(minutes: 5)).toIso8601String(),
  'auto_renews': true,
};
GooglePlayPurchaseDetails _owned() => billing.googleSubscription(
  product: _old,
  acknowledged: true,
  token: 'synthetic-fresh-token',
  packageName: StoreCatalogConfiguration.packageName,
);

void main() {
  test(
    'replacement read starts both sources in parallel and retires owner ABA',
    () async {
      final inventory = Completer<QueryPurchaseDetailsResponse>();
      final canonical = Completer<List<Map<String, dynamic>>>();
      var inventoryStarted = false, canonicalStarted = false, epoch = 0;
      final reader = GoogleSubscriptionReplacementReader(
        inventoryReader: (_) {
          inventoryStarted = true;
          return inventory.future;
        },
        canonicalReader: (_) {
          canonicalStarted = true;
          return canonical.future;
        },
        clock: () => _now,
      );
      final read = reader.read(
        purchase: _UnusedNative(),
        owner: _owner,
        targetProductId: _new,
        current: () => epoch == 0,
      );
      await Future<void>.delayed(Duration.zero);
      expect(inventoryStarted && canonicalStarted, isTrue);
      epoch = 2;
      inventory.complete(
        QueryPurchaseDetailsResponse(pastPurchases: [_owned()]),
      );
      canonical.complete([_row()]);
      final result = await read;
      expect(result.decision, GoogleReplacementDecision.unavailable);
      expect(result.previous, isNull);
    },
  );

  test(
    'the exact old paid period cannot authorize replacement at its expiry',
    () async {
      final row = _row();
      final reader = GoogleSubscriptionReplacementReader(
        inventoryReader: (_) async =>
            QueryPurchaseDetailsResponse(pastPurchases: [_owned()]),
        canonicalReader: (_) async => [row],
        clock: () => _now,
      );
      final result = await reader.read(
        purchase: _UnusedNative(),
        owner: _owner,
        targetProductId: _new,
        current: () => true,
      );
      expect(result.decision, GoogleReplacementDecision.replace);
      final boundary = DateTime.parse(row['expires_at'] as String);
      expect(
        result.validAt(boundary.subtract(const Duration(microseconds: 1))),
        isTrue,
      );
      expect(result.validAt(boundary), isFalse);
    },
  );

  for (final shape in [
    'absent',
    'terminal',
    'pending-past-end',
    'renewal-ambiguous',
    'wrong-owner',
    'bad-revision',
    'bad-time',
    'two-rows',
    'native-error',
  ]) {
    test(
      'replacement policy distinguishes $shape without invented empty proof',
      () async {
        final row = _row();
        var rows = [row];
        if (shape == 'absent') rows = [];
        if (shape == 'terminal') row['lifecycle'] = 'expired';
        if (shape == 'pending-past-end' || shape == 'renewal-ambiguous') {
          row['expires_at'] = _now
              .subtract(const Duration(seconds: 1))
              .toIso8601String();
          row['lifecycle'] = shape == 'pending-past-end' ? 'pending' : 'active';
          row['auto_renews'] = shape != 'pending-past-end';
        }
        if (shape == 'wrong-owner') row['owner_id'] = 'another-owner';
        if (shape == 'bad-revision') row['revision'] = 'corrupt';
        if (shape == 'bad-time') row['verified_at'] = 'corrupt';
        if (shape == 'two-rows') rows = [row, Map<String, dynamic>.from(row)];
        final reader = GoogleSubscriptionReplacementReader(
          inventoryReader: (_) async => QueryPurchaseDetailsResponse(
            pastPurchases: const [],
            error: shape == 'native-error'
                ? IAPError(
                    source: 'synthetic',
                    code: 'unavailable',
                    message: 'Synthetic',
                  )
                : null,
          ),
          canonicalReader: (_) async => rows,
          clock: () => _now,
        );
        final result = await reader.read(
          purchase: _UnusedNative(),
          owner: _owner,
          targetProductId: _new,
          current: () => true,
        );
        expect(
          result.decision,
          shape == 'absent' || shape == 'terminal'
              ? GoogleReplacementDecision.clear
              : const {'pending-past-end', 'renewal-ambiguous'}.contains(shape)
              ? GoogleReplacementDecision.blocked
              : GoogleReplacementDecision.unavailable,
        );
        expect(result.previous, isNull);
      },
    );
  }
}
