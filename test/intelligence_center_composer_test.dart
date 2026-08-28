import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  AppDatabase database, {
  Locale locale = const Locale('en'),
  TextScaler? textScaler,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      coachContextSnapshotProvider.overrideWith(
        (ref) async => CoachContextSnapshot.empty(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const IntelligenceCenterPage(),
    ),
  );
}

void main() {
  Future<void> revealOlderMessage(WidgetTester tester, Finder target) async {
    for (var attempt = 0; attempt < 6 && target.evaluate().isEmpty; attempt++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, 320));
      await tester.pumpAndSettle();
    }
  }

  Future<AppDatabase> database(WidgetTester tester) async {
    final value = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(value.close);
    return value;
  }

  testWidgets('keyboard send submits text and renders the latest reply', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = await database(tester);
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    final fieldFinder = find.byKey(const Key('ai-coach-question-field'));
    final field = tester.widget<TextField>(fieldFinder);
    expect(field.textInputAction, TextInputAction.send);

    await tester.enterText(fieldFinder, 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsOneWidget);
    expect(find.textContaining('I am ready').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('restored technical failure is sanitized behind latest welcome', (
    tester,
  ) async {
    final db = await database(tester);
    final stored = <Map<String, Object?>>[
      for (var index = 0; index < 18; index++)
        {
          'id': 'old-$index',
          'role': 'user',
          'kind': 'freeQuestion',
          'text': 'رسالة $index',
          'createdAt': DateTime(2026, 8, 9, 12, index).toIso8601String(),
          'evidence': <String>[],
          'missingData': <String>[],
        },
      {
        'id': 'technical-error',
        'role': 'bil',
        'kind': 'safety',
        'text':
            'BIL did not expose an action because the safety boundary did not approve one. AI Context is not accepted.',
        'createdAt': DateTime(2026, 8, 9, 13).toIso8601String(),
        'evidence': <String>['local-coach-runtime'],
        'missingData': <String>[],
      },
    ];
    await PreferencesRepository(
      db,
    ).set('intelligenceConversationV1', jsonEncode(stored));

    await tester.pumpWidget(_app(db, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('BIL did not expose'), findsNothing);
    expect(find.textContaining('AI Context is not accepted'), findsNothing);
    expect(
      find.textContaining('جاهز لقرارك المفيد التالي').hitTestable(),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('every opened chat gets one non-persistent session welcome', (
    tester,
  ) async {
    final db = await database(tester);
    final repository = PreferencesRepository(db);
    await repository.set(
      'intelligenceConversationV1',
      jsonEncode([
        {
          'id': 'old-user-message',
          'role': 'user',
          'kind': 'freeQuestion',
          'text': 'Previous question',
          'createdAt': DateTime(2026, 8, 20).toIso8601String(),
          'evidence': <String>[],
          'missingData': <String>[],
        },
      ]),
    );

    await tester.pumpWidget(_app(db));
    await tester.pump();
    expect(
      find.textContaining('ready for your next useful decision'),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ready for your next useful decision'),
      findsOneWidget,
    );
    expect(
      await repository.get('intelligenceConversationV1'),
      contains('Previous question'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ready for your next useful decision'),
      findsOneWidget,
    );
    expect(
      await repository.get('intelligenceConversationV1'),
      contains('Previous question'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'legacy body answers without a matching context fingerprint are removed',
    (tester) async {
      final db = await database(tester);
      final repository = PreferencesRepository(db);
      await repository.set(
        'intelligenceConversationV1',
        jsonEncode([
          {
            'id': 'stale-question',
            'role': 'user',
            'kind': 'freeQuestion',
            'text': 'What is my weight trend?',
            'createdAt': DateTime(2030, 8, 20, 8).toIso8601String(),
            'evidence': <String>[],
            'missingData': <String>[],
          },
          {
            'id': 'stale-answer',
            'role': 'bil',
            'kind': 'coach',
            'text': 'Stale body answer',
            'createdAt': DateTime(2030, 8, 20, 8, 1).toIso8601String(),
            'evidence': <String>['local weight record'],
            'missingData': <String>[],
          },
        ]),
      );
      await WeightRepository(
        db,
      ).addWeight(89.2, date: DateTime(2026, 8, 20, 9));
      final imported = await WeightRepository(db).getAll();
      expect(imported, hasLength(1));

      await tester.pumpWidget(_app(db));
      await tester.pumpAndSettle();

      for (var attempt = 0; attempt < 30; attempt++) {
        final stored = await repository.get('intelligenceConversationV1');
        if (stored?.contains('stale-answer') != true) break;
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text('What is my weight trend?'), findsNothing);
      expect(find.text('Stale body answer'), findsNothing);
      expect(
        await repository.get('intelligenceConversationV1'),
        isNot(contains('stale-answer')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('session welcome stays visible after a tall restored history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = await database(tester);
    await PreferencesRepository(db).set(
      'intelligenceConversationV1',
      jsonEncode([
        for (var index = 0; index < 24; index++)
          {
            'id': 'history-$index',
            'role': index.isEven ? 'user' : 'bil',
            'kind': 'freeQuestion',
            'text':
                'Historic conversation turn $index with enough detail to make this bubble wrap across several lines on a phone viewport.',
            'createdAt': DateTime(2026, 8, 20, 8, index).toIso8601String(),
            'evidence': <String>[],
            'missingData': <String>[],
          },
      ]),
    );

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ready for your next useful decision').hitTestable(),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('voice transcript and answer remain readable in the chat', (
    tester,
  ) async {
    final db = await database(tester);
    await PreferencesRepository(db).set(
      'intelligenceConversationV1',
      jsonEncode([
        {
          'id': 'voice-user',
          'role': 'user',
          'kind': 'freeQuestion',
          'text': 'assalamualaikum',
          'createdAt': DateTime(2026, 8, 21, 10).toIso8601String(),
          'evidence': <String>[],
          'missingData': <String>[],
          'modality': 'voice',
        },
        {
          'id': 'voice-coach',
          'role': 'bil',
          'kind': 'coach',
          'text': 'وعليكم السلام. كيف أساعدك اليوم؟',
          'createdAt': DateTime(2026, 8, 21, 10, 1).toIso8601String(),
          'evidence': <String>[],
          'missingData': <String>[],
          'modality': 'voice',
        },
      ]),
    );

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await revealOlderMessage(tester, find.text('assalamualaikum'));

    expect(find.text('assalamualaikum'), findsOneWidget);
    expect(find.text('وعليكم السلام. كيف أساعدك اليوم؟'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('assalamualaikum')).textDirection,
      TextDirection.ltr,
    );
    expect(
      tester
          .widget<Text>(find.text('وعليكم السلام. كيف أساعدك اليوم؟'))
          .textDirection,
      TextDirection.rtl,
    );
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('single premium chat surface fits an Arabic phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = await database(tester);

    await tester.pumpWidget(_app(db, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(TabBarView), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('ai-coach-question-field')), findsOneWidget);
    expect(find.byKey(const Key('ai-coach-voice-button')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('AI answer report sheet works in RTL at 160% text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = await database(tester);
    await PreferencesRepository(db).set(
      'intelligenceConversationV1',
      jsonEncode([
        {
          'id': 'reportable-answer',
          'role': 'bil',
          'kind': 'coach',
          'text': 'إجابة قابلة للإبلاغ لاختبار واجهة الأمان.',
          'createdAt': DateTime(2026, 8, 24, 12).toIso8601String(),
          'evidence': <String>[],
          'missingData': <String>[],
        },
      ]),
    );

    await tester.pumpWidget(
      _app(
        db,
        locale: const Locale('ar'),
        textScaler: const TextScaler.linear(1.6),
      ),
    );
    await tester.pumpAndSettle();

    final report = find.byKey(const Key('ai-coach-report-reportable-answer'));
    await revealOlderMessage(tester, report);
    await tester.ensureVisible(report);
    await tester.tap(report);
    await tester.pumpAndSettle();

    final title = find.text('الإبلاغ عن إجابة الذكاء الاصطناعي؟');
    expect(title, findsOneWidget);
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
    expect(find.byKey(const Key('ai-coach-confirm-report')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('ai-coach-confirm-report')));
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
