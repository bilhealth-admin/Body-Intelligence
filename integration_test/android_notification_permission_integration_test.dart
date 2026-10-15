import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _marker = 'BIL LOCAL NOTIFICATIONS SDK QA ONLY';
const _channel = 'bil_native_notification_permission_qa_v1';
const _expected = String.fromEnvironment(
  'BIL_QA_NOTIFICATION_PERMISSION_EXPECTED',
);
const _head = String.fromEnvironment('BIL_QA_SOURCE_HEAD');
const _fingerprint = String.fromEnvironment('BIL_QA_SOURCE_FINGERPRINT');

class _DenyQaHttp extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Notification SDK QA forbids Dart HTTP');
  }
}

// Read-only platform facts, without a new dependency or native application edit.
Future<String> _getprop(String property) async {
  final process = await Process.start('/system/bin/getprop', [property]);
  try {
    final result = await Future.wait<Object>([
      process.exitCode,
      process.stdout.transform(utf8.decoder).join(),
      process.stderr.drain<void>().then((_) => true),
    ]).timeout(const Duration(seconds: 5));
    if (result[0] != 0) throw StateError('Android QA getprop failed');
    return (result[1] as String).trim();
  } finally {
    process.kill();
  }
}

Future<List<ActiveNotification>> _ownedNotifications(
  FlutterLocalNotificationsPlugin plugin,
  int id,
) async => (await plugin.getActiveNotifications())
    .where((item) => item.id == id)
    .toList(growable: false);

