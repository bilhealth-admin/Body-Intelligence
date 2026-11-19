import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/app/security/bil_integrity_exception.dart';
import 'package:body_intelligence_log/features/commerce/services/android_store_purchase_readiness.dart';
import 'package:body_intelligence_log/features/commerce/services/store_account_visit.dart';

const owner = '00000000-0000-4000-8000-000000000001';
const denial = BilIntegrityException(
  'license_unlicensed',
  recoveryHandle: 'opaque-native-handle',
  recoveryOwner: owner,
);
void main() {
  test(
    'fresh positive proof permits only the original explicit intent',
    () async {
      var probes = 0, dialogs = 0;
      final gate = AndroidStorePurchaseReadiness(
        probe: (_, _) async {
          probes++;
        },
        recover: (_) async {
          dialogs++;
          return true;
        },
        release: (_) async {},
      );
      expect(
        await gate.check(
          ownerId: owner,
          productId: 'bil_ai_boost',
          isCurrent: () => true,
        ),
        AndroidPurchaseReadiness.ready,
      );
      expect(probes, 1);
      expect(dialogs, 0);
    },
  );
  test(
    'GET_LICENSED interaction plus fresh proof requires another explicit Buy',
    () async {
      final attempts = <String>[];
      var dialogs = 0;
      final gate = AndroidStorePurchaseReadiness(
        probe: (_, attempt) async {
          attempts.add(attempt);
          if (attempts.length == 1) throw denial;
        },
        recover: (_) async {
          dialogs++;
          return true;
        },
        release: (_) async {},
      );
      expect(
        await gate.check(
          ownerId: owner,
          productId: 'bil_ai_boost',
          isCurrent: () => true,
        ),
        AndroidPurchaseReadiness.reviewRequired,
      );
      expect(dialogs, 1);
      expect(attempts.length, 2);
      expect(attempts[1], isNot(attempts[0]));
      expect(
        await gate.check(
          ownerId: owner,
          productId: 'bil_ai_boost',
          isCurrent: () => true,
        ),
        AndroidPurchaseReadiness.ready,
      );
      expect(attempts.length, 3);
      expect(dialogs, 1);
    },
  );
  test(
    'cancelled/unavailable native dialog does not reattest or retry it',
    () async {
      var probes = 0, dialogs = 0;
      final released = <String>[];
      final gate = AndroidStorePurchaseReadiness(
        probe: (_, _) async {
          probes++;
          throw denial;
        },
        recover: (_) async {
          dialogs++;
          return false;
        },
        release: (h) async {
          released.add(h);
        },
      );
      expect(
        await gate.check(
          ownerId: owner,
          productId: 'bil_ai_boost',
          isCurrent: () => true,
        ),
        AndroidPurchaseReadiness.licenseRequired,
      );
      expect(probes, 1);
      expect(dialogs, 1);
      expect(released, [denial.recoveryHandle]);
    },
  );
  test(
    'successful dialog alone never licenses; second denial gets no second dialog',
    () async {
      var probes = 0, dialogs = 0;
      final gate = AndroidStorePurchaseReadiness(
        probe: (_, _) async {
          probes++;
          throw denial;
        },
        recover: (_) async {
          dialogs++;
          return true;
        },
        release: (_) async {},
      );
      expect(
        await gate.check(
          ownerId: owner,
          productId: 'bil_ai_boost',
          isCurrent: () => true,
        ),
        AndroidPurchaseReadiness.licenseRequired,
      );
      expect(probes, 2);
      expect(dialogs, 1);
    },
  );
  for (final error in [
    const BilIntegrityException('integrity_backend_unavailable'),
    const BilIntegrityException('license_unlicensed'),
    const BilIntegrityException(
      'license_unlicensed',
      recoveryHandle: 'stale',
      recoveryOwner: 'other',
    ),
    const BilIntegrityException(
      'device_integrity_missing',
      recoveryHandle: 'x',
      recoveryOwner: owner,
    ),
  ]) {
    test(
      'nonrecoverable ${error.code}/${error.recoveryHandle} cannot open dialog',
      () async {
        var dialogs = 0;
        final gate = AndroidStorePurchaseReadiness(
          probe: (_, _) async => throw error,
          recover: (_) async {
            dialogs++;
            return true;
          },
          release: (_) async {},
        );
        expect(
          await gate.check(
            ownerId: owner,
            productId: 'bil_ai_boost',
            isCurrent: () => true,
          ),
          AndroidPurchaseReadiness.unavailable,
        );
        expect(dialogs, 0);
      },
    );
  }
  for (final heldAtDialog in [false, true]) {
    test(
      'owner A B A retires held ${heldAtDialog ? 'dialog' : 'probe'} continuation',
      () async {
        var currentOwner = owner, dialogs = 0;
        final owners = StreamController<String?>.broadcast(sync: true);
        final visit = StoreAccountVisit(
          readOwner: () => currentOwner,
          changes: owners.stream,
        );
        final captured = visit.capture();
        final held = Completer<void>();
        final entered = Completer<void>();
        final gate = AndroidStorePurchaseReadiness(
          probe: (_, _) async {
            if (!heldAtDialog) {
              entered.complete();
              await held.future;
            }
            throw denial;
          },
          recover: (_) async {
            dialogs++;
            entered.complete();
            await held.future;
            return true;
          },
          release: (_) async {},
        );
        final pending = gate.check(
          ownerId: owner,
          productId: 'bil_ai_boost',
          isCurrent: () => visit.isCurrent(captured),
        );
        await entered.future;
        currentOwner = 'owner-b';
        owners.add(currentOwner);
        currentOwner = owner;
        owners.add(currentOwner);
        held.complete();
        expect(await pending, AndroidPurchaseReadiness.retired);
        expect(dialogs, heldAtDialog ? 1 : 0);
        visit.dispose();
        await owners.close();
      },
    );
  }
  test(
    'duplicate intent and timeout cannot revive late positive proof',
    () async {
      final held = Completer<void>();
      var probes = 0;
      final gate = AndroidStorePurchaseReadiness(
        timeout: const Duration(milliseconds: 10),
        probe: (_, _) {
          probes++;
          return held.future;
        },
        recover: (_) async => true,
        release: (_) async {},
      );
      final first = gate.check(
        ownerId: owner,
        productId: 'bil_ai_boost',
        isCurrent: () => true,
      );
      expect(
        await gate.check(
          ownerId: owner,
          productId: 'bil_ai_boost',
          isCurrent: () => true,
        ),
        AndroidPurchaseReadiness.retired,
      );
      expect(await first, AndroidPurchaseReadiness.unavailable);
      held.complete();
      await Future<void>.delayed(Duration.zero);
      expect(probes, 1);
    },
  );
  test(
    'separate subscription/Boost service gates share one bounded readiness flight',
    () async {
      final held = Completer<void>();
      var secondProbes = 0;
      final first = AndroidStorePurchaseReadiness(
        probe: (_, _) => held.future,
        recover: (_) async => true,
        release: (_) async {},
      );
      final second = AndroidStorePurchaseReadiness(
        probe: (_, _) async {
          secondProbes++;
        },
        recover: (_) async => true,
        release: (_) async {},
      );
      final pending = first.check(
        ownerId: owner,
        productId: 'bil_premium_ai_coach',
        isCurrent: () => true,
      );
      expect(
        await second.check(
          ownerId: owner,
          productId: 'bil_ai_boost',
          isCurrent: () => true,
        ),
        AndroidPurchaseReadiness.retired,
      );
      expect(secondProbes, 0);
      held.complete();
      await pending;
      expect(
        await second.check(
          ownerId: owner,
          productId: 'bil_ai_boost',
          isCurrent: () => true,
        ),
        AndroidPurchaseReadiness.ready,
      );
      expect(secondProbes, 1);
    },
  );
  test('disposed visit cannot even request token or open dialog', () async {
    final visit = StoreAccountVisit(readOwner: () => owner);
    final snapshot = visit.capture();
    visit.dispose();
    var calls = 0;
    final gate = AndroidStorePurchaseReadiness(
      probe: (_, _) async {
        calls++;
      },
      recover: (_) async {
        calls++;
        return true;
      },
      release: (_) async {},
    );
    expect(
      await gate.check(
        ownerId: owner,
        productId: 'bil_ai_boost',
        isCurrent: () => visit.isCurrent(snapshot),
      ),
      AndroidPurchaseReadiness.retired,
    );
    expect(calls, 0);
  });
}
