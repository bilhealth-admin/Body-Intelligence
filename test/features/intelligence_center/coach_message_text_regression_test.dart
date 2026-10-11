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

  testWidgets(
    'fresh BIL reply reveals at a conversational pace without delaying its timestamp',
    (tester) async {
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
    },
  );

  testWidgets(
    'reply geometry remains fixed throughout reveal for Arabic, emoji and long text',
    (tester) async {
      const prefix = 'تقرير 🥗💪🏽 عربي English 👨‍👩‍👧‍👦';
      final reply = List<String>.filled(70, prefix).join(' ');
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 340,
                child: CoachMessageText(
                  key: const ValueKey('coach-long-geometry'),
                  text: reply,
                  createdAt: DateTime(2026, 10, 8),
                  textDirection: TextDirection.rtl,
                  animateReveal: true,
                ),
              ),
            ),
          ),
        ),
      );

      final message = find.byType(CoachMessageText);
      final initialSize = tester.getSize(message);
      expect(initialSize.height, greaterThan(250));
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        isNot(reply),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(message).height, closeTo(initialSize.height, .01));
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.getSize(message).height, closeTo(initialSize.height, .01));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.getSize(message).height, closeTo(initialSize.height, .01));
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        reply,
      );
      // There is only one message in the widget tree. A second invisible
      // RichText/EditableText caused ambiguous reactions and transcript tests.
      expect(find.text(reply), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full reply never pushes an adjacent feedback row while animating',
    (tester) async {
      final reply = List<String>.filled(
        12,
        'Detailed evidence based answer.',
      ).join(' ');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CoachMessageText(
                    key: const ValueKey('coach-feedback-anchor'),
                    text: reply,
                    createdAt: DateTime(2026, 10, 8),
                    textDirection: TextDirection.ltr,
                    animateReveal: true,
                    showTime: false,
                  ),
                  const SizedBox(
                    key: ValueKey('coach-fake-reactions'),
                    height: 48,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final feedback = find.byKey(const ValueKey('coach-fake-reactions'));
      final top = tester.getTopLeft(feedback).dy;
      for (final elapsed in [
        const Duration(milliseconds: 120),
        const Duration(milliseconds: 400),
        const Duration(milliseconds: 1500),
        const Duration(seconds: 2),
      ]) {
        await tester.pump(elapsed);
        expect(tester.getTopLeft(feedback).dy, closeTo(top, .01));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('joined emoji and combining scripts never reveal split graphemes', (
    tester,
  ) async {
    const reply =
        'العائلة 👨‍👩‍👧‍👦 والرياضة 🏃🏽‍♂️ — let us review the sleep report.';
    final completeClusters = reply.characters.toList(growable: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachMessageText(
            text: reply,
            createdAt: DateTime(2026, 10, 8),
            textDirection: TextDirection.rtl,
            animateReveal: true,
          ),
        ),
      ),
    );
    for (var step = 0; step < 12; step++) {
      await tester.pump(const Duration(milliseconds: 70));
      final visible = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(
        completeClusters.take(visible.characters.length).join(),
        visible,
        reason: 'The display must end on a complete grapheme at frame $step',
      );
    }
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      reply,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('recycled fresh reply does not restart its reveal', (
    tester,
  ) async {
    const reply = 'A reply that must remain complete after history scrolling.';
    final created = DateTime(2026, 9, 13, 11, 30);
    const key = ValueKey('coach-message-text-recycled');
    Future<void> pumpMessage() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachMessageText(
            key: key,
            text: reply,
            createdAt: created,
            textDirection: TextDirection.ltr,
            animateReveal: true,
          ),
        ),
      ),
    );

    await pumpMessage();
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      isNot(reply),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpMessage();
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      reply,
    );
  });
}
