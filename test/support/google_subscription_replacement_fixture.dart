import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Explicit positive fixture for tests of other financial boundaries.
/// It still runs the real replacement policy on two successful empty sources.
GoogleSubscriptionReplacementReader emptyGoogleSubscriptionProofFixture() =>
    GoogleSubscriptionReplacementReader(
      inventoryReader: (_) async =>
          QueryPurchaseDetailsResponse(pastPurchases: const []),
      canonicalReader: (_) async => const <Map<String, dynamic>>[],
    );
