import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/theme/bil_flagship_theme.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_copy.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_page.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/providers/fitness_device_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/connected_health_card.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/global_platform/fitness_devices/native_ble_fitness_bridge.dart';
import 'package:body_intelligence_log/features/global_platform/platform/native_platform_bridges.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../visual_closure/visual_evidence_font.dart';

const _capture = bool.fromEnvironment('BIL_CAPTURE_HEALTH_REVIEW');

Future<void> _captureSurface(WidgetTester tester, String name) async {
  if (!_capture) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('health-review-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/diagnostics/health_devices_review_20260909/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

final _now = DateTime(2026, 9, 9, 20, 42);

class _Preferences implements PreferencesRepository {
  @override
  Stream<String?> watch(String key) => Stream.value(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ConnectedHealthSignalView _reading(
  String key,
  double value,
  String unit, {
  DateTime? at,
  String source = 'iPhone',
}) => ConnectedHealthSignalView(
  key: key,
  value: value,
  unit: unit,
  source: source,
  observedAt: at ?? _now,
  confidence: 1,
);

ConnectedHealthSnapshot _snapshot(
  TargetPlatform platform,
) => ConnectedHealthSnapshot(
  status: ConnectedHealthStatus.synchronized,
  platformSource: platform == TargetPlatform.iOS
      ? 'Apple Health'
      : 'Health Connect',
  availableSources: [
    platform == TargetPlatform.iOS ? 'Apple Health' : 'Health Connect',
  ],
  signals: [
    _reading('steps', 4321, 'count'),
    _reading('heartRate', 71, 'count/min'),
    _reading('activeEnergy', 415, 'kcal'),
    _reading('sleep', 7.5, 'h'),
    _reading(
      'restingHeartRate',
      66,
      'count/min',
      source: 'com.apple.health.example.long.id',
    ),
    _reading('distance', 21.9, 'm'),
    _reading('hrv', 87.8, 'ms'),
  ],
  // A previous build can have a history missing today, but a current signal.
  stepHistory: [
    _reading(
      'steps',
      9000,
      'count',
      at: _now.subtract(const Duration(days: 1)),
    ),
  ],
  importedCount: 7,
  lastSyncAt: _now.subtract(const Duration(minutes: 16)),
  failureCode: null,
  deviceVerified: true,
);

class _Gateway implements ConnectedHealthGateway {
  _Gateway(this.value);
  ConnectedHealthSnapshot value;
  int syncs = 0;
  int loads = 0;
  int exports = 0;
  Completer<ConnectedHealthSnapshot>? pending;
  @override
  Future<ConnectedHealthSnapshot> load() async {
    loads++;
    return value;
  }

  @override
  Future<ConnectedHealthSnapshot> synchronize() {
    syncs++;
    return (pending = Completer()).future;
  }

  void finish() {
    value = value.copyWith(lastSyncAt: _now);
    pending!.complete(value);
  }

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async => value;
  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async {
    exports++;
    return value;
  }

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async => value;
  @override
  Future<void> openSystemSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_capture) setUpAll(loadVisualEvidenceFont);
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final locale in AppLocalizations.supportedLocales) {
      final tag = BilLocalePolicy.canonicalTag(locale);
      testWidgets(
        '${platform.name}/$tag manual refresh, phone steps, navigation and uncluttered readings',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final gateway = _Gateway(_snapshot(platform));
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConnectedHealthCard(
                      languageCode: tag,
                      compact: true,
                      dashboardCompact: true,
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/connected-health',
                builder: (_, _) => const ConnectedHealthPage(),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                preferencesRepositoryProvider.overrideWithValue(_Preferences()),
                connectedHealthGatewayProvider.overrideWithValue(gateway),
                fitnessDeviceProvider.overrideWith(
                  (ref) =>
                      FitnessDeviceController(MethodChannelBleFitnessBridge()),
                ),
                verifiedSubscriptionStateProvider.overrideWith(
                  (ref) async => SubscriptionState(
                    plan: CommercePlan.premium,
                    entitlements: {},
                    authority: EntitlementAuthority.verifiedServer,
                    isPurchasable: true,
                    canRestorePurchases: true,
                  ),
                ),
                liveHealthNowProvider.overrideWithValue(() => _now),
              ],
              child: MaterialApp.router(
                routerConfig: router,
                locale: locale,
                theme: _capture
                    ? visualEvidenceTheme(
                        BilFlagshipTheme.light(isArabic: tag == 'ar'),
                        fontFamily: tag == 'ar'
                            ? 'NotoArabicEvidence'
                            : 'RobotoEvidence',
                      )
                    : null,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: RepaintBoundary(
                    key: const Key('health-review-capture'),
                    child: child!,
                  ),
                ),
              ),
            ),
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(MaterialApp)),
          );
          await container.read(connectedHealthProvider.notifier).refresh();
          await tester.pumpAndSettle();
          expect(gateway.syncs, 0);
          expect(find.text('4321'), findsOneWidget);
          expect(find.byKey(const Key('watch-metric-sleep')), findsOneWidget);
          expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
          await _captureSurface(tester, '${platform.name}_${tag}_dashboard');
          final refresh = find.byKey(const Key('dashboard-fitness-last-sync'));
          await tester.tap(refresh);
          await tester.pump();
          expect(gateway.syncs, 1);
          expect(
            container.read(connectedHealthProvider).value!.lastSyncAt,
            isNot(_now),
          );
          await tester.tap(refresh);
          await tester.pump();
          expect(find.byType(ConnectedHealthPage), findsNothing);
          expect(gateway.syncs, 1);
          gateway.finish();
          await tester.pumpAndSettle();
          expect(
            container.read(connectedHealthProvider).value!.lastSyncAt,
            _now,
          );
          await tester.tap(
            find.text(
              connectedHealthTextForLanguage(
                tag,
                'Fitness snapshot',
                'ملخص اللياقة',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ConnectedHealthPage), findsOneWidget);
          expect(gateway.syncs, 1);
          expect(
            find.byKey(const Key('connected-health-live-watch-card')),
            findsOneWidget,
          );
          await _captureSurface(tester, '${platform.name}_${tag}_devices');
          await tester.tap(
            find.byKey(const Key('connected-health-watch-refresh')),
          );
          await tester.pump();
          expect(gateway.syncs, 2);
          // Back must work while the native operation is still unresolved.
          await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          expect(find.byType(ConnectedHealthPage), findsNothing);
          gateway.finish();
          await tester.pumpAndSettle();
          router.push('/connected-health');
          await tester.pumpAndSettle();
          final settings = find.byKey(
            const Key('connected-health-source-settings'),
          );
          await tester.scrollUntilVisible(settings, 220);
          await tester.ensureVisible(settings);
          await tester.pumpAndSettle();
          await _captureSurface(tester, '${platform.name}_${tag}_source');
          await tester.tap(settings);
          await tester.pumpAndSettle();
          final export = find.byKey(
            const Key('connected-health-weight-export'),
          );
          await tester.ensureVisible(export);
          await tester.pumpAndSettle();
          await tester.tap(export);
          await tester.pumpAndSettle();
          expect(gateway.exports, 1);
          expect(gateway.syncs, 2);
          final signals = find.byKey(
            const Key('connected-health-signals-card'),
          );
          await tester.scrollUntilVisible(signals, 250);
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: signals, matching: find.text('iPhone')),
            findsNothing,
          );
          expect(
            find.textContaining('com.apple.health.example.long.id'),
            findsNothing,
          );
          expect(
            find.descendant(
              of: signals,
              matching: find.textContaining('count/min'),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }

  test(
    'timed-out sync retry attaches to native flight instead of importing twice',
    () async {
      final gateway = _Gateway(_snapshot(TargetPlatform.iOS));
      final controller = ConnectedHealthController(
        gateway,
        synchronizationTimeout: Duration.zero,
      );
      await controller.refresh();
      final originalTime = controller.state.value!.lastSyncAt;
      await controller.synchronize();
      await controller.synchronize();
      expect(gateway.syncs, 1);
      expect(controller.state.value!.isBusy, isFalse);
      expect(controller.state.value!.lastSyncAt, originalTime);
      gateway.finish();
      await Future<void>.delayed(Duration.zero);
      // Late completion doesn't turn a failed UI attempt into a claimed success.
      expect(controller.state.value!.failureCode, 'health_sync_timed_out');
      controller.dispose();
    },
  );

  for (final channelName in ['bil/apple_health', 'bil/health_connect']) {
    test(
      '$channelName daily totals preserve OS aggregation and calendar provenance',
      () async {
        final channel = MethodChannel(channelName);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'readDailyTotals');
          expect((call.arguments as Map).keys, ['asOf']);
          return [
            for (final source in ['health.statistics', 'health.statistics'])
              {
                'id': 'daily:steps:2026-09-09',
                'type': 'steps',
                'value': 4321,
                'unit': 'count',
                'observedAt': _now.toUtc().toIso8601String(),
                'sourceId': source,
                'timeZoneId': 'Africa/Cairo',
                'attributes': {
                  'aggregation': 'native_daily',
                  'sources': ['phone', 'watch'],
                },
              },
          ];
        });
        final records = await MethodChannelHealthBridge(
          channelName: channelName,
        ).readDailyTotals(asOf: _now);
        final projected = nativeDailyActivitySignals(records, _now);
        expect(projected, hasLength(1));
        expect(projected.single.canonicalValue, 4321); // never 8642
        expect(projected.single.provenance.providerId, channelName);
        expect(projected.single.attributes['sources'], ['phone', 'watch']);
        expect(nativeDailyActivitySignals([], _now), isEmpty);
        expect(
          nativeDailyActivitySignals(
            records,
            _now.subtract(const Duration(days: 1)),
          ),
          isEmpty,
        );
        expect(
          nativeDailyActivitySignals(
            records,
            _now.add(const Duration(days: 31)),
          ),
          isEmpty,
        );
      },
    );
  }

  test(
    'identical BLE pulse at a later time is a new observation; corrupt packets abstain',
    () {
      const parser = BleGattMeasurementParser();
      Map<String, Object?> packet(DateTime at) => {
        'peripheralId': 'sensor',
        'characteristic': '2A37',
        'packet': base64Encode([0, 71]),
        'receivedAt': at.toIso8601String(),
      };
      final first = parser.parse(packet(_now), asOf: _now).single;
      final repeat = parser
          .parse(packet(_now.add(const Duration(seconds: 5))), asOf: _now)
          .single;
      expect(first['value'], repeat['value']);
      expect(first['sampleId'], isNot(repeat['sampleId']));
      expect(
        parser.parse({...packet(_now), 'packet': '!!!'}, asOf: _now),
        isEmpty,
      );
    },
  );

  test(
    'native bridges use unfiltered OS totals, bounded foreground queries and scoped BLE reads',
    () {
      final swift = File(
        'ios/Runner/BILGlobalHealthBridge.swift',
      ).readAsStringSync();
      final kotlin = File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILGlobalHealthBridge.kt',
      ).readAsStringSync();
      expect(swift, contains('HKStatisticsCollectionQuery('));
      expect(swift, contains('options: .cumulativeSum'));
      expect(swift, contains('value: -29'));
      expect(swift, isNot(contains('options: .separateBySource')));
      expect(kotlin, contains('aggregateGroupByPeriod('));
      expect(kotlin, contains('Period.ofDays(1)'));
      expect(kotlin, isNot(contains('dataOriginFilter =')));
      expect(
        kotlin,
        contains('HealthPermission.getReadPermission(StepsRecord::class)'),
      );
      final ble = File(
        'ios/Runner/BILFitnessBleBridge.swift',
      ).readAsStringSync();
      expect(ble, contains('session.seenPackets.insert'));
      expect(ble, isNot(contains('private var seenPackets')));
      expect(ble, contains('peripheral.setNotifyValue(false'));
      expect(ble, contains('central.retrievePeripherals(withIdentifiers:'));
      final androidBle = File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILFitnessBleBridge.kt',
      ).readAsStringSync();
      expect(
        androidBle,
        contains('BluetoothAdapter.checkBluetoothAddress(id)'),
      );
      expect(androidBle, contains('getRemoteDevice(id)'));
    },
  );
}
