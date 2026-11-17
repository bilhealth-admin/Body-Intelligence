import 'dart:async';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _StorefrontSdk extends Fake implements InAppPurchase {
  String country = 'JOR';
  int countryReads = 0, queries = 0, buys = 0;
  Future<ProductDetailsResponse> Function()? query;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String> countryCode() async {
    countryReads++;
    return country;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) {
    queries++;
    return query?.call() ?? Future.value(_all());
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buys++;
    return false;
  }
}

ProductDetailsResponse _all() => ProductDetailsResponse(
  productDetails: [
    for (final id in StoreCatalogConfiguration.productIds)
      ProductDetails(
        id: id,
        title: id,
        description: 'Synthetic provider availability',
        price: 'USD 9.99',
        rawPrice: 9.99,
        currencyCode: 'USD',
      ),
  ],
  notFoundIDs: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _StorefrontSdk sdk;
  late StreamController<String?> owners;
  late ProviderContainer scope;
  late ProviderSubscription<AsyncValue<CommercePlan?>> listener;
  late List<CommercePlan?> published;
  var disposed = false;

  setUp(() {
    sdk = _StorefrontSdk();
    owners = StreamController<String?>.broadcast(sync: true);
    published = [];
    disposed = false;
    scope = ProviderContainer(
      overrides: [
        // Only I/O/config are substituted; target policy/provider is real.
        storefrontPurchaseClientProvider.overrideWithValue(sdk),
        storefrontCatalogConfiguredProvider.overrideWithValue(true),
        verifiedEntitlementOwnerSeedProvider.overrideWithValue('owner-a'),
        verifiedEntitlementOwnerProvider.overrideWith((ref) => owners.stream),
      ],
    );
    listener = scope.listen(storefrontTargetPlanProvider, (_, next) {
      if (next.hasValue && !next.isLoading) published.add(next.value);
    }, fireImmediately: true);
  });
  tearDown(() async {
    if (!disposed) {
      listener.close();
      scope.dispose();
    }
    await owners.close();
  });

  test(
    'real provider reads storefront both sides of same-country query',
    () async {
      expect(
        await scope.read(storefrontTargetPlanProvider.future),
        CommercePlan.premiumAiCoach,
      );
      expect(sdk.countryReads, 2);
      expect(sdk.queries, 1);
      expect(published, [CommercePlan.premiumAiCoach]);
      await scope.pump();
      expect(sdk.countryReads, 2);
      expect(sdk.queries, 1);
      expect(sdk.buys, 0);
    },
  );

  test(
    'country changed during query publishes no stale target until explicit refresh',
    () async {
      final held = Completer<ProductDetailsResponse>();
      sdk.query = () => held.future;
      final pending = scope.read(storefrontTargetPlanProvider.future);
      await scope.pump();
      expect(sdk.countryReads, 1);
      sdk.country = 'EGY';
      held.complete(_all());
      expect(await pending, isNull);
      expect(published, [null]);
      expect(sdk.countryReads, 2);
      expect(sdk.queries, 1);
      await scope.pump();
      expect(sdk.queries, 1, reason: 'No polling/retry loop.');
      sdk.query = null;
      scope.invalidate(storefrontTargetPlanProvider);
      expect(
        await scope.read(storefrontTargetPlanProvider.future),
        CommercePlan.premium,
      );
      expect(sdk.countryReads, 4);
      expect(sdk.queries, 2);
      expect(sdk.buys, 0);
    },
  );

  Future<void> deliverOwner(String owner) async {
    final delivered = Completer<void>();
    final witness = scope.listen(verifiedEntitlementOwnerProvider, (_, next) {
      if (next.hasValue &&
          !next.isLoading &&
          next.value == owner &&
          !delivered.isCompleted) {
        delivered.complete();
      }
    });
    // Ensure the broadcast StreamProvider has actually subscribed before emit.
    await scope.pump();
    owners.add(owner);
    await delivered.future.timeout(const Duration(seconds: 5));
    witness.close();
    await scope.pump();
    expect(scope.read(verifiedEntitlementOwnerProvider).requireValue, owner);
  }

  test(
    'real A B A provider visit retires the old query and latest alone publishes',
    () async {
      final old = Completer<ProductDetailsResponse>();
      final retiredB = Completer<ProductDetailsResponse>();
      final current = Completer<ProductDetailsResponse>();
      final producers = [old, retiredB, current];
      final entered = List.generate(3, (_) => Completer<void>());
      sdk.query = () {
        final index = sdk.queries - 1;
        entered[index].complete();
        return producers[index].future;
      };
      await deliverOwner('owner-a');
      expect(scope.read(verifiedEntitlementOwnerIdProvider), 'owner-a');
      expect(scope.read(verifiedEntitlementOwnerVisitProvider), 0);
      final pending = scope.read(storefrontTargetPlanProvider.future);
      // The future can be cancelled/forwarded by Riverpod during dependency refresh.
      // Capture completion so retirement cannot become an unhandled test error.
      final settled = pending.then<CommercePlan?>(
        (v) => v,
        onError: (Object _) => null,
      );
      await entered[0].future.timeout(const Duration(seconds: 5));
      await scope.pump();
      await deliverOwner('owner-b');
      expect(scope.read(verifiedEntitlementOwnerIdProvider), 'owner-b');
      expect(
        scope.read(verifiedEntitlementOwnerVisitProvider),
        1,
        reason: 'The raw B event must retire the first A visit.',
      );
      // Observe the real B consumer future. Reading flushes lazy dependencies;
      // do not await this deliberately held native producer.
      unawaited(
        scope
            .read(storefrontTargetPlanProvider.future)
            .then<void>((_) {}, onError: (Object _) {}),
      );
      await entered[1].future.timeout(const Duration(seconds: 5));
      await scope.pump();
      expect(sdk.queries, 2);
      await deliverOwner('owner-a');
      expect(scope.read(verifiedEntitlementOwnerIdProvider), 'owner-a');
      expect(
        scope.read(verifiedEntitlementOwnerVisitProvider),
        2,
        reason: 'A returns as a new visit, not the retired original A.',
      );
      unawaited(
        scope
            .read(storefrontTargetPlanProvider.future)
            .then<void>((_) {}, onError: (Object _) {}),
      );
      await entered[2].future.timeout(const Duration(seconds: 5));
      await scope.pump();
      final before = sdk.queries;
      expect(
        before,
        3,
        reason: 'Each delivered owner visit has one current producer.',
      );
      old.complete(_all());
      await scope.pump();
      expect(published, isEmpty);
      retiredB.complete(_all());
      await scope.pump();
      expect(published, isEmpty);
      expect(sdk.queries, 3);
      current.complete(_all());
      await settled;
      expect(
        await scope.read(storefrontTargetPlanProvider.future),
        CommercePlan.premiumAiCoach,
      );
      expect(published, [CommercePlan.premiumAiCoach]);
      expect(sdk.queries, 3);
      await scope.pump();
      expect(sdk.queries, 3);
      expect(sdk.buys, 0);
    },
  );

  test('dispose during query does not publish or reread storefront', () async {
    final held = Completer<ProductDetailsResponse>();
    sdk.query = () => held.future;
    unawaited(
      scope
          .read(storefrontTargetPlanProvider.future)
          .then<void>((_) {}, onError: (Object _) {}),
    );
    await scope.pump();
    expect(sdk.countryReads, 1);
    scope.dispose();
    disposed = true;
    held.complete(_all());
    await held.future;
    await Future<void>.value();
    expect(published, isEmpty);
    expect(sdk.countryReads, 1);
    expect(sdk.queries, 1);
    expect(sdk.buys, 0);
  });

  test(
    'reattached consumer refreshes the changed storefront exactly once',
    () async {
      expect(
        await scope.read(storefrontTargetPlanProvider.future),
        CommercePlan.premiumAiCoach,
      );
      expect(sdk.countryReads, 2);
      expect(sdk.queries, 1);
      listener.close();
      await scope.pump();
      sdk.country = 'EGY';
      listener = scope.listen(storefrontTargetPlanProvider, (_, next) {
        if (next.hasValue && !next.isLoading) published.add(next.value);
      });
      await scope.pump();
      expect(
        await scope.read(storefrontTargetPlanProvider.future),
        CommercePlan.premium,
      );
      expect(published, [CommercePlan.premiumAiCoach, CommercePlan.premium]);
      expect(sdk.countryReads, 4);
      expect(sdk.queries, 2);
      await scope.pump();
      expect(sdk.countryReads, 4);
      expect(sdk.queries, 2);
      expect(sdk.buys, 0);
    },
  );
}
