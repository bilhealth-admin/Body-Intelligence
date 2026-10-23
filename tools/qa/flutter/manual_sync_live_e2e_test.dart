import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_nutrition_snapshot_codec.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../test/features/cloud_platform/support/cloud_nutrition_fixture.dart';

/// Explicit live gate, outside automatic test/ discovery. Real signed Auth,
/// deployed RPCs, canonical Vault key, file SQLite and authenticated AES-GCM.
/// OS path/connectivity/secure-store channels are local models, not an iPhone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'manual button sync persists restores resumes and reports real success',
    () async {
      final configPath = Platform.environment['BIL_MANUAL_SYNC_CONFIG'];
      if (configPath == null) {
        throw StateError('Use the disposable live runner');
      }
      final configFile = File(configPath).absolute;
      final config = jsonDecode(await configFile.readAsString()) as Map;
      if (config['url'] != 'https://tgmanzhqulksykhslrzb.supabase.co' ||
          config['project'] != 'tgmanzhqulksykhslrzb') {
        throw StateError('Unexpected fixture project');
      }
      final users = (config['users'] as List).cast<Map>();
      for (final user in users) {
        if (!RegExp(
          r'^bil-manual-sync-[a-f0-9]{32}-[ab]@bilhealth\.invalid$',
        ).hasMatch(user['email'] as String)) {
          throw StateError('Disposable identities required');
        }
      }
      final root = configFile.parent;
      final owner = users.first['id'] as String;
      final evidence = <String, Object?>{
        'status': 'FAIL',
        'boundaries': {
          'auth': 'real signed server-validated session',
          'transport': 'actual deployed Supabase HTTPS RPCs',
          'storage': 'real independent SQLite files',
          'key_custody': 'actual authenticated canonical Vault RPC',
          'crypto': 'real local Node AES-256-GCM through modeled OS channel',
          'not_proved': [
            'physical iPhone',
            'CryptoKit or Keychain on this run',
            'this real user account or its historical ciphertext',
          ],
        },
        'stages': <Object?>[],
      };
      final stages = evidence['stages'] as List;
      final network = HttpOverrides.runWithHttpOverrides(
        _LiveNetwork.new,
        _RealNetwork(),
      );
      final crypto = await _CryptoBridge.start();
      final devices = <_LogicalDevice>[];
      _LogicalDevice? selected;
      var online = true;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const storageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      const connectivityChannel = MethodChannel(
        'dev.fluttercommunity.plus/connectivity',
      );
      const cryptoChannel = MethodChannel('bil/system_crypto');
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      messenger.setMockMethodCallHandler(storageChannel, (call) async {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final values = selected!.secrets;
        final key = args['key'] as String;
        switch (call.method) {
          case 'read':
            return values[key];
          case 'write':
            values[key] = args['value'] as String;
            return null;
          case 'delete':
            values.remove(key);
            return null;
          default:
            throw StateError('Unexpected secure-store method');
        }
      });
      messenger.setMockMethodCallHandler(
        pathChannel,
        (_) async => selected!.directory.path,
      );
      messenger.setMockMethodCallHandler(
        connectivityChannel,
        (_) async => [online ? 'wifi' : 'none'],
      );
      messenger.setMockMethodCallHandler(cryptoChannel, crypto.call);
      // This explicit QA fixture is outside automatic test/ discovery.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      final sdk = await Supabase.initialize(
        url: config['url'] as String,
        publishableKey: config['public_key'] as String,
        debug: false,
        httpClient: network,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage(),
        ),
      );
      final client = sdk.client;
      Future<_LogicalDevice> device(String label) async {
        final folder = Directory('${root.path}/$label');
        await folder.create();
        final value = _LogicalDevice(folder, owner);
        devices.add(value);
        selected = value;
        await LocalDataAccountBoundary(
          value.database,
        ).bindAuthenticatedOwner(owner);
        return value;
      }

      Future<CloudManualSyncResult> run(
        String label,
        _LogicalDevice value,
      ) async {
        selected = value;
        final oldCount = network.exchanges.length;
        final service = CloudManualSyncService(
          client: client,
          database: value.database,
          accountBoundary: LocalDataAccountBoundary(value.database),
        );
        final status = CloudManualSyncStatusController(
          preferences: PreferencesRepository(value.database),
          runSync: service.runOnce,
          cloudAvailable: true,
          ownerId: owner,
        );
        CloudManualSyncStatus? visibleStatus;
        final removeListener = status.addListener(
          (value) => visibleStatus = value,
        );
        try {
          final result = await status.runOnce().timeout(
            const Duration(minutes: 4),
          );
          final row = <String, Object?>{
            'stage': label,
            'disposition': result.disposition.name,
            'reason': result.reason,
            'completed': result.completed,
            'enqueued': result.enqueued,
            'pushed': result.pushed,
            'pulled': result.pulled,
            'applied': result.applied,
            'pending': result.pending,
            'conflicts': result.conflicts,
            'last_success': visibleStatus?.lastSuccessfulSyncAt
                ?.toIso8601String(),
            'exchanges': network.exchanges.sublist(oldCount),
            'ledger': value.ledger(),
          };
          stages.add(row);
          debugPrint(
            'LIVE_SYNC_STAGE=$label completed=${result.completed} reason=${result.reason} pending=${result.pending}',
          );
          return result;
        } finally {
          removeListener();
          status.dispose();
        }
      }

      try {
        selected = await device('device-a');
        await client.auth.signInWithPassword(
          email: users.first['email'] as String,
          password: users.first['password'] as String,
        );
        expect((await client.auth.getUser()).user?.id, owner);
        await client.rpc(
          'bil_record_consent',
          params: {
            'p_purpose': 'cloud_sync',
            'p_policy_version': '1',
            'p_granted': true,
          },
        );
        for (final scope in ['nutrition', 'goals']) {
          await client.rpc(
            'bil_record_cloud_restore_consent_v2',
            params: {
              'p_scope': scope,
              'p_policy_version': '1',
              'p_granted': true,
            },
          );
        }
        final a = selected!;
        final db = a.database;
        final oldSuccess = DateTime.utc(2026, 10, 13, 18);
        await PreferencesRepository(db).set(
          cloudLastSuccessfulSyncPreferenceKeyFor(owner),
          oldSuccess.toIso8601String(),
        );
        await db
            .into(db.userProfile)
            .insert(
              UserProfileCompanion.insert(
                gender: 'male',
                age: 30,
                height: 175,
                currentWeight: 80,
                targetWeight: 75,
                activityLevel: 'moderate',
                exercises: true,
              ),
            );
        await db
            .into(db.weightEntries)
            .insert(
              WeightEntriesCompanion.insert(
                weight: 80,
                date: Value(DateTime(2026, 10, 20)),
                dayKey: const Value('2026-10-20'),
              ),
            );
        for (var index = 0; index < 201; index++) {
          await db
              .into(db.waterEntries)
              .insert(
                WaterEntriesCompanion.insert(
                  occurredAt: DateTime(
                    2026,
                    10,
                    20,
                  ).add(Duration(minutes: index)),
                  dayKey: '2026-10-20',
                  amountMl: 100 + index,
                ),
              );
        }
        await seedCloudNutritionFixture(db, ownerId: owner);
        final expected = await _snapshot(db);
        final uploaded = await run('a-upload-all-data', a);
        expect(
          uploaded.completed,
          isTrue,
          reason:
              'One button must complete eligible batches: ${uploaded.reason}',
        );
        expect((a.ledger()['outbox'] as int), 0);
        expect((a.ledger()['dead_letters'] as int), 0);
        final newSuccess = await PreferencesRepository(
          db,
        ).get(cloudLastSuccessfulSyncPreferenceKeyFor(owner));
        expect(DateTime.parse(newSuccess!).isAfter(oldSuccess), isTrue);

        final b = await device('device-b-empty');
        expect(await b.database.select(b.database.waterEntries).get(), isEmpty);
        final restored = await run('b-restore-empty-sqlite', b);
        expect(restored.completed, isTrue, reason: restored.reason);
        expect(await _snapshot(b.database), expected);
        expect(
          await PreferencesRepository(
            b.database,
          ).get(CloudNutritionSnapshotCodec.referencePreference),
          CloudNutritionSnapshotCodec.referenceVersion,
          reason:
              'Restoration must record the exact nutrition reference version',
        );
        expect(
          network.exchanges.where((e) => e['has_more'] == true),
          isNotEmpty,
          reason: 'The actual server must exercise paginated restoration',
        );
        final keySlot = 'bil.cloud.payload-key.v1.$owner';
        expect(b.secrets[keySlot], a.secrets[keySlot]);
        expect(b.secrets[keySlot], isNotNull);
        evidence['canonical_key_matches_across_devices'] = true;
        evidence['canonical_key_sha256'] = sha256
            .convert(base64Decode(a.secrets[keySlot]!))
            .toString();
        await b.reopen();
        expect(
          await _snapshot(b.database),
          expected,
          reason: 'Data must survive closing and reopening SQLite',
        );
        final repeated = await run('b-idempotent-repeat-after-reopen', b);
        expect(repeated.completed, isTrue, reason: repeated.reason);
        expect(await _snapshot(b.database), expected);

        // Actual server commits a new record, then the local transport loses
        // its response. No SQL/data edits are used to manufacture a retry.
        selected = a;
        await db
            .into(db.waterEntries)
            .insert(
              WaterEntriesCompanion.insert(
                occurredAt: DateTime(2026, 10, 21, 12),
                dayKey: '2026-10-21',
                amountMl: 225,
              ),
            );
        network.loseNextCommit = true;
        final beforeLoss = await PreferencesRepository(
          db,
        ).get(cloudLastSuccessfulSyncPreferenceKeyFor(owner));
        final lost = await run('a-response-lost-after-real-commit', a);
        expect(network.loseNextCommit, isFalse);
        expect(lost.completed, isFalse);
        expect(a.ledger()['outbox'], 1);
        expect(a.ledger()['dead_letters'], 0);
        expect(
          await PreferencesRepository(
            db,
          ).get(cloudLastSuccessfulSyncPreferenceKeyFor(owner)),
          beforeLoss,
        );
        // Respect the actual durable retry backoff; never edit its timestamp.
        await Future<void>.delayed(const Duration(seconds: 4));
        final resumed = await run('a-resume-preserved-outbox', a);
        expect(resumed.completed, isTrue, reason: resumed.reason);
        expect(a.ledger()['outbox'], 0);
        final expectedAfterEdit = await _snapshot(db);
        expect(
          (await run('b-pull-after-commit-response-loss', b)).completed,
          isTrue,
        );
        expect(await _snapshot(b.database), expectedAfterEdit);

        final c = await device('device-c-corruption');
        network.tamperNextPull = true;
        final beforeTamper = network.v1Calls;
        final corrupt = await run('c-aes-authentication-failure', c);
        expect(network.tamperNextPull, isFalse);
        expect(corrupt.completed, isFalse);
        expect(corrupt.reason, 'cloud_sync_decrypt_failed');
        expect(
          network.v1Calls - beforeTamper,
          1,
          reason: 'A failed page must not repeat twenty times',
        );
        expect(
          await PreferencesRepository(
            c.database,
          ).get(cloudLastSuccessfulSyncPreferenceKeyFor(owner)),
          isNull,
        );
        expect(c.ledger()['dead_letters'], 0);
        expect((await run('c-retry-authentic-page', c)).completed, isTrue);
        expect(await _snapshot(c.database), expectedAfterEdit);

        final cursorBeforeOffline = a.ledger()['cursors'];
        final callsBeforeOffline = network.v1Calls;
        online = false;
        final offline = await run('a-offline-preserves-data', a);
        expect(offline.disposition, CloudManualSyncDisposition.offline);
        expect(network.v1Calls, callsBeforeOffline);
        expect(a.ledger()['cursors'], cursorBeforeOffline);
        expect(await _snapshot(db), expectedAfterEdit);
        online = true;
        await client.rpc(
          'bil_record_consent',
          params: {
            'p_purpose': 'cloud_sync',
            'p_policy_version': '1',
            'p_granted': false,
          },
        );
        final callsBeforeDenial = network.v1Calls;
        final denied = await run('a-real-consent-denial', a);
        expect(denied.disposition, CloudManualSyncDisposition.consentMissing);
        expect(network.v1Calls, callsBeforeDenial);
        expect(await _snapshot(db), expectedAfterEdit);
        await client.rpc(
          'bil_record_consent',
          params: {
            'p_purpose': 'cloud_sync',
            'p_policy_version': '1',
            'p_granted': true,
          },
        );
        expect((await run('a-consent-regranted', a)).completed, isTrue);

        await client.auth.signOut();
        await client.auth.signInWithPassword(
          email: users[1]['email'] as String,
          password: users[1]['password'] as String,
        );
        expect((await client.auth.getUser()).user?.id, users[1]['id']);
        await client.rpc(
          'bil_record_consent',
          params: {
            'p_purpose': 'cloud_sync',
            'p_policy_version': '1',
            'p_granted': true,
          },
        );
        final isolated =
            await client.rpc(
                  'bil_sync_records',
                  params: {
                    'p_device_id': const Uuid().v4(),
                    'p_cursor': 0,
                    'p_operations': <Object?>[],
                  },
                )
                as Map;
        expect(isolated['records'], isEmpty);
        expect(
          (await run('b-account-cannot-use-a-local-store', a)).disposition,
          CloudManualSyncDisposition.localOwnerMismatch,
        );
        expect(await _snapshot(db), expectedAfterEdit);
        evidence['account_isolation'] = true;
        evidence['restored_counts'] = {
          'profile': 1,
          'weight': 1,
          'hydration': 202,
          'nutrition_and_goals': 'exact repository-authored snapshot equality',
        };
        evidence['status'] = 'PASS';
      } finally {
        evidence['real_crypto_encryptions'] = crypto.encryptions;
        evidence['real_crypto_decryptions'] = crypto.decryptions;
        await File(
          '${root.path}/service-proof.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
        await client.auth.signOut();
        await sdk.dispose();
        for (final value in devices) {
          await value.database.close();
        }
        for (final channel in [
          storageChannel,
          pathChannel,
          connectivityChannel,
          cryptoChannel,
        ]) {
          messenger.setMockMethodCallHandler(channel, null);
        }
        await crypto.close();
        network.close();
        debugDefaultTargetPlatformOverride = null;
      }
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

Future<Map<String, Object?>> _snapshot(AppDatabase db) async {
  Future<List<Map<String, Object?>>> rows(String table) async {
    final data = await db.customSelect('SELECT * FROM $table').get();
    final values = data
        .map(
          (row) => Map<String, Object?>.from(row.data)
            ..remove('id')
            ..remove('sync_status')
            ..remove('meal_id')
            ..remove('food_id'),
        )
        .toList();
    values.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    return values;
  }

  final preferences = await db
      .customSelect(
        // The restore-only schema witness is asserted separately above. It is
        // not a pre-existing user preference or a changed nutrition target.
        "SELECT key,value FROM preferences WHERE (key LIKE 'goal.%' OR key LIKE 'nutrition.%' OR key LIKE 'recipe.%') AND key != 'goal.cloudReferenceVersion.v1' ORDER BY key",
      )
      .get();
  return {
    for (final table in [
      'user_profile',
      'weight_entries',
      'water_entries',
      'foods',
      'meals',
      'meal_items',
    ])
      table: await rows(table),
    'preferences': preferences.map((r) => r.data).toList(),
    'meal_relationships':
        (await db
                .customSelect(
                  'SELECT i.uuid AS item_uuid,m.uuid AS meal_uuid,f.uuid AS food_uuid '
                  'FROM meal_items i JOIN meals m ON m.id=i.meal_id '
                  'JOIN foods f ON f.id=i.food_id ORDER BY i.uuid',
                )
                .get())
            .map((r) => r.data)
            .toList(),
  };
}

final class _LogicalDevice {
  _LogicalDevice(this.directory, this.owner) {
    database = _open();
  }
  final Directory directory;
  final String owner;
  final secrets = <String, String>{};
  late AppDatabase database;
  AppDatabase _open() => AppDatabase.forTesting(
    NativeDatabase(File('${directory.path}/health.sqlite')),
    localOwnerId: owner,
  );
  Future<void> reopen() async {
    await database.close();
    database = _open();
  }

  Map<String, Object?> ledger() {
    final file = File('${directory.path}/bil_cloud_ledger_v1.sqlite');
    if (!file.existsSync()) return {};
    final db = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
    try {
      return {
        'outbox': db
            .select('SELECT count(*) AS n FROM cloud_outbox')
            .single['n'],
        'dead_letters': db
            .select('SELECT count(*) AS n FROM cloud_dead_letters')
            .single['n'],
        'cursors': db
            .select('SELECT cursor FROM cloud_cursors ORDER BY device_id')
            .map((r) => r['cursor'])
            .toList(),
      };
    } finally {
      db.close();
    }
  }
}

final class _LiveNetwork extends http.BaseClient {
  final http.Client _inner = http.Client();
  final exchanges = <Map<String, Object?>>[];
  bool loseNextCommit = false, tamperNextPull = false;
  int v1Calls = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.scheme != 'https' ||
        request.url.host != 'tgmanzhqulksykhslrzb.supabase.co') {
      throw StateError('Live fixture only permits the configured project');
    }
    final v1 = request.url.path == '/rest/v1/rpc/bil_sync_records';
    final v2 = request.url.path == '/rest/v1/rpc/bil_sync_records_v2';
    final outgoing = (v1 || v2) && request is http.Request
        ? jsonDecode(request.body) as Map
        : null;
    if (v1) v1Calls++;
    if (outgoing != null) {
      for (final operation in outgoing['p_operations'] as List) {
        final envelope = v1
            ? operation['record']['payload']
            : operation['payload'];
        expect(envelope['_bil_cipher_v'], 1);
        expect(envelope['alg'], 'A256GCM');
        expect(envelope['ciphertext'], isA<String>());
        expect(envelope.containsKey('currentWeight'), isFalse);
      }
    }
    final response = await _inner.send(request);
    final bytes = await response.stream.toBytes();
    if (outgoing == null || response.statusCode != 200) {
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }
    final body = jsonDecode(utf8.decode(bytes)) as Map;
    exchanges.add({
      'protocol': v1 ? 1 : 2,
      'status': response.statusCode,
      'request_cursor': outgoing['p_cursor'],
      'response_cursor': body['cursor'],
      'operations': (outgoing['p_operations'] as List).length,
      'records': (body['records'] as List).length,
      'has_more': body['has_more'],
      'scope': outgoing['p_scope'],
    });
    if (v1 && loseNextCommit && (outgoing['p_operations'] as List).isNotEmpty) {
      loseNextCommit = false;
      throw const SocketException(
        'Synthetic response loss after real server commit',
      );
    }
    if (v1 && tamperNextPull && (body['records'] as List).isNotEmpty) {
      tamperNextPull = false;
      final payload = body['records'][0]['payload'] as Map;
      final encrypted = base64Url.decode(payload['ciphertext'] as String);
      encrypted[encrypted.length - 1] ^= 1;
      payload['ciphertext'] = base64Url.encode(encrypted);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() => _inner.close();
}

final class _RealNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionTimeout = const Duration(seconds: 20);
}

