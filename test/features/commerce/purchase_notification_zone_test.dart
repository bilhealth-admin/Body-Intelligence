import 'dart:async';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
import 'package:body_intelligence_log/features/community/services/community_owner_operation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _NoNativeRequests extends Fake implements InAppPurchase {}

bool operationStillCurrent() {
  try {
    CommunityOwnerOperation.checkCurrent();
    return true;
  } on CommunityOwnerOperationCancelled {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://notification-lifetime.invalid',
      publishableKey: 'synthetic-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient(
        (_) async => throw StateError(
          'This lifetime test must never send a network request',
        ),
      ),
    );
  });
  tearDown(() => Supabase.instance.dispose());
  final factories = <String, ChangeNotifier Function()>{
    'subscription': () =>
        VerifiedStorePurchaseService(purchase: _NoNativeRequests()),
    'Boost': () => AiBoostPurchaseService(
      purchase: _NoNativeRequests(),
      owner: () => null,
      ownerChanges: const Stream.empty(),
    ),
  };
  for (final entry in factories.entries) {
    test(
      '${entry.key} UI continuation survives a completed HTTP guard, guard work stays fenced',
      () async {
        final notifier = entry.value();
        addTearDown(notifier.dispose);
        final observed = Completer<bool>();
        late Future<bool> guardedContinuation;
        notifier.addListener(() {
          Future<void>.delayed(Duration.zero).then((_) {
            if (!observed.isCompleted) {
              observed.complete(operationStillCurrent());
            }
          });
        });
        await CommunityOwnerOperation.run<void>(
          client: Supabase.instance.client,
          ownerId: null,
          readOwner: () => null,
          action: (_) async {
            guardedContinuation = Future<void>.delayed(
              Duration.zero,
            ).then((_) => operationStillCurrent());
            notifier.notifyListeners();
          },
        );
        expect(
          await guardedContinuation,
          isFalse,
          reason:
              'Finishing the authenticated operation still cancels its own continuations.',
        );
        expect(
          await observed.future.timeout(const Duration(seconds: 2)),
          isTrue,
          reason:
              'Unrelated UI work must inherit the durable notifier zone, not a retired HTTP fence.',
        );
      },
    );
  }
}
