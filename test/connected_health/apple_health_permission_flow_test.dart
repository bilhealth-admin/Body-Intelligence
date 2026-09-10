import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/apple_health_permission_review.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/dashboard_health_activity_refresh.dart';
import 'package:body_intelligence_log/features/global_platform/health_data/unified_health_data_integration.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/platform/native_platform_bridges.dart';
import 'package:body_intelligence_log/features/global_platform/runtime/global_product_composition_root.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bil/apple_health');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('native permission decision flow', () {
    final host = GlobalNativeIntegrationHost.instance;
    late NativeConnectedHealthGateway gateway;
    late List<String> calls;
    late String status;
    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      calls = [];
      status = 'shouldRequest';
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'authorizationRequestStatus' => status,
          'requestPermissions' => {
            'requestCompleted': true,
            'readStatus': 'indeterminate',
          },
          'availability' => {'available': true},
          'permissions' => {'steps': true, 'weight': true},
          _ => null,
        };
      });
      await host.initialize(
        database: sqlite3.openInMemory(),
        configuration: const GlobalProductRuntimeConfiguration(
          localeCatalogs: [],
        ),
      );
      gateway = NativeConnectedHealthGateway(host.productFlows!);
    });
    tearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      await host.close();
      debugDefaultTargetPlatformOverride = null;
    });

    test('startup asks unanswered Health questions without a button', () async {
      final result = await gateway.requestStartupPermissions();
      expect(calls.where((call) => call == 'requestPermissions'), hasLength(1));
      expect(result!.status, ConnectedHealthStatus.authorizationRequested);
      expect(result.failureCode, isNull);
      expect(calls, isNot(contains('readChanges')));
      expect(calls, isNot(contains('openSettings')));
      expect(
        (await host.productFlows!.store.get(
          'connected_health_consent',
          'Apple Health',
        ))!['readRequested'],
        isTrue,
      );
    });

    for (final answered in ['unnecessary', 'unknown']) {
      test(
        'startup does not reprompt or open settings for $answered',
        () async {
          status = answered;
          expect(await gateway.requestStartupPermissions(), isNull);
          expect(calls, ['authorizationRequestStatus']);
          expect(
            await host.productFlows!.store.get(
              'connected_health_consent',
              'Apple Health',
            ),
            isNull,
          );
        },
      );
    }

    test(
      'manual review opens guidance and preserves existing read anchors',
      () async {
        status = 'unnecessary';
        final store = host.productFlows!.store;
        await store.put('connected_health_consent', 'Apple Health', {
          'readRequested': true,
          'weightWriteRequested': true,
        });
        await store.put('health_anchor', 'bil/apple_health', {
          'value': 'keep-anchor',
        });
        final result = await gateway.requestPermissions();
        expect(result.failureCode, 'health_permissions_review_required');
        expect(result.status, ConnectedHealthStatus.authorizationRequested);
        expect(calls, isNot(contains('requestPermissions')));
        expect(calls, isNot(contains('openSettings')));
        expect(
          (await store.get('health_anchor', 'bil/apple_health'))!['value'],
          'keep-anchor',
        );
        expect(
          (await store.get(
            'connected_health_consent',
            'Apple Health',
          ))!['weightWriteRequested'],
          isTrue,
        );
      },
    );

    test(
      'new read types can still request a native sheet after earlier consent',
      () async {
        await host.productFlows!.store.put(
          'connected_health_consent',
          'Apple Health',
          {'readRequested': true},
        );
        final result = await gateway.requestStartupPermissions();
        expect(
          calls.where((call) => call == 'requestPermissions'),
          hasLength(1),
        );
        expect(result!.status, isNot(ConnectedHealthStatus.ready));
      },
    );

    test('old native hosts fall back only for explicit requests', () async {
      messenger.setMockMethodCallHandler(channel, null);
      final bridge = MethodChannelHealthBridge(channelName: 'bil/apple_health');
      expect(
        await bridge.authorizationRequestStatus({'steps'}),
        HealthAuthorizationRequestStatus.unknown,
      );
    });

    test(
      'preview cache rows are ignored, not deleted or counted as Health evidence',
      () async {
        final store = host.productFlows!.store;
        Map<String, Object?> row(String provider, double count) =>
            GlobalHealthSignal(
              key: 'steps',
              canonicalValue: count,
              canonicalUnit: 'count',
              provenance: GlobalProvenance(
                providerId: provider,
                sourceId: 'source',
                recordId: provider,
                observedAt: DateTime.now(),
                confidence: 1,
              ),
            ).toMap();
        await store.put('connected_health_consent', 'Apple Health', {
          'readRequested': true,
        });
        await store.put('connected_health_ui', 'snapshot', {
          'signals': [
            row('preview-fixture', 8000),
            row('bil/apple_health', 321),
          ],
          'stepHistory': [row('preview-fixture', 8000)],
        });
        final loaded = await gateway.load();
        expect(loaded.signals.map((signal) => signal.value), [321]);
        expect(loaded.stepHistory.map((signal) => signal.value), [321]);
        expect(loaded.deviceVerified, isTrue);
        final retained = await store.get('connected_health_ui', 'snapshot');
        expect(retained!['signals'], hasLength(2));

        // A valid native daily history is evidence even if a previous version
        // did not also duplicate the latest day into the summary signals.
        await store.put('connected_health_ui', 'snapshot', {
          'signals': <Object?>[],
          'stepHistory': [row('bil/apple_health', 654)],
        });
        final historyOnly = await gateway.load();
        expect(historyOnly.stepHistory.single.value, 654);
        expect(historyOnly.deviceVerified, isTrue);
        expect(historyOnly.status, ConnectedHealthStatus.synchronized);
      },
    );
  });

  test(
    'review guidance covers all released locales and native privacy API',
    () {
      for (final locale in AppLocalizations.supportedLocales) {
        final text = appleHealthPermissionReviewText(locale);
        expect(text, contains('Body Intelligence Log'), reason: '$locale');
        if (locale.languageCode != 'en') {
          expect(
            text,
            isNot(appleHealthPermissionReviewCopy['en']),
            reason: '$locale',
          );
        }
      }
      final native = File(
        'ios/Runner/BILGlobalHealthBridge.swift',
      ).readAsStringSync();
      expect(
        native,
        contains(
          'getRequestStatusForAuthorization(toShare: [], read: readTypes)',
        ),
      );
      expect(native, contains('case .unnecessary: result("unnecessary")'));
      expect(native, contains('UIApplication.openSettingsURLString'));
      expect(native, isNot(contains('App-Prefs:')));
    },
  );

  for (final entry in ['after startup', 'after onboarding completion']) {
    testWidgets(
      'Health prompt is automatic once $entry and resume cannot duplicate it',
      (tester) async {
        final gateway = _StartupGateway();
        final container = ProviderContainer(
          overrides: [
            connectedHealthGatewayProvider.overrideWithValue(gateway),
          ],
        );
        addTearDown(container.dispose);
        Future<void> mount(bool dashboard) => tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: dashboard
                  ? DashboardHealthActivityRefresh(child: Text(entry))
                  : const SizedBox.shrink(),
            ),
          ),
        );
        await mount(true);
        await tester.pump();
        expect(gateway.startupChecks, 1);
        expect(gateway.dailyReads, 0);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(gateway.startupChecks, 1);
        gateway.pending.complete(const ConnectedHealthSnapshot.unavailable());
        await tester.pumpAndSettle();
        expect(gateway.dailyReads, 1);
        await mount(false);
        await mount(true);
        await tester.pumpAndSettle();
        expect(gateway.startupChecks, 1);
        expect(gateway.manualCalls, 0);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}

class _StartupGateway
    implements
        ConnectedHealthGateway,
        ConnectedHealthStartupPermissionGateway,
        ConnectedHealthDailyActivityGateway {
  final pending = Completer<ConnectedHealthSnapshot?>();
  int startupChecks = 0;
  int dailyReads = 0;
  int manualCalls = 0;
  @override
  Future<ConnectedHealthSnapshot?> requestStartupPermissions() {
    startupChecks++;
    return pending.future;
  }

  @override
  Future<ConnectedHealthSnapshot> loadDailyActivity() async {
    dailyReads++;
    return const ConnectedHealthSnapshot.unavailable();
  }

  @override
  Future<ConnectedHealthSnapshot> load() async =>
      const ConnectedHealthSnapshot.unavailable();
  @override
  Future<ConnectedHealthSnapshot> requestPermissions() {
    manualCalls++;
    return load();
  }

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() =>
      requestPermissions();
  @override
  Future<ConnectedHealthSnapshot> synchronize() => requestPermissions();
  @override
  Future<ConnectedHealthSnapshot> revokePermissions() => requestPermissions();
  @override
  Future<void> openSystemSettings() async {
    manualCalls++;
  }
}
