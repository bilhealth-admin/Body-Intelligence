import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final arabic in [false, true]) {
      testWidgets(
        'selectable transcript and stored timestamp $platform Arabic=$arabic',
        (tester) async {
          final text = arabic ? 'رسالة محفوظة للاختبار' : 'Saved test message';
          final created = DateTime(2026, 9, 8, 10, 35);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(arabic ? 'ar' : 'en'),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(alwaysUse24HourFormat: true),
                child: child!,
              ),
              home: Scaffold(
                body: Center(
                  child: CoachMessageText(
                    text: text,
                    createdAt: created,
                    alignEnd: arabic,
                    textDirection: arabic
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final selectable = tester.widget<SelectableText>(
            find.byType(SelectableText),
          );
          expect(selectable.data, text);
          expect(selectable.enableInteractiveSelection, isTrue);
          final context = tester.element(find.byType(CoachMessageText));
          final expected = TimeOfDay.fromDateTime(created).format(context);
          expect(find.text(expected), findsOneWidget);
          await tester.pump(const Duration(minutes: 2));
          expect(find.text(expected), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('fresh BIL reply reveals at a conversational pace without delaying its timestamp', (
    tester,
  ) async {
    const reply =
        'Your saved answer appears smoothly while its full content remains accessible.';
    final created = DateTime(2026, 9, 13, 11, 30);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachMessageText(
            text: reply,
            createdAt: created,
            textDirection: TextDirection.ltr,
            animateReveal: true,
          ),
        ),
      ),
    );

    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      isNot(reply),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      isNot(reply),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      reply,
    );
    expect(tester.takeException(), isNull);
  });
}
