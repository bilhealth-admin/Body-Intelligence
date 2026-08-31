import 'dart:io';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/fitness_device_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/connected_health_card.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ConnectedHealthSignalView _signal(
  String key,
  double value,
  String unit, {
  String source = 'verified-device',
  double confidence = .98,
}) => ConnectedHealthSignalView(
  key: key,
  value: value,
  unit: unit,
  source: source,
  observedAt: DateTime.utc(2026, 8, 31, 12),
  confidence: confidence,
);

ConnectedHealthSnapshot _snapshot({
  required ConnectedHealthStatus status,
  required bool verified,
  required List<ConnectedHealthSignalView> signals,
  String? source = 'Health Connect',
}) => ConnectedHealthSnapshot(
  status: status,
  platformSource: source,
  availableSources: source == null ? const [] : [source],
  signals: signals,
  importedCount: signals.length,
  lastSyncAt: DateTime.utc(2026, 8, 31, 12),
  failureCode: null,
  deviceVerified: verified,
);

Widget _subject(
  ConnectedHealthSnapshot snapshot, {
  Locale locale = const Locale('en'),
}) => ProviderScope(
  overrides: [
    liveHealthNowProvider.overrideWithValue(
      () => DateTime(2026, 8, 31, 14, 22, 8),
    ),
  ],
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: 280,
          child: LiveHealthWatch(
            snapshot: snapshot,
            languageCode: locale.languageCode,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('connected watch renders only actual supported readings', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _subject(
        _snapshot(
          status: ConnectedHealthStatus.synchronized,
          verified: true,
          signals: [
            _signal('steps', 4321, 'steps'),
            _signal('heartRate', 71, 'bpm'),
            _signal('activeEnergy', 415, 'kcal'),
            _signal('sleep', 7.5, 'h'),
            _signal('weight', 80, 'kg'),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('watch-date-line')), findsOneWidget);
    expect(find.byKey(const Key('watch-digital-time')), findsOneWidget);
    expect(find.byKey(const Key('watch-metric-steps')), findsOneWidget);
    expect(find.byKey(const Key('watch-metric-heart-rate')), findsOneWidget);
    expect(find.byKey(const Key('watch-metric-active-energy')), findsOneWidget);
    expect(find.byKey(const Key('watch-metric-sleep')), findsOneWidget);
    expect(find.text('4321'), findsOneWidget);
    expect(find.text('71'), findsOneWidget);
    expect(find.text('415'), findsOneWidget);
    expect(find.text('7.5'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(find.byIcon(Icons.directions_walk_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bedtime_outlined), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Steps, 4321 steps')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Heart rate, 71 bpm')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  for (final status in const [
    ConnectedHealthStatus.unavailable,
    ConnectedHealthStatus.permissionRequired,
    ConnectedHealthStatus.permissionDenied,
    ConnectedHealthStatus.authorizationRequested,
    ConnectedHealthStatus.degraded,
  ]) {
    testWidgets('$status hides stale readings but keeps clock and link CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(
          _snapshot(
            status: status,
            verified: true,
            signals: [_signal('steps', 9999, 'steps')],
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('watch-date-line')), findsOneWidget);
      expect(find.byKey(const Key('watch-digital-time')), findsOneWidget);
      expect(find.byKey(const Key('watch-metric-steps')), findsNothing);
      expect(find.byKey(const Key('watch-metric-heart-rate')), findsNothing);
      expect(find.byKey(const Key('watch-metric-active-energy')), findsNothing);
      expect(find.byKey(const Key('watch-metric-sleep')), findsNothing);
      expect(find.byKey(const Key('watch-connect-health-cta')), findsOneWidget);
      expect(find.text('9999'), findsNothing);
      expect(find.text('—'), findsNothing);
    });
  }

  testWidgets('unverified, source-less, and invalid signals stay hidden', (
    tester,
  ) async {
    for (final snapshot in [
      _snapshot(
        status: ConnectedHealthStatus.synchronized,
        verified: false,
        signals: [_signal('steps', 100, 'steps')],
      ),
      _snapshot(
        status: ConnectedHealthStatus.synchronized,
        verified: true,
        source: null,
        signals: [_signal('steps', 100, 'steps')],
      ),
      _snapshot(
        status: ConnectedHealthStatus.synchronized,
        verified: true,
        signals: [
          _signal('steps', double.nan, 'steps'),
          _signal('heartRate', 70, 'bpm', source: ''),
          _signal('sleep', 7, 'h', confidence: 0),
        ],
      ),
    ]) {
      await tester.pumpWidget(_subject(snapshot));
      await tester.pump();
      expect(find.byKey(const Key('watch-metric-steps')), findsNothing);
      expect(find.byKey(const Key('watch-metric-heart-rate')), findsNothing);
      expect(find.byKey(const Key('watch-metric-sleep')), findsNothing);
      expect(find.byKey(const Key('watch-date-line')), findsOneWidget);
      expect(find.byKey(const Key('watch-digital-time')), findsOneWidget);
    }
  });

  test('watch scope contains no oxygen or SpO2 metric', () {
    expect(liveHealthWatchSignalIsActual(_signal('oxygen', 98, '%')), isFalse);
    expect(liveHealthWatchSignalIsActual(_signal('SpO2', 98, '%')), isFalse);
  });

  testWidgets(
    'connected BLE heart rate is shown inside watch without body metrics',
    (tester) async {
      final merged = dashboardWatchSnapshot(
        _snapshot(
          status: ConnectedHealthStatus.permissionRequired,
          verified: false,
          signals: [_signal('steps', 9999, 'steps')],
        ),
        FitnessDeviceSnapshot(
          status: FitnessDeviceConnectionStatus.connected,
          connectedDeviceId: 'strap-a',
          measurements: <Map<String, Object?>>[
            <String, Object?>{
              'kind': 'weight',
              'value': 78.0,
              'unit': 'kg',
              'observedAt': DateTime.utc(2026, 8, 31, 12).toIso8601String(),
            },
            <String, Object?>{
              'kind': 'body_fat',
              'value': 20.0,
              'unit': '%',
              'observedAt': DateTime.utc(2026, 8, 31, 12).toIso8601String(),
            },
            <String, Object?>{
              'kind': 'heart_rate',
              'value': 72.0,
              'unit': 'bpm',
              'observedAt': DateTime.utc(2026, 8, 31, 12).toIso8601String(),
            },
          ],
        ),
      );

      expect(merged.status, ConnectedHealthStatus.synchronized);
      expect(merged.signals.map((signal) => signal.key), ['heartRate']);
      expect(merged.availableSources, ['Bluetooth fitness device']);

      await tester.pumpWidget(_subject(merged));
      await tester.pump();
      expect(find.byKey(const Key('watch-metric-heart-rate')), findsOneWidget);
      expect(find.byKey(const Key('watch-metric-steps')), findsNothing);
      expect(find.text('72'), findsOneWidget);
      expect(find.text('78'), findsNothing);
      expect(find.text('20'), findsNothing);
    },
  );

  test('connected BLE with no packet is a source but invents no reading', () {
    final merged = dashboardWatchSnapshot(
      const ConnectedHealthSnapshot.unavailable(),
      const FitnessDeviceSnapshot(
        status: FitnessDeviceConnectionStatus.connected,
        connectedDeviceId: 'strap-a',
      ),
    );

    expect(merged.status, ConnectedHealthStatus.ready);
    expect(merged.deviceVerified, isTrue);
    expect(merged.availableSources, ['Bluetooth fitness device']);
    expect(merged.signals, isEmpty);
    expect(merged.lastSyncAt, isNull);
  });

  test('disconnected BLE retained packets cannot appear on the watch', () {
    final base = const ConnectedHealthSnapshot.unavailable();
    final merged = dashboardWatchSnapshot(
      base,
      FitnessDeviceSnapshot(
        status: FitnessDeviceConnectionStatus.idle,
        connectedDeviceId: 'strap-a',
        measurements: <Map<String, Object?>>[
          <String, Object?>{
            'kind': 'heart_rate',
            'value': 72.0,
            'unit': 'bpm',
            'observedAt': DateTime.utc(2026, 8, 31, 12).toIso8601String(),
          },
        ],
      ),
    );

    expect(identical(merged, base), isTrue);
    expect(merged.signals, isEmpty);
  });

  test('dashboard CTA and status follow aggregate connection truth', () {
    final card = File(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    ).readAsStringSync();

    expect(
      card,
      contains('final hasConnectedSource = liveHealthWatchCanShowMetrics'),
    );
    expect(card, contains('child: hasConnectedSource'));
    expect(
      card,
      contains('ConnectedHealthStatusDot(status: watchSnapshot.status)'),
    );
    expect(card, contains('if (baseUsable) ...snapshot.signals'));
    expect(card, contains('?latestHeartRate'));
  });
}
