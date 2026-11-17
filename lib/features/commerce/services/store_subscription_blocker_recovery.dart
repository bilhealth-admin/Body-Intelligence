import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/commerce_plan.dart';
import '../domain/free_plan.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/subscription_state.dart';
import 'store_account_visit.dart';

enum StoreSubscriptionBlockerRecoveryResult {
  eligible,
  blocked,
  unavailable,
  ownerChanged,
}

/// Counts are only negative evidence for retiring stale checkout decoration.
/// They never identify an owner, grant access, or acknowledge a transaction.
final class NativeStoreSubscriptionInventory {
  const NativeStoreSubscriptionInventory({
    required this.currentEntitlementCount,
    required this.unfinishedCount,
  });

  final int currentEntitlementCount;
  final int unfinishedCount;

  bool get isValid =>
      currentEntitlementCount >= 0 &&
      currentEntitlementCount <= 10000 &&
      unfinishedCount >= 0 &&
      unfinishedCount <= 10000;
  bool get isEmpty =>
      isValid && currentEntitlementCount == 0 && unfinishedCount == 0;
}

abstract interface class StoreSubscriptionInventoryReader {
  Future<NativeStoreSubscriptionInventory> read();
}

final class NativeStoreSubscriptionInventoryReader
    implements StoreSubscriptionInventoryReader {
  const NativeStoreSubscriptionInventoryReader({
    this._channel = const MethodChannel(
      'bil/store_subscription_blocker_recovery',
    ),
  });

  final MethodChannel _channel;

  @override
  Future<NativeStoreSubscriptionInventory> read() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError('store_inventory_unsupported');
    }
    final result = await _channel
        .invokeMethod<Object?>('readInventory')
        .timeout(const Duration(seconds: 8));
    if (result is! Map ||
        result.length != 3 ||
        result['scopeVersion'] is! int ||
        result['scopeVersion'] != 1 ||
        result['currentEntitlementCount'] is! int ||
        result['unfinishedCount'] is! int) {
      throw const FormatException('store_inventory_invalid');
    }
    final inventory = NativeStoreSubscriptionInventory(
      currentEntitlementCount: result['currentEntitlementCount'] as int,
      unfinishedCount: result['unfinishedCount'] as int,
    );
    if (!inventory.isValid) {
      throw const FormatException('store_inventory_invalid');
    }
    return inventory;
  }
}

final class StoreSubscriptionBlockerRecoveryContext {
  const StoreSubscriptionBlockerRecoveryContext({
    required this.failedSubscriptionProductId,
    required this.hasUnresolvedReceipt,
    required this.hasPendingVerifiedFinish,
    required this.hasQueuedUpdates,
    required this.hasUnknownPurchase,
    required this.hasOwnershipConflict,
    required this.hasConsumableFailure,
    required this.isBackedOff,
    required this.hasNativeActivity,
  });

  final String? failedSubscriptionProductId;
  final bool hasUnresolvedReceipt;
  final bool hasPendingVerifiedFinish;
  final bool hasQueuedUpdates;
  final bool hasUnknownPurchase;
  final bool hasOwnershipConflict;
  final bool hasConsumableFailure;
  final bool isBackedOff;
  final bool hasNativeActivity;

  bool get permitsReadOnlyProof =>
      failedSubscriptionProductId != null &&
      StoreCatalogConfiguration.bindingForProduct(
            failedSubscriptionProductId!,
          ) !=
          null &&
      !hasUnresolvedReceipt &&
      !hasPendingVerifiedFinish &&
      !hasQueuedUpdates &&
      !hasUnknownPurchase &&
      !hasOwnershipConflict &&
      !hasConsumableFailure &&
      !isBackedOff &&
      !hasNativeActivity;
}

/// An explicit action may request this proof; success authorizes only the
/// caller's fenced retirement of stale subscription UI state. The caller must
/// recheck its generation/phase fence when consuming the result. No state is
/// written here, and no purchase, restore, sync, finish or receipt delete runs.
final class StoreSubscriptionBlockerRecovery {
  const StoreSubscriptionBlockerRecovery({
    required this._freshCanonicalReader,
    this._nativeReader = const NativeStoreSubscriptionInventoryReader(),
    this._readTimeout = const Duration(seconds: 8),
  });

  final Future<SubscriptionState> Function() _freshCanonicalReader;
  final StoreSubscriptionInventoryReader _nativeReader;
  final Duration _readTimeout;

  Future<StoreSubscriptionBlockerRecoveryResult> assess({
    required StoreSubscriptionBlockerRecoveryContext Function() currentContext,
    required StoreAccountSnapshot expectedVisit,
    required bool Function(StoreAccountSnapshot) visitIsCurrent,
  }) async {
    String? product;
    StoreSubscriptionBlockerRecoveryResult? fence() {
      if (expectedVisit.ownerId == null ||
          expectedVisit.ownerId!.isEmpty ||
          !visitIsCurrent(expectedVisit)) {
        return StoreSubscriptionBlockerRecoveryResult.ownerChanged;
      }
      final context = currentContext();
      if (!context.permitsReadOnlyProof ||
          (product != null && context.failedSubscriptionProductId != product)) {
        return StoreSubscriptionBlockerRecoveryResult.blocked;
      }
      product ??= context.failedSubscriptionProductId;
      return null;
    }

    try {
      final initial = fence();
      if (initial != null) return initial;
      final first = await _nativeReader.read().timeout(_readTimeout);
      final afterFirst = fence();
      if (afterFirst != null) return afterFirst;
      if (!first.isValid) {
        return StoreSubscriptionBlockerRecoveryResult.unavailable;
      }
      if (!first.isEmpty) return StoreSubscriptionBlockerRecoveryResult.blocked;
      // This is deliberately after the explicit action and first native read.
      // Production must inject currentForExplicitStoreRecovery, not a cached
      // provider, continuity fallback, or purchase handoff.
      final canonical = await _freshCanonicalReader().timeout(_readTimeout);
      final afterCanonical = fence();
      if (afterCanonical != null) return afterCanonical;
      if (canonical.authority != EntitlementAuthority.verifiedServer) {
        return StoreSubscriptionBlockerRecoveryResult.unavailable;
      }
      if (canonical.plan != CommercePlan.free ||
          canonical.entitlements.difference(FreePlan.entitlements).isNotEmpty ||
          canonical.verifiedNextPeriod != null) {
        return StoreSubscriptionBlockerRecoveryResult.blocked;
      }
      final second = await _nativeReader.read().timeout(_readTimeout);
      final afterSecond = fence();
      if (afterSecond != null) return afterSecond;
      if (!second.isValid) {
        return StoreSubscriptionBlockerRecoveryResult.unavailable;
      }
      return second.isEmpty
          ? StoreSubscriptionBlockerRecoveryResult.eligible
          : StoreSubscriptionBlockerRecoveryResult.blocked;
    } on Object {
      // A read, verification, timeout or unsupported platform cannot be
      // converted into an empty StoreKit inventory or a fresh Free proof.
      try {
        return expectedVisit.ownerId == null ||
                expectedVisit.ownerId!.isEmpty ||
                !visitIsCurrent(expectedVisit)
            ? StoreSubscriptionBlockerRecoveryResult.ownerChanged
            : StoreSubscriptionBlockerRecoveryResult.unavailable;
      } on Object {
        return StoreSubscriptionBlockerRecoveryResult.unavailable;
      }
    }
  }
}
