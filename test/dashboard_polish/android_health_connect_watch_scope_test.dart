import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 18, 19, 30);

ConnectedHealthSignalView _signal(String key, double value, String unit) =>
    ConnectedHealthSignalView(
      key: key,
      value: value,
      unit: unit,
      source: 'Synthetic authorized device source',
      observedAt: _now,
      confidence: 1,
    );

final _activity = [
  _signal('steps', 1200, 'count'),
  _signal('distance', 840, 'm'),
  _signal('activeEnergy', 52, 'kcal'),
];
final _unsupported = [
  _signal('heartRate', 71, 'bpm'),
  _signal('restingHeartRate', 60, 'bpm'),
  _signal('sleep', 7.5, 'h'),
  _signal('weight', 70, 'kg'),
  _signal('bodyFat', 20, '%'),
];

Future<void> _mount(
  WidgetTester tester,
  List<ConnectedHealthSignalView> signals, {
  Locale locale = const Locale('en'),
  double scale = 1,
  bool denied = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final snapshot = ConnectedHealthSnapshot(
    status: denied
        ? ConnectedHealthStatus.permissionDenied
        : ConnectedHealthStatus.synchronized,
    platformSource: defaultTargetPlatform == TargetPlatform.android
        ? 'Health Connect'
        : 'Apple Health',
    availableSources: const ['Synthetic authorized device source'],
    signals: signals,
    importedCount: signals.length,
    lastSyncAt: _now,
    failureCode: null,
    deviceVerified: !denied,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [liveHealthNowProvider.overrideWithValue(() => _now)],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Center(
                child: SizedBox.square(
                  dimension: 224,
                  child: LiveHealthWatch(
                    snapshot: snapshot,
                    languageCode: locale.languageCode,
                    compact: true,
                    showConnectControl: false,
                  ),
                ),
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
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('Android measured activity only, including distance: $locale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _mount(
        tester,
        [..._activity, ..._unsupported],
        locale: locale,
        scale: 2,
      );
      for (final key in ['steps', 'distance', 'active-energy']) {
        expect(find.byKey(Key('watch-metric-$key')), findsOneWidget);
      }
      expect(find.byKey(const Key('watch-metric-heart-rate')), findsNothing);
      expect(find.byKey(const Key('watch-metric-sleep')), findsNothing);
      expect(find.text('840'), findsOneWidget);
      expect(find.text('1200'), findsOneWidget);
      expect(find.text('52'), findsOneWidget);
      expect(find.text('71'), findsNothing);
      expect(find.text('7.5'), findsNothing);
      expect(
        find.bySemanticsLabel(
          RegExp(locale.languageCode == 'ar' ? 'المسافة' : 'Distance'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('a distance-only Android import is a real reading, not empty', (
    tester,
  ) async {
    await _mount(tester, [_activity[1]]);
    expect(find.byKey(const Key('watch-metric-distance')), findsOneWidget);
    expect(find.byKey(const Key('watch-metric-steps')), findsNothing);
    expect(find.byKey(const Key('watch-metric-active-energy')), findsNothing);
    expect(find.byKey(const Key('watch-no-recent-readings')), findsNothing);
    expect(find.text('840'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final signals in [<ConnectedHealthSignalView>[], _unsupported]) {
    testWidgets(
      'Android does not fabricate missing activity (${signals.length} other readings)',
      (tester) async {
        await _mount(tester, signals);
        expect(
          find.byKey(const Key('watch-no-recent-readings')),
          findsOneWidget,
        );
        for (final key in [
          'steps',
          'distance',
          'active-energy',
          'heart-rate',
          'sleep',
        ]) {
          expect(find.byKey(Key('watch-metric-$key')), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Android revoked cached activity remains hidden', (tester) async {
    await _mount(tester, _activity, denied: true);
    expect(find.byKey(const Key('watch-no-recent-readings')), findsOneWidget);
    expect(find.text('840'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('yesterday distance is not a current Android reading', (
    tester,
  ) async {
    await _mount(tester, [
      ConnectedHealthSignalView(
        key: 'distance',
        value: 950,
        unit: 'm',
        source: 'Synthetic authorized device source',
        observedAt: _now.subtract(const Duration(days: 1)),
        confidence: 1,
      ),
    ]);
    expect(find.byKey(const Key('watch-metric-distance')), findsNothing);
    expect(find.byKey(const Key('watch-no-recent-readings')), findsOneWidget);
    expect(find.text('950'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'iOS retains its existing four-metric face without Android distance',
    (tester) async {
      await _mount(tester, [..._activity, ..._unsupported]);
      for (final key in ['steps', 'heart-rate', 'active-energy', 'sleep']) {
        expect(find.byKey(Key('watch-metric-$key')), findsOneWidget);
      }
      expect(find.byKey(const Key('watch-metric-distance')), findsNothing);
      expect(find.text('71'), findsOneWidget);
      expect(find.text('7.5'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