final class _CryptoBridge {
  _CryptoBridge(this.process) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final body = jsonDecode(line) as Map;
          _pending.remove(body['id'])!.complete(body);
        });
    // The helper deliberately produces no stderr or input diagnostics.
    process.stderr.drain<void>();
  }
  final Process process;
  final _pending = <int, Completer<Map>>{};
  int _next = 0, encryptions = 0, decryptions = 0;
  static Future<_CryptoBridge> start() async => _CryptoBridge(
    await Process.start('node', ['tools/qa/manual_sync_crypto_bridge.mjs']),
  );
  Future<Object?> call(MethodCall call) async {
    final args = Map<String, dynamic>.from(call.arguments as Map);
    final id = _next++;
    final ready = Completer<Map>();
    _pending[id] = ready;
    final request = <String, Object?>{'id': id, 'method': call.method};
    for (final entry in args.entries) {
      request[entry.key] = base64Encode(entry.value as Uint8List);
    }
    process.stdin.writeln(jsonEncode(request));
    final response = await ready.future.timeout(const Duration(seconds: 10));
    if (response['ok'] != true) {
      throw PlatformException(code: 'qa_aes_gcm_authentication_failed');
    }
    if (call.method == 'encryptAes256Gcm') {
      encryptions++;
      return {
        'nonce': base64Decode(response['nonce'] as String),
        'protected': base64Decode(response['protected'] as String),
      };
    }
    decryptions++;
    return base64Decode(response['plaintext'] as String);
  }

  Future<void> close() async {
    await process.stdin.close();
    await process.exitCode;
  }
}
