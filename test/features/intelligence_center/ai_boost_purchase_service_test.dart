import 'dart:async';

import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_benefit_delivery.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

class _Native extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  Future<bool> Function() launch = () async => true;
  Future<void> Function()? finish;
  bool finishFails = false;
  int launches = 0;
  int finishes = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          ProductDetails(
            id: AiBoostPurchaseService.productId,
            title: 'Boost',
            description: 'Native boundary fixture',
            price: '2.49',
            rawPrice: 2.49,
            currencyCode: 'USD',
          ),
        ],
        notFoundIDs: const [],
      );
  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) {
    expect(autoConsume, isFalse);
    launches++;
    return launch();
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    finishes++;
    if (finishFails) throw StateError('StoreKit finish unavailable');
    await finish?.call();
  }
}

PurchaseDetails _receipt(
  String id, [
  PurchaseStatus status = PurchaseStatus.purchased,
]) {
  final result = PurchaseDetails(
    purchaseID: id,
    productID: AiBoostPurchaseService.productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: 'fixture-$id',
      source: 'app_store',
    ),
    transactionDate: '1',
    status: status,
  );
  result.pendingCompletePurchase = true;
  return result;
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<AiBoostPurchaseService> create(
    _Native native, {
    String? Function()? owner,
    Future<bool> Function(PurchaseDetails, String)? verify,
    Future<List<PurchaseDetails>> Function()? reconcile,
    Stream<String?>? ownerChanges,
    Duration launchTimeout = const Duration(seconds: 1),
    Duration pendingTimeout = const Duration(seconds: 90),
  }) async {
    final service = AiBoostPurchaseService(
      purchase: native,
      owner: owner ?? () => 'owner-a',
      verify: verify ?? (_, _) async => true,
      ownerChanges: ownerChanges,
      reconcile: reconcile ?? () async => [],
      launchTimeout: launchTimeout,
      pendingTimeout: pendingTimeout,
    );
    addTearDown(() async {
      service.dispose();
      await native.updates.close();
    });
    await service.initialize();
    expect(service.canPurchase, isTrue);
    return service;
  }

  StoreBenefitDelivery inactiveDelivery(
    String owner, {
    String store = 'app_store',
  }) => StoreBenefitDelivery(
    ownerId: owner,
    store: store,
    environment: 'sandbox',
    eventKey: 'a' * 64,
    productId: AiBoostPurchaseService.productId,
    verifiedAt: DateTime.now().toUtc(),
    active: false,
    isBoost: true,
    finishPending: false,
    quantity: 0,
  );

  StoreBenefitDelivery finishProof({
    bool active = true,
    bool pending = true,
    String owner = 'owner-a',
    String event = 'a',
    String environment = 'sandbox',
    DateTime? at,
  }) => StoreBenefitDelivery(
    ownerId: owner,
    store: 'google_play',
    environment: environment,
    eventKey: event * 64,
    productId: AiBoostPurchaseService.productId,
    verifiedAt: at ?? DateTime.utc(2026, 10, 12, 12),
    active: active,
    isBoost: true,
    finishPending: pending,
    quantity: active ? 2500 : 0,
  );

  PurchaseDetails googleFinishReceipt(String id) => PurchaseDetails(
    purchaseID: id,
    productID: AiBoostPurchaseService.productId,
    status: PurchaseStatus.purchased,
    transactionDate: '1',
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: 'fixture-$id',
      source: 'google_play',
    ),
  )..pendingCompletePurchase = true;

  for (final retry in [false, true]) {
    test(
      'Google Boost refund during ${retry ? 'finish retry' : 'finish'} retires exact receipt and invalidates delivery',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final native = _Native();
        var verifyCalls = 0, finishCalls = 0;
        final finish = Completer<StoreVerificationOutcome>();
        final service = AiBoostPurchaseService(
          purchase: native,
          owner: () => 'owner-a',
          ownerChanges: const Stream.empty(),
          verifyDelivery: (_, _) async {
            verifyCalls++;
            return StoreVerificationOutcome(true, delivery: finishProof());
          },
          finishDelivery: (_, _) {
            finishCalls++;
            if (retry && finishCalls == 1) throw StateError('transient finish');
            return finish.future;
          },
        );
        addTearDown(() async {
          service.dispose();
          await native.updates.close();
        });
        await service.initialize();
        native.updates.add([googleFinishReceipt('refund-at-finish')]);
        await _settle();
        expect(service.verifiedCreditsRevision, 1);
        expect(service.deliveryIsActive('a' * 64), isTrue);
        expect(service.canPurchase, isFalse);
        final retried = retry
            ? service.retryPendingTransaction()
            : Future<void>.value();
        await _settle();
        finish.complete(
          StoreVerificationOutcome(
            true,
            delivery: finishProof(
              active: false,
              pending: false,
              at: DateTime.utc(2026, 10, 12, 12, 1),
            ),
          ),
        );
        await retried;
        await _settle();
        expect(service.state, AiBoostPurchaseState.ready);
        expect(service.errorCode, 'purchase_inactive');
        expect(service.lastDelivery!.active, isFalse);
        expect(service.lastDelivery!.quantity, 0);
        expect(service.deliveryIsActive('a' * 64), isFalse);
        expect(
          service.verifiedCreditsRevision,
          2,
          reason:
              'trusted delivery then invalidation; no local credit or refund',
        );
        expect(service.canRetry, isFalse);
        expect(service.canPurchase, isTrue);
        expect(verifyCalls, 1);
        expect(finishCalls, retry ? 2 : 1);
        expect(native.launches, 0);
        expect(native.finishes, 0);
        // Replayed old callback must not restore its already-revoked confirmation.
        native.updates.add([googleFinishReceipt('refund-at-finish')]);
        await _settle();
        expect(service.state, AiBoostPurchaseState.ready);
        expect(service.deliveryIsActive('a' * 64), isFalse);
        expect(service.verifiedCreditsRevision, 2);
        expect(finishCalls, retry ? 2 : 1);
      },
    );
  }
  test(
    'Google Boost finish refund from earlier A visit cannot affect A to B to A',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final native = _Native();
      final owners = StreamController<String?>.broadcast(sync: true);
      var owner = 'owner-a';
      final finish = Completer<StoreVerificationOutcome>();
      final service = AiBoostPurchaseService(
        purchase: native,
        owner: () => owner,
        ownerChanges: owners.stream,
        verifyDelivery: (_, _) async =>
            StoreVerificationOutcome(true, delivery: finishProof()),
        finishDelivery: (_, _) => finish.future,
      );
      addTearDown(() async {
        service.dispose();
        await owners.close();
        await native.updates.close();
      });
      await service.initialize();
      native.updates.add([googleFinishReceipt('old-visit-finish')]);
      await _settle();
      expect(service.verifiedCreditsRevision, 1);
      owner = 'owner-b';
      owners.add(owner);
      owner = 'owner-a';
      owners.add(owner);
      finish.complete(
        StoreVerificationOutcome(
          true,
          delivery: finishProof(active: false, pending: false),
        ),
      );
      await _settle();
      expect(service.lastDelivery, isNull);
      expect(service.deliveryIsActive('a' * 64), isFalse);
      expect(service.state, AiBoostPurchaseState.unavailable);
      expect(
        service.verifiedCreditsRevision,
        1,
        reason: 'old visit cannot publish a new revision',
      );
      expect(native.launches, 0);
      expect(native.finishes, 0);
    },
  );
  for (final mismatch in ['owner', 'event', 'environment', 'older']) {
    test(
      'Google Boost foreign or stale finish proof $mismatch keeps exact retry',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final native = _Native();
        final service = AiBoostPurchaseService(
          purchase: native,
          owner: () => 'owner-a',
          ownerChanges: const Stream.empty(),
          verifyDelivery: (_, _) async =>
              StoreVerificationOutcome(true, delivery: finishProof()),
          finishDelivery: (_, _) async => StoreVerificationOutcome(
            true,
            delivery: finishProof(
              active: false,
              pending: false,
              owner: mismatch == 'owner' ? 'owner-b' : 'owner-a',
              event: mismatch == 'event' ? 'b' : 'a',
              environment: mismatch == 'environment' ? 'production' : 'sandbox',
              at: mismatch == 'older' ? DateTime.utc(2026, 10, 11) : null,
            ),
          ),
        );
        addTearDown(() async {
          service.dispose();
          await native.updates.close();
        });
        await service.initialize();
        native.updates.add([googleFinishReceipt('bad-finish')]);
        await _settle();
        expect(service.errorCode, 'store_finish_pending');
        expect(service.canRetry, isTrue);
        expect(service.deliveryIsActive('a' * 64), isTrue);
        expect(service.verifiedCreditsRevision, 1);
        expect(native.launches, 0);
        expect(native.finishes, 0);
      },
    );
  }

  test(
    'cold Google canceled canonical receipt clears the old retry with no credit or native consume',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final native = _Native();
      var verifications = 0;
      final service = AiBoostPurchaseService(
        purchase: native,
        owner: () => 'owner-a',
        ownerChanges: const Stream.empty(),
        verifyDelivery: (_, owner) async {
          verifications++;
          return StoreVerificationOutcome(
            true,
            delivery: inactiveDelivery(owner, store: 'google_play'),
          );
        },
        reconcile: () async => [],
      );
      addTearDown(() async {
        service.dispose();
        await native.updates.close();
      });
      await service.initialize();
      final receipt = GooglePlayPurchaseDetails.fromPurchase(
        const PurchaseWrapper(
          orderId: 'fixture-canceled-order',
          packageName: 'com.bilhealth.bodyintelligencelog',
          purchaseTime: 1,
          signature: 'fixture-only',
          products: ['bil_ai_boost'],
          purchaseToken: 'fixture-canceled-token',
          isAutoRenewing: false,
          originalJson: '',
          developerPayload: '',
          isAcknowledged: false,
          purchaseState: PurchaseStateWrapper.purchased,
        ),
      ).single;
      // The old SDK receipt can replay while the authenticated canonical server
      // has already observed canceled. Its status alone never authorizes credit.
      native.updates.add([receipt]);
      await _settle();
      expect(verifications, 1);
      expect(service.state, AiBoostPurchaseState.ready);
      expect(service.errorCode, 'purchase_inactive');
      expect(service.lastDelivery!.active, isFalse);
      expect(service.lastDelivery!.quantity, 0);
      expect(native.finishes, 0);
      expect(native.launches, 0);
      expect(service.canRetry, isFalse);
      expect(service.canPurchase, isTrue);
      expect(service.verifiedCreditsRevision, 1);
    },
  );

  test(
    'canonical inactive Boost finishes without success or credit; finish failure retries',
    () async {
      final native = _Native()..finishFails = true;
      var verifications = 0;
      final service = AiBoostPurchaseService(
        purchase: native,
        owner: () => 'owner-a',
        ownerChanges: const Stream.empty(),
        verifyDelivery: (_, owner) async {
          verifications++;
          return StoreVerificationOutcome(
            true,
            delivery: inactiveDelivery(owner),
          );
        },
        reconcile: () async => [],
      );
      addTearDown(() async {
        service.dispose();
        await native.updates.close();
      });
      await service.initialize();
      native.updates.add([_receipt('refunded-canonical')]);
      await _settle();
      expect(service.state, AiBoostPurchaseState.ready);
      expect(service.errorCode, 'store_finish_pending');
      expect(service.lastDelivery!.active, isFalse);
      expect(service.lastDelivery!.quantity, 0);
      expect(service.deliveryIsActive('a' * 64), isFalse);
      expect(
        service.verifiedCreditsRevision,
        1,
        reason: 'reload authoritative balance only',
      );
      expect(service.canPurchase, isFalse);
      expect(service.canRetry, isTrue);
      native.finishFails = false;
      await service.retryPendingTransaction();
      expect(service.errorCode, 'purchase_inactive');
      expect(service.state, AiBoostPurchaseState.ready);
      expect(service.canPurchase, isTrue);
      expect(native.finishes, 2);
      expect(native.launches, 0);
      expect(verifications, 2);
      expect(service.verifiedCreditsRevision, 1);
    },
  );

  test(
    'inactive Boost response from earlier A visit cannot settle after A to B to A',
    () async {
      final native = _Native();
      final owners = StreamController<String?>.broadcast(sync: true);
      var owner = 'owner-a';
      final verification = Completer<StoreVerificationOutcome>();
      final service = AiBoostPurchaseService(
        purchase: native,
        owner: () => owner,
        ownerChanges: owners.stream,
        verifyDelivery: (_, _) => verification.future,
        reconcile: () async => [],
      );
      addTearDown(() async {
        service.dispose();
        await owners.close();
        await native.updates.close();
      });
      await service.initialize();
      native.updates.add([_receipt('old-a-inactive')]);
      await _settle();
      owner = 'owner-b';
      owners.add(owner);
      owner = 'owner-a';
      owners.add(owner);
      verification.complete(
        StoreVerificationOutcome(true, delivery: inactiveDelivery('owner-a')),
      );
      await _settle();
      expect(native.finishes, 0);
      expect(service.lastDelivery, isNull);
      expect(service.verifiedCreditsRevision, 0);
      expect(service.state, AiBoostPurchaseState.unavailable);
    },
  );

  test(
    'native launch exception is bounded and reconciles without new charge',
    () async {
      final native = _Native()
        ..launch = () async => throw StateError('native failure');
      final service = await create(native);
      await service.purchaseBoost();
      expect(service.state, AiBoostPurchaseState.failed);
      expect(service.errorCode, 'purchase_status_unknown');
      expect(service.canPurchase, isFalse);
      expect(service.canRetry, isTrue);
      await service.retryPendingTransaction();
      expect(service.canPurchase, isFalse);
      expect(service.errorCode, 'purchase_status_unknown');
      expect(native.launches, 1);
    },
  );

  test(
    'Apple authentication outlives catalog timeout without false failure',
    () async {
      final launch = Completer<bool>();
      final native = _Native()..launch = () => launch.future;
      final service = await create(
        native,
        launchTimeout: const Duration(milliseconds: 5),
        pendingTimeout: const Duration(milliseconds: 100),
      );
      final purchasing = service.purchaseBoost();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final stateWhileAuthenticating = service.state;
      final errorWhileAuthenticating = service.errorCode;
      await service.purchaseBoost();
      launch.complete(false);
      await purchasing;
      expect(stateWhileAuthenticating, AiBoostPurchaseState.pending);
      expect(errorWhileAuthenticating, isNull);
      expect(native.launches, 1);
      expect(service.verifiedCreditsRevision, 0);
      expect(service.state, AiBoostPurchaseState.ready);
      expect(service.errorCode, 'purchase_not_started');
    },
  );

  test(
    'hanging launch cannot leave pending forever or enable duplicate charge',
    () async {
      final native = _Native()..launch = () => Completer<bool>().future;
      final service = await create(
        native,
        launchTimeout: const Duration(milliseconds: 1),
        pendingTimeout: const Duration(milliseconds: 1),
      );
      await service.purchaseBoost();
      expect(service.state, AiBoostPurchaseState.failed);
      expect(service.errorCode, 'purchase_status_unknown');
      await service.purchaseBoost();
      expect(native.launches, 1);
    },
  );

  test(
    'cancellation returns actionable ready state without verification',
    () async {
      final native = _Native();
      var verifications = 0;
      final service = await create(
        native,
        verify: (_, _) async {
          verifications++;
          return true;
        },
      );
      await service.purchaseBoost();
      native.updates.add([_receipt('cancel', PurchaseStatus.canceled)]);
      await _settle();
      expect(service.canPurchase, isTrue);
      expect(service.errorCode, 'purchase_cancelled');
      expect(verifications, 0);
      expect(native.finishes, 0);
    },
  );

  test('false launch allows a real retry without fabricated credit', () async {
    final native = _Native()..launch = () async => false;
    final service = await create(native);
    await service.purchaseBoost();
    expect(service.state, AiBoostPurchaseState.ready);
    expect(service.canPurchase, isTrue);
    expect(service.verifiedCreditsRevision, 0);
  });

  test(
    'lost callback watchdog offers reconciliation, not a second charge',
    () async {
      final native = _Native();
      final service = await create(
        native,
        pendingTimeout: const Duration(milliseconds: 1),
      );
      await service.purchaseBoost();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(service.state, AiBoostPurchaseState.failed);
      expect(service.canPurchase, isFalse);
      await service.retryPendingTransaction();
      expect(service.canPurchase, isFalse);
      expect(service.errorCode, 'purchase_status_unknown');
      expect(native.launches, 1);
    },
  );

  test(
    'verified consumable can be purchased again in the same service',
    () async {
      final native = _Native();
      var verifications = 0;
      final service = await create(
        native,
        verify: (_, _) async {
          verifications++;
          return true;
        },
      );
      await service.purchaseBoost();
      native.updates.add([_receipt('first')]);
      await _settle();
      expect(service.state, AiBoostPurchaseState.verified);
      expect(service.canPurchase, isTrue);
      await service.purchaseBoost();
      native.updates.add([_receipt('second')]);
      await _settle();
      expect(native.launches, 2);
      expect(verifications, 2);
      expect(service.verifiedCreditsRevision, 2);
      expect(service.canPurchase, isTrue);
    },
  );

  test(
    'finish failure preserves verified credit and retries only existing transaction',
    () async {
      final native = _Native()..finishFails = true;
      var verifications = 0;
      final service = await create(
        native,
        verify: (_, _) async {
          verifications++;
          return true;
        },
      );
      native.updates.add([_receipt('credited')]);
      await _settle();
      expect(service.state, AiBoostPurchaseState.verified);
      expect(service.errorCode, 'store_finish_pending');
      expect(service.verifiedCreditsRevision, 1);
      expect(service.canPurchase, isFalse);
      native.finishFails = false;
      await service.retryPendingTransaction();
      expect(service.canPurchase, isTrue);
      expect(service.errorCode, isNull);
      expect(verifications, 1);
      expect(native.launches, 0);
      expect(native.finishes, 2);
    },
  );

  test(
    'verification failure stays unfinished and blocks new charge until retry',
    () async {
      final native = _Native();
      var verified = false;
      final service = await create(native, verify: (_, _) async => verified);
      native.updates.add([_receipt('unverified')]);
      await _settle();
      expect(service.state, AiBoostPurchaseState.failed);
      expect(service.canPurchase, isFalse);
      expect(native.finishes, 0);
      expect(service.verifiedCreditsRevision, 0);
      verified = true;
      await service.retryPendingTransaction();
      expect(service.canPurchase, isTrue);
      expect(native.finishes, 1);
      expect(native.launches, 0);
    },
  );

  test(
    'duplicate callbacks serialize and never duplicate credit publication',
    () async {
      final native = _Native();
      final verify = Completer<bool>();
      var verifications = 0;
      final service = await create(
        native,
        verify: (_, _) {
          verifications++;
          return verify.future;
        },
      );
      final receipt = _receipt('same');
      native.updates.add([receipt]);
      native.updates.add([receipt]);
      await _settle();
      expect(verifications, 1);
      expect(service.canPurchase, isFalse);
      verify.complete(true);
      await _settle();
      expect(verifications, 1);
      expect(service.verifiedCreditsRevision, 1);
      expect(service.canPurchase, isTrue);
    },
  );

  test('credited replay cannot replace a later pending consumable', () async {
    final native = _Native();
    var verifications = 0;
    final service = await create(
      native,
      verify: (_, _) async {
        verifications++;
        return true;
      },
    );
    final credited = _receipt('credited-before-next');
    native.updates.add([credited]);
    await _settle();
    expect(service.canPurchase, isTrue);
    await service.purchaseBoost();
    expect(service.state, AiBoostPurchaseState.pending);
    native.updates.add([credited]);
    await _settle();
    expect(service.state, AiBoostPurchaseState.pending);
    expect(service.canPurchase, isFalse);
    await service.purchaseBoost();
    expect(native.launches, 1);
    expect(verifications, 1);
    expect(service.verifiedCreditsRevision, 1);
    native.updates.add([_receipt('actual-next')]);
    await _settle();
    expect(service.canPurchase, isTrue);
    expect(verifications, 2);
    expect(service.verifiedCreditsRevision, 2);
  });

  test('retry and native replay share verification and finish queue', () async {
    final native = _Native();
    final retryStarted = Completer<void>();
    final verifyRetry = Completer<bool>();
    final finishRetry = Completer<void>();
    var verifications = 0;
    var activeFinishes = 0;
    var maximumActiveFinishes = 0;
    native.finish = () async {
      activeFinishes++;
      if (activeFinishes > maximumActiveFinishes) {
        maximumActiveFinishes = activeFinishes;
      }
      await finishRetry.future;
      activeFinishes--;
    };
    final service = await create(
      native,
      verify: (_, _) {
        verifications++;
        if (verifications == 1) return Future<bool>.value(false);
        if (!retryStarted.isCompleted) retryStarted.complete();
        return verifyRetry.future;
      },
    );
    final receipt = _receipt('retry-replayed');
    native.updates.add([receipt]);
    await _settle();
    expect(service.canRetry, isTrue);
    final retry = service.retryPendingTransaction();
    await retryStarted.future;
    native.updates.add([receipt]);
    await _settle();
    expect(verifications, 2);
    expect(service.canPurchase, isFalse);
    verifyRetry.complete(true);
    await _settle();
    expect(native.finishes, 1);
    expect(service.verifiedCreditsRevision, 1);
    expect(service.canPurchase, isFalse);
    finishRetry.complete();
    await retry;
    await _settle();
    expect(verifications, 2);
    expect(native.finishes, 2);
    expect(maximumActiveFinishes, 1);
    expect(service.verifiedCreditsRevision, 1);
    expect(service.canPurchase, isTrue);
    expect(native.launches, 0);
  });

  for (final status in [PurchaseStatus.canceled, PurchaseStatus.error]) {
    test(
      'credited ${status.name} replay cannot cancel a later purchase',
      () async {
        final native = _Native();
        final launch = Completer<bool>();
        final service = await create(native);
        native.updates.add([_receipt('old-terminal')]);
        await _settle();
        native.launch = () => launch.future;
        final pending = service.purchaseBoost();
        native.updates.add([_receipt('old-terminal', status)]);
        await _settle();
        expect(service.state, AiBoostPurchaseState.pending);
        expect(service.errorCode, isNull);
        expect(service.canPurchase, isFalse);
        expect(service.verifiedCreditsRevision, 1);
        // Ignoring a replay must also preserve the active launch generation,
        // rather than invalidating its real completion or cancelling its timer.
        launch.complete(false);
        await pending;
        expect(service.state, AiBoostPurchaseState.ready);
        expect(service.errorCode, 'purchase_not_started');
        expect(native.launches, 1);
      },
    );
  }

  test(
    'late launch failure cannot overwrite newer verified callback',
    () async {
      final native = _Native();
      final launch = Completer<bool>();
      native.launch = () => launch.future;
      final service = await create(native);
      final pending = service.purchaseBoost();
      native.updates.add([_receipt('newer')]);
      await _settle();
      launch.complete(false);
      await pending;
      expect(service.state, AiBoostPurchaseState.verified);
      expect(service.errorCode, isNull);
    },
  );

  test(
    'old owner verification cannot publish credit or finish for new owner',
    () async {
      final native = _Native();
      var owner = 'owner-a';
      final verify = Completer<bool>();
      final service = await create(
        native,
        owner: () => owner,
        verify: (_, _) => verify.future,
      );
      native.updates.add([_receipt('old-owner')]);
      await _settle();
      owner = 'owner-b';
      verify.complete(true);
      await _settle();
      expect(service.verifiedCreditsRevision, 0);
      expect(native.finishes, 0);
      expect(service.canPurchase, isFalse);
    },
  );
  test(
    'A to B to A retires Boost verification from the earlier A visit',
    () async {
      final native = _Native();
      var owner = 'owner-a';
      final changes = StreamController<String?>.broadcast(sync: true);
      addTearDown(changes.close);
      final verification = Completer<bool>();
      final service = await create(
        native,
        owner: () => owner,
        ownerChanges: changes.stream,
        verify: (_, _) => verification.future,
      );
      native.updates.add([_receipt('first-a-visit')]);
      await _settle();
      owner = 'owner-b';
      changes.add(owner);
      owner = 'owner-a';
      changes.add(owner);
      verification.complete(true);
      await _settle();
      expect(service.verifiedCreditsRevision, 0);
      expect(native.finishes, 0);
      expect(service.canPurchase, isFalse);
      expect(service.state, AiBoostPurchaseState.unavailable);
      await service.initialize();
      expect(service.canPurchase, isTrue);
    },
  );
  test('empty unfinished history cannot resolve an uncertain charge', () async {
    final native = _Native()
      ..launch = () async => throw StateError('uncertain native launch');
    final service = await create(native);
    await service.purchaseBoost();
    await service.retryPendingTransaction();
    expect(service.errorCode, 'purchase_status_unknown');
    expect(service.canPurchase, isFalse);
    expect(service.canRetry, isTrue);
    await service.purchaseBoost();
    expect(native.launches, 1);
  });
  test(
    'changed JWS does not turn the same platform transaction into a new delivery',
    () async {
      final native = _Native();
      var verifications = 0;
      final service = await create(
        native,
        verify: (_, _) async {
          verifications++;
          return true;
        },
      );
      native.updates.add([_receipt('stable-platform-id')]);
      await _settle();
      final replay = PurchaseDetails(
        purchaseID: 'stable-platform-id',
        productID: AiBoostPurchaseService.productId,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: 'rotated-signed-fixture',
          source: 'app_store',
        ),
        transactionDate: '1',
        status: PurchaseStatus.purchased,
      )..pendingCompletePurchase = true;
      native.updates.add([replay]);
      await _settle();
      expect(verifications, 1);
      expect(service.verifiedCreditsRevision, 1);
    },
  );
}
