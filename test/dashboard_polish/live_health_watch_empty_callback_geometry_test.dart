import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual_closure/visual_evidence_font.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);

  for (final side in [280.0, 304.0]) {
    for (final language in ['en', 'ar']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('full empty watch $side $language ${scale}x keeps copy '
            'below the clock and its action usable', (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var taps = 0;

          Widget subject({required bool showMetrics}) => ProviderScope(
            overrides: [
              liveHealthNowProvider.overrideWithValue(
                () => DateTime(2026, 11, 15, 4),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'RobotoEvidence'),
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Center(
                    child: SizedBox.square(
                      dimension: side,
                      child: LiveHealthWatch(
                        snapshot: const ConnectedHealthSnapshot.unavailable(),
                        languageCode: language,
                        showMetrics: showMetrics,
                        onConnectTap: () => taps++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpWidget(subject(showMetrics: false));
          await tester.pump();
          final clock = tester.getRect(
            find.byKey(const Key('watch-digital-time')),
          );
          final date = tester.getRect(find.byKey(const Key('watch-date-line')));

          await tester.pumpWidget(subject(showMetrics: true));
          await tester.pump();
          final label = tester.getRect(
            find.byKey(const Key('watch-no-recent-readings')),
          );
          final cta = find.byKey(const Key('watch-connect-health-cta'));
          final action = tester.getRect(cta);

          expect(
            tester.getRect(find.byKey(const Key('watch-digital-time'))),
            clock,
          );
          expect(
            tester.getRect(find.byKey(const Key('watch-date-line'))),
            date,
          );
          expect(label.top, greaterThanOrEqualTo(clock.bottom));
          expect(label.bottom, lessThanOrEqualTo(action.top));
          expect(action.overlaps(clock), isFalse);
          expect(action.height, greaterThanOrEqualTo(48));
          expect(
            tester
                .widget<Text>(find.byKey(const Key('watch-no-recent-readings')))
                .data,
            language == 'ar' ? 'لا توجد قراءات حديثة' : 'No recent readings',
          );
          final context = tester.element(find.byType(LiveHealthWatch));
          expect(MediaQuery.textScalerOf(context).scale(10), 10 * scale);
          await tester.tap(cta);
          await tester.pump();
          expect(taps, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
      }
    }
  }
}
