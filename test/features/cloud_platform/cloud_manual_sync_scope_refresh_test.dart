import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_nutrition_snapshot_codec.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_consent_local_store.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_consent_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _device = '22222222-2222-4222-8222-222222222222';

/// Real SDK, manual service, journal, SQLite restoration and status persistence.
/// HTTP and the OS crypto channel are deterministic models here; real SQL/RLS
/// and native authenticated encryption have separate integration gates.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in ['normal', 'refresh', 'revoked']) {
    test(
      'manual sync $mode handles a privacy status read during restoration',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final directory = await Directory.systemTemp.createTemp(
          'bil-sync-scope-test-',
        );
        addTearDown(() async {
          if (directory.absolute.parent.path !=
                  Directory.systemTemp.absolute.path ||
              !directory.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('bil-sync-scope-test-')) {
            throw StateError('Refusing cleanup outside the test directory');
          }
          await directory.delete(recursive: true);
        });
        final key = Uint8List(32);
        final keyId = sha256.convert(key).toString();
        final secrets = <String, String>{
          'bil.cloud.payload-key.v1.$_owner': base64.encode(key),
          'bil.cloud.device-id.v1': _device,
          'bil.cloud.device-registered-at.v1': '2026-10-01T00:00:00Z',
        };
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const storage = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
        const connectivity = MethodChannel(
          'dev.fluttercommunity.plus/connectivity',
        );
        const crypto = MethodChannel('bil/system_crypto');
        for (final channel in [storage, pathProvider, connectivity, crypto]) {
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        }
        messenger.setMockMethodCallHandler(storage, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          switch (call.method) {
            case 'read':
              return secrets[args['key']];
            case 'write':
              secrets[args['key'] as String] = args['value'] as String;
              return null;
            case 'delete':
              secrets.remove(args['key']);
              return null;
            default:
              throw StateError('Unexpected secret operation ${call.method}');
          }
        });
        messenger.setMockMethodCallHandler(
          pathProvider,
          (_) async => directory.path,
        );
        messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
        messenger.setMockMethodCallHandler(crypto, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          if (call.method == 'encryptAes256Gcm') {
            return {
              'nonce': Uint8List(12),
              'protected': Uint8List.fromList([
                ...(args['plaintext'] as Uint8List),
                ...List.filled(16, 0),
              ]),
            };
          }
          if (call.method == 'decryptAes256Gcm') {
            final bytes = args['protected'] as Uint8List;
            return Uint8List.fromList(bytes.sublist(0, bytes.length - 16));
          }
          throw StateError('Unexpected crypto operation');
        });
        Map<String, Object?> seal(Map<String, Object?> clear) => {
          '_bil_cipher_v': 1,
          'alg': 'A256GCM',
          'nonce': base64Url.encode(Uint8List(12)),
          'ciphertext': base64Url.encode([
            ...utf8.encode(jsonEncode(clear)),
            ...List.filled(16, 0),
          ]),
        };

        final source = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: _owner,
        );
        final List<CloudNutritionSnapshot> snapshots;
        try {
          await LocalDataAccountBoundary(source).bindAuthenticatedOwner(_owner);
          await MealRepository(source).addQuickMacroEntry(
            date: DateTime(2026, 10, 20, 12),
            mealType: 'snack',
            calories: 600,
            protein: 0,
            carbohydrates: 0,
            fat: 0,
            caloriesKnown: true,
            proteinKnown: false,
            carbohydratesKnown: false,
            fatKnown: false,
            occurredAt: DateTime(2026, 10, 20, 12),
          );
          snapshots = await CloudNutritionSnapshotCodec(
            source,
            ownerId: _owner,
            ownerIsCurrent: () => true,
          ).capture(scopes: {'nutrition'});
        } finally {
          await source.close();
        }
        final records = snapshots.map((snapshot) {
          final clear = <String, Object?>{
            'owner_id': _owner,
            'scope': snapshot.scope,
            'record_type': snapshot.type,
            'record_id': snapshot.id,
            'deleted': false,
            'payload_version': 2,
            'key_id': keyId,
            'snapshot': snapshot.toJson(),
          };
          return <String, Object?>{
              ...clear,
              'server_revision': 1,
              'payload': {...seal(clear), 'key_id': keyId},
            }
            ..remove('snapshot')
            ..remove('key_id');
        }).toList();
        var granted = true;
        var capabilityReads = 0;
        var exchanges = 0;
        CloudRestoreConsentRepository? consentRepository;
        final user = {
          'id': _owner,
          'email': 'sync-fixture@example.invalid',
          'aud': 'authenticated',
          'created_at': '2026-10-01T00:00:00Z',
          'app_metadata': <String, Object?>{},
          'user_metadata': <String, Object?>{},
        };
        SharedPreferences.setMockInitialValues({});
        final sdk = await Supabase.initialize(
          url: 'https://manual-sync.invalid',
          publishableKey: 'synthetic-fixture',
          debug: false,
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage(),
          ),
          httpClient: MockClient((request) async {
            http.Response response(Object? body) => http.Response.bytes(
              utf8.encode(jsonEncode(body)),
              200,
              request: request,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
            switch (request.url.path) {
              case '/auth/v1/user':
                return response(user);
              case '/rest/v1/bil_ai_closed_test_grants':
              case '/rest/v1/bil_subscriptions':
                return response([]);
              case '/rest/v1/rpc/bil_get_my_admin_subscription':
                return response(null);
              case '/rest/v1/bil_consent_receipts':
                return response([
                  {
                    'granted': true,
                    'recorded_at': '2026-10-01T00:00:00Z',
                    'policy_version': '1',
                  },
                ]);
              case '/rest/v1/rpc/bil_cloud_restore_capabilities_v2':
                capabilityReads++;
                if (mode != 'normal' && capabilityReads == 2) {
                  if (mode == 'revoked') granted = false;
                  // A settings read has its own visit, independent of the HTTP
                  // continuation of the synchronization it overlaps.
                  await Zone.root.run(() => consentRepository!.read());
                }
                return response({
                  'protocol_version': 2,
                  'consent_policy_version': '1',
                  'scopes': ['nutrition', 'goals'],
                });
              case '/rest/v1/rpc/bil_cloud_restore_consent_v2':
                return response({
                  'nutrition': {
                    'granted': granted,
                    'policy_version': '1',
                    'recorded_at': granted
                        ? '2026-10-01T00:00:00Z'
                        : '2026-10-21T00:00:00Z',
                  },
                  'goals': {'granted': false, 'policy_version': '1'},
                });
              case '/rest/v1/rpc/bil_sync_records':
                final body = jsonDecode(request.body) as Map;
                return response({
                  'acknowledged': (body['p_operations'] as List)
                      .map((o) => o['operation_id'])
                      .toList(),
                  'records': [],
                  'cursor': 0,
                  'has_more': false,
                });
              case '/rest/v1/rpc/bil_sync_records_v2':
                exchanges++;
                expect(
                  granted,
                  isTrue,
                  reason: 'No nutrition exchange after the observed denial.',
                );
                final body = jsonDecode(request.body) as Map;
                final cursor = body['p_cursor'] as int;
                final page = records
                    .skip(cursor)
                    .take(body['p_limit'] as int)
                    .toList();
                expect(body['p_operations'], isEmpty);
                return response({
                  'protocol_version': 2,
                  'scope': 'nutrition',
                  'cursor': cursor + page.length,
                  'has_more': cursor + page.length < records.length,
                  'receipts': [],
                  'records': page,
                });
              default:
                throw StateError(
                  'Unexpected external request: ${request.url.path}',
                );
            }
          }),
        );
        addTearDown(sdk.dispose);
        final token = base64Url
            .encode(utf8.encode(jsonEncode({'sub': _owner, 'exp': 4102444800})))
            .replaceAll('=', '');
        await sdk.client.auth.recoverSession(
          jsonEncode({
            'access_token': 'eyJhbGciOiJIUzI1NiJ9.$token.test',
            'refresh_token': 'synthetic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': user,
          }),
        );
        final destination = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: _owner,
        );
        addTearDown(destination.close);
        final boundary = LocalDataAccountBoundary(destination);
        await boundary.bindAuthenticatedOwner(_owner);
        consentRepository = CloudRestoreConsentRepository(
          client: sdk.client,
          localStore: AppDatabaseCloudRestoreConsentLocalStore(destination),
        );
        addTearDown(consentRepository.dispose);
        final service = CloudManualSyncService(
          client: sdk.client,
          database: destination,
          accountBoundary: boundary,
          restoreConsent: consentRepository,
        );
        final status = CloudManualSyncStatusController(
          preferences: PreferencesRepository(destination),
          runSync: service.runOnce,
          cloudAvailable: true,
          ownerId: _owner,
        );
        addTearDown(status.dispose);
        final result = await status.runOnce();
        if (mode == 'revoked') {
          expect(result.completed, isFalse);
          expect(exchanges, 0);
          expect(
            await destination.select(destination.mealItems).get(),
            isEmpty,
          );
          expect(status.state.lastSuccessfulSyncAt, isNull);
        } else {
          expect(result.completed, isTrue, reason: result.reason);
          expect(
            await destination.select(destination.mealItems).get(),
            hasLength(1),
          );
          expect(status.state.lastSuccessfulSyncAt, isNotNull);
          final repeated = await status.runOnce();
          expect(repeated.completed, isTrue, reason: repeated.reason);
          expect(
            await destination.select(destination.mealItems).get(),
            hasLength(1),
          );
          final diary = await MealRepository(
            destination,
          ).watchMealsForDate(DateTime(2026, 10, 20)).first;
          expect(diary.single.items.single.calories, 600);
          expect(diary.single.items.single.nutrientEvidenceMask, 128);
        }
      },
    );
  }
}