Future<List<ActiveNotification>> _awaitOwnedState(
  FlutterLocalNotificationsPlugin plugin,
  int id, {
  required bool present,
}) async {
  final clock = Stopwatch()..start();
  do {
    final active = await _ownedNotifications(plugin, id);
    if (active.isNotEmpty == present) return active;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  } while (clock.elapsed < const Duration(seconds: 3));
  throw StateError('QA notification presence did not become $present');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final tagged in [false, true]) {
    final variant = tagged ? 'tagged' : 'plain';
    testWidgets('Android local SDK permission $_expected $variant', (
      tester,
    ) async {
      final metadata = <String, Object?>{
        'classification': 'native local-notification SDK runtime QA only',
        'not_production_notification_e2e': true,
        'marker': _marker,
        'sdk_build_input': 'flutter_local_notifications 22.2.0',
        'expected_permission': _expected,
        'variant': variant,
        'source_head': _head,
        'source_fingerprint': _fingerprint,
        'started_utc': DateTime.now().toUtc().toIso8601String(),
        'status': 'RUNNING',
      };
      binding.reportData ??= <String, dynamic>{};
      (binding.reportData!['android_notification_permission'] ??= <dynamic>[])
          .add(metadata);
      final denyHttp = _DenyQaHttp();
      final previousHttp = HttpOverrides.current;
      final plugin = FlutterLocalNotificationsPlugin();
      final id = 0x42490000 + DateTime.now().microsecondsSinceEpoch % 0xffff;
      final tag = tagged ? 'bil-native-sdk-qa-$id' : null;
      Directory? output;
      var ownsId = false;
      try {
        // Fail before initialization/show on an unsupported or non-QA target.
        expect(Platform.isAndroid && kDebugMode, isTrue);
        expect(const bool.fromEnvironment('BIL_QA_ANDROID_EMULATOR'), isTrue);
        expect(const String.fromEnvironment('BIL_ENVIRONMENT'), 'testing');
        expect(
          const bool.fromEnvironment('BIL_USE_SUPABASE', defaultValue: true) ||
              const bool.fromEnvironment('BIL_PAYMENTS_ENABLED') ||
              const bool.fromEnvironment('BIL_PUSH_ENABLED') ||
              const bool.fromEnvironment('BIL_ADS_ENABLED'),
          isFalse,
        );
        expect(['denied', 'granted'], contains(_expected));
        expect(_head.isNotEmpty && _fingerprint.isNotEmpty, isTrue);
        HttpOverrides.global = denyHttp;
        final api = int.tryParse(await _getprop('ro.build.version.sdk'));
        expect(api, isNotNull);
        expect(api, greaterThanOrEqualTo(33));
        final kernelQemu = await _getprop('ro.kernel.qemu');
        final qemu = kernelQemu != '1'
            ? await _getprop('ro.boot.qemu')
            : kernelQemu;
        expect(qemu, '1', reason: 'Only a disposable QA emulator is allowed.');
        metadata['android_api'] = api;
        metadata['native_emulator_property'] = qemu;
        final directory = await getExternalStorageDirectory();
        expect(directory, isNotNull);
        output = Directory('${directory!.path}/notification-permission-native');
        await output.create(recursive: true);
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Center(child: Text(_marker))),
          ),
        );
        expect(find.text(_marker), findsOneWidget);
        final initialized = await plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_bil_notification'),
          ),
        );
        expect(initialized, isTrue);
        metadata['initialized'] = initialized;
        final android = plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        expect(android, isNotNull);
        final enabled = await android!.areNotificationsEnabled();
        metadata['permission_before_show'] = enabled;
        expect(enabled, _expected == 'granted');
        // Never replace/cancel any preexisting notification or clear app state.
        expect(await _ownedNotifications(plugin, id), isEmpty);
        ownsId = true;
        final title = '$_marker / $_expected / $variant';
        metadata['notification_id'] = id;
        metadata['notification_tag'] = tag;
        await plugin.show(
          id: id,
          title: title,
          body: 'Synthetic SDK permission proof. No account or cloud data.',
          payload: 'BIL_NATIVE_NOTIFICATION_PERMISSION_QA_ONLY',
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel,
              _marker,
              channelDescription: 'Isolated local SDK test notifications only',
              tag: tag,
              silent: true,
              playSound: false,
              enableVibration: false,
              showWhen: false,
            ),
          ),
        );
        metadata['show_completed_without_exception'] = true;
        final active = await _awaitOwnedState(
          plugin,
          id,
          present: _expected == 'granted',
        );
        metadata['matching_active_count'] = active.length;
        if (_expected == 'granted') {
          expect(active, hasLength(1));
          expect(active.single.title, title);
          expect(active.single.channelId, _channel);
          expect(active.single.id, id);
          expect(active.single.tag, tag);
          metadata['matching_active_title'] = active.single.title;
          metadata['matching_active_channel'] = active.single.channelId;
        } else {
          expect(active, isEmpty);
        }
        final after = await android.areNotificationsEnabled();
        metadata['permission_after_show'] = after;
        expect(
          after,
          enabled,
          reason: 'The fixture must never request permission.',
        );
        expect(denyHttp.attempts, 0);
        metadata['status'] = 'PASS';
      } catch (error) {
        metadata['status'] = 'FAIL';
        metadata['error'] = error.toString();
        rethrow;
      } finally {
        Object? cleanupError;
        try {
          if (ownsId) {
            await plugin.cancel(id: id, tag: tag);
            // A wrong native tag must fail the case and still leave no QA row.
            for (final item in await _ownedNotifications(plugin, id)) {
              await plugin.cancel(id: id, tag: item.tag);
            }
            final remaining = await _awaitOwnedState(
              plugin,
              id,
              present: false,
            );
            expect(remaining, isEmpty);
            metadata['owned_notification_cleanup'] = 'PASS';
          }
        } catch (error) {
          cleanupError = error;
          metadata['owned_notification_cleanup'] = 'FAIL';
          metadata['cleanup_error'] = error.toString();
          metadata['status'] = 'FAIL';
        }
        metadata['dart_http_attempts'] = denyHttp.attempts;
        metadata['ended_utc'] = DateTime.now().toUtc().toIso8601String();
        HttpOverrides.global = previousHttp;
        if (output != null) {
          await File('${output.path}/$_expected-$variant.json').writeAsString(
            const JsonEncoder.withIndent('  ').convert(metadata),
            flush: true,
          );
        }
        // Synthetic metadata only; no screenshots or unrelated notifications.
        debugPrint('BIL_NOTIFICATION_SDK_QA ${jsonEncode(metadata)}');
        if (cleanupError != null) {
          throw StateError(
            'Owned QA notification cleanup failed: $cleanupError',
          );
        }
      }
    });
  }
}
