import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/providers/connected_health_provider.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 22, 1, 17);
final _start = DateTime(2026, 11, 20, 8);

ConnectedHealthSignalView _reading(
  String key,
  double value,
  String unit,
  DateTime observedAt, {
  Map<String, Object?> attributes = const {},
}) => ConnectedHealthSignalView(
  key: key,
  value: value,
  unit: unit,
  source: 'Apple Watch',
  observedAt: observedAt,
  confidence: 1,
  attributes: attributes,
);

Future<void> _pumpWatch(
  WidgetTester tester,
  ConnectedHealthSignalView sleep,
) async {
  final yesterday = _now.subtract(const Duration(days: 1));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [liveHealthNowProvider.overrideWithValue(() => _now)],
      child: MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 280,
              child: LiveHealthWatch(
                snapshot: ConnectedHealthSnapshot(
                  status: ConnectedHealthStatus.synchronized,
                  platformSource: 'Apple Health',
                  availableSources: const ['Apple Health'],
                  signals: [
                    sleep,
                    _reading('steps', 1081, 'count', yesterday),
                    _reading('activeEnergy', 56.1, 'kcal', yesterday),
                    _reading('heartRate', 79, 'bpm', yesterday),
                  ],
                  importedCount: 4,
                  lastSyncAt: _now,
                  failureCode: null,
                  deviceVerified: true,
                ),
                languageCode: 'en',
                compact: true,
                showConnectControl: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'sleep remains recent from its actual end across gaps and midnight',
    (tester) async {
      GlobalHealthSignal stage(String id, DateTime start, DateTime end) =>
          GlobalHealthSignal(
            key: 'sleep',
            canonicalValue: end.difference(start).inMinutes / 60,
            canonicalUnit: 'h',
            provenance: GlobalProvenance(
              providerId: 'apple-health',
              sourceId: 'com.apple.health',
              recordId: id,
              observedAt: start,
              confidence: 1,
              deviceId: 'Apple Watch',
            ),
            attributes: {
              'sleepStage': 'core',
              'endedAt': end.toIso8601String(),
            },
          );
      final end = DateTime(2026, 11, 20, 14);
      final aggregate = aggregateConnectedSleepSignals([
        stage(
          'first',
          _start,
          _start.add(const Duration(hours: 4, minutes: 30)),
        ),
        stage('last', end.subtract(const Duration(minutes: 30)), end),
      ]).single;
      // Five measured hours span six elapsed hours. Inferring end=start+value
      // would incorrectly hide this completed session.
      expect(aggregate.canonicalValue, 5);
      expect(aggregate.provenance.observedAt, _start.toUtc());
      expect(DateTime.parse('${aggregate.attributes['endedAt']}'), end.toUtc());
      final sleep = ConnectedHealthSignalView.fromSignal(aggregate);
      await _pumpWatch(tester, sleep);

      expect(find.byKey(const Key('watch-metric-sleep')), findsOneWidget);
      expect(find.text('5.0'), findsOneWidget);
      expect(find.byKey(const Key('watch-no-recent-readings')), findsNothing);
      expect(find.byKey(const Key('watch-metric-steps')), findsNothing);
      expect(find.byKey(const Key('watch-metric-active-energy')), findsNothing);
      expect(find.byKey(const Key('watch-metric-heart-rate')), findsNothing);
      expect(sleep.observedAt, _start.toUtc());
      expect(sleep.source, 'Apple Watch');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final age in [
    const Duration(hours: 36),
    const Duration(hours: 36, milliseconds: 1),
  ]) {
    testWidgets(
      'sleep end respects the unchanged 36-hour boundary: $age',
      (tester) async {
        final end = _now.subtract(age);
        await _pumpWatch(
          tester,
          _reading(
            'sleep',
            3.1,
            'h',
            _start,
            attributes: {'endedAt': end.toIso8601String()},
          ),
        );
        expect(
          find.byKey(const Key('watch-metric-sleep')),
          age == const Duration(hours: 36) ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final (name, end) in <(String, Object?)>[
    ('missing', null),
    ('malformed', 'invalid-date'),
    (
      'before start',
      _start.subtract(const Duration(minutes: 1)).toIso8601String(),
    ),
    ('equal start', _start.toIso8601String()),
    ('future', _now.add(const Duration(minutes: 1)).toIso8601String()),
  ]) {
    testWidgets(
      'invalid sleep end cannot make an old start recent: $name',
      (tester) async {
        await _pumpWatch(
          tester,
          _reading('sleep', 3.1, 'h', _start, attributes: {'endedAt': end}),
        );
        expect(find.byKey(const Key('watch-metric-sleep')), findsNothing);
        expect(
          find.byKey(const Key('watch-no-recent-readings')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'sleep without completion metadata preserves recent-start fallback',
    (tester) async {
      await _pumpWatch(
        tester,
        _reading('sleep', 3.1, 'h', _now.subtract(const Duration(hours: 8))),
      );
      expect(find.byKey(const Key('watch-metric-sleep')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
