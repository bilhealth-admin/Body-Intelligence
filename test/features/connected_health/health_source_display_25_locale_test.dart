import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_copy.dart';
import 'package:body_intelligence_log/features/connected_health/connected_health_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reviewed = <String, String>{
    'ar': 'مصدر الصحة',
    'en': 'Health source',
    'fr': 'Source santé',
    'es': 'Fuente de salud',
    'tr': 'Sağlık kaynağı',
  };
  const rawSource = '{"metadata":{"deviceId":"opaque-source-id"}}';
  final signal = ConnectedHealthSignalView(
    key: 'sleep',
    value: 2.6,
    unit: 'h',
    source: rawSource,
    observedAt: DateTime.utc(2026, 10, 8),
    confidence: 1,
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('Unknown health source is localized ${locale.toLanguageTag()}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Text(
                connectedHealthDisplayName(context, signal),
                key: const Key('unknown-health-source-label'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final display = tester.widget<Text>(
        find.byKey(const Key('unknown-health-source-label')),
      ).data!;
      final tag = BilLocalePolicy.canonicalTag(locale);
      expect(display.trim(), isNotEmpty);
      if (tag != 'en') expect(display, isNot('Health source'));
      if (reviewed.containsKey(tag)) expect(display, reviewed[tag]);
      expect(display, isNot(contains('{')));
      expect(display, isNot(contains('opaque-source-id')));
      expect(signal.source, rawSource, reason: 'provenance must not mutate');
      expect(tester.takeException(), isNull);
    });
  }
}
