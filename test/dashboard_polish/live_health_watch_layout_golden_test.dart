import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ConnectedHealthSignalView _signal(String key, double value, String unit) =>
    ConnectedHealthSignalView(
      key: key,
      value: value,
      unit: unit,
      source: 'QA watch',
      observedAt: DateTime.utc(2026, 8, 31, 14, 20),
      confidence: .98,
    );

void main() {
  testWidgets('compact watch keeps all four readings below the clock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(220, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveHealthNowProvider.overrideWithValue(
            () => DateTime.utc(2026, 8, 31, 14, 22, 8),
          ),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            backgroundColor: Color(0xFFF5F6F8),
            body: RepaintBoundary(
              key: const Key('live-health-watch-golden-boundary'),
              child: ColoredBox(
                color: const Color(0xFFF5F6F8),
                child: Center(
                  child: SizedBox.square(
                    dimension: 176,
                    child: LiveHealthWatch(
                      compact: true,
                      languageCode: 'en',
                      snapshot: ConnectedHealthSnapshot(
                        status: ConnectedHealthStatus.synchronized,
                        platformSource: 'Apple Health',
                        availableSources: const ['Apple Health'],
                        signals: [
                          _signal('heartRate', 80, 'bpm'),
                          _signal('activeEnergy', 300, 'kcal'),
                          _signal('sleep', 4.8, 'h'),
                        ],
                        stepHistory: [_signal('steps', 2198, 'count')],
                        importedCount: 4,
                        lastSyncAt: DateTime.utc(2026, 8, 31, 12),
                        failureCode: null,
                        deviceVerified: true,
                      ),
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

    await expectLater(
      find.byKey(const Key('live-health-watch-golden-boundary')),
      matchesGoldenFile('goldens/live_health_watch_compact_all_metrics.png'),
    );
  });
}
