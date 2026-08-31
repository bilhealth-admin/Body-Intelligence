import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:body_intelligence_log/features/connected_health/widgets/live_health_watch.dart';
import 'package:body_intelligence_log/shared/widgets/bil_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _subject({required Locale locale, required VoidCallback onConnect}) =>
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: Directionality(
              textDirection: locale.languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Scaffold(
                body: Center(
                  child: SizedBox.square(
                    dimension: 188,
                    child: LiveHealthWatch(
                      snapshot: const ConnectedHealthSnapshot.unavailable(),
                      languageCode: locale.languageCode,
                      compact: true,
                      onConnectTap: onConnect,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final configuration in const [
    (locale: Locale('en'), semantics: 'Link fitness'),
    (locale: Locale('ar'), semantics: 'ربط اللياقة'),
  ]) {
    testWidgets(
      '${configuration.locale.languageCode} dashboard watch is icon-only at 160%',
      (tester) async {
        var taps = 0;
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          _subject(locale: configuration.locale, onConnect: () => taps += 1),
        );
        await tester.pump();

        expect(find.text('Not connected · Connect'), findsNothing);
        expect(find.text('غير متصل · ربط'), findsNothing);
        expect(
          tester
              .getSemantics(
                find.byKey(const Key('watch-connect-health-semantics')),
              )
              .label,
          contains(configuration.semantics),
        );

        expect(find.byType(BilFullWordmark), findsNothing);
        expect(find.text('BODY INTELLIGENCE LOG'), findsNothing);
        expect(find.byKey(const Key('watch-date-line')), findsOneWidget);
        expect(find.byKey(const Key('watch-digital-time')), findsOneWidget);
        expect(
          tester.getSize(
            find.byKey(const Key('watch-connect-health-icon-disc')),
          ),
          const Size.square(30),
        );
        expect(
          tester
              .widget<Icon>(find.byKey(const Key('watch-connect-health-icon')))
              .size,
          12,
        );

        await tester.tap(find.byKey(const Key('watch-connect-health-cta')));
        await tester.pump();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
