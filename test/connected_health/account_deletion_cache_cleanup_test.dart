import 'dart:io';

import 'package:body_intelligence_log/features/connected_health/services/connected_health_account_deletion_cleanup.dart';
import 'package:body_intelligence_log/features/global_platform/persistence/owner_scoped_health_store.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'account deletion cleanup initializes and clears only its local owner',
    () async {
      final host = GlobalNativeIntegrationHost.instance;
      await host.close();

      final appSupport = await Directory.systemTemp.createTemp(
        'bil-health-account-deletion-',
      );
      final appSupportPath = appSupport.absolute.path;
      final systemTempPath = Directory.systemTemp.absolute.path;
      expect(
        appSupportPath.startsWith(systemTempPath),
        isTrue,
        reason:
            'The test database must stay inside its disposable temp directory.',
      );

      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        pathProvider,
        (call) async => appSupport.path,
      );

      try {
        await clearConnectedHealthCacheForAccountDeletion(
          ownerId: 'account-a',
          readCurrentOwnerId: () => 'account-a',
        );
        final flows = host.productFlows;
        expect(
          flows,
          isNotNull,
          reason: 'A cold cleanup must initialize storage.',
        );

        final ownerA = OwnerScopedHealthStore(
          inner: flows!.store,
          ownerId: 'account-a',
          readCurrentOwnerId: () => 'account-a',
        );
        final ownerB = OwnerScopedHealthStore(
          inner: flows.store,
          ownerId: 'account-b',
          readCurrentOwnerId: () => 'account-b',
        );
        for (final bucket in OwnerScopedHealthStore.accountHealthDataBuckets) {
          await ownerA.put(bucket, 'row', {'value': 'A'});
          await ownerB.put(bucket, 'row', {'value': 'B'});
        }

        await clearConnectedHealthCacheForAccountDeletion(
          ownerId: 'account-a',
          readCurrentOwnerId: () => 'account-a',
        );
        for (final bucket in OwnerScopedHealthStore.accountHealthDataBuckets) {
          expect(await ownerA.get(bucket, 'row'), isNull, reason: bucket);
          expect(await ownerB.get(bucket, 'row'), {
            'value': 'B',
          }, reason: bucket);
        }
      } finally {
        await host.close();
        messenger.setMockMethodCallHandler(pathProvider, null);
        if (appSupport.absolute.path.startsWith(systemTempPath)) {
          await appSupport.delete(recursive: true);
        }
      }
    },
  );
}
