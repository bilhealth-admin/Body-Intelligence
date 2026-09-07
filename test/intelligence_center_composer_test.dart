import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  AppDatabase database, {
  Locale locale = const Locale('en'),
  TextScaler? textScaler,
  EdgeInsets viewInsets = EdgeInsets.zero,
  PreferencesRepository? preferences,
  WeightRepository? weightRepository,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      if (preferences != null)
        preferencesRepositoryProvider.overrideWithValue(preferences),
      if (weightRepository != null)
        weightRepositoryProvider.overrideWithValue(weightRepository),
      coachContextSnapshotProvider.overrideWith(
        (ref) async => CoachContextSnapshot.empty(),
      ),
      intelligenceHealthContextProvider.overrideWith(
        (ref) async => const IntelligenceHealthContext(
          primaryMessage: '',
          explanation: [],
          confidence: 1,
          evidence: [],
          missingData: [],
        ),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      builder: textScaler == null && viewInsets == EdgeInsets.zero
          ? null
          : (context, child) {
              var data = MediaQuery.of(context);
              if (textScaler != null) {
                data = data.copyWith(textScaler: textScaler);
              }
              if (viewInsets != EdgeInsets.zero) {
                data = data.copyWith(viewInsets: viewInsets);
              }
              return MediaQuery(data: data, child: child!);
            },
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
      await tester.drag(find.byType(ListView).last, const Offset(0, -320));
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

  testWidgets(
    'conversation input stays locked until the stored transcript is restored',
    (tester) async {
      final db = await database(tester);
      final repository = PreferencesRepository(db);
      await repository.setMany({
        'intelligenceConversationV1': jsonEncode([
          {
            'id': 'saved-before-startup',
            'role': 'user',
            'kind': 'freeQuestion',
            'text': 'Saved before startup',
            'createdAt': DateTime.utc(2026, 9, 4, 8).toIso8601String(),
            'evidence': <String>[],
            'missingData': <String>[],
          },
        ]),
        'intelligenceConversationActiveIdV1': 'existing-chat',
      });
      final delayed = _DelayedConversationPreferences(db);

      await tester.pumpWidget(_app(db, preferences: delayed));
      await tester.pump();
      expect(delayed.conversationReadStarted, isTrue);
      expect(
        find.byKey(const Key('ai-coach-conversation-restoring')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-coach-question-field')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('ai-coach-hero-start')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('ai-coach-food-image-button')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('ai-coach-voice-button')))
            .onPressed,
        isNull,
      );

      delayed.releaseConversationRead();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ai-coach-conversation-restoring')),
        findsNothing,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-coach-question-field')))
            .enabled,
        isTrue,
      );
      expect(find.text('Saved before startup'), findsOneWidget);

      final field = find.byKey(const Key('ai-coach-question-field'));
      await tester.enterText(field, 'hello after restore');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        final stored = await repository.get('intelligenceConversationV1');
        if (stored?.contains('hello after restore') == true) break;
      }
      expect(
        await repository.get('intelligenceConversationV1'),
        allOf(
          contains('Saved before startup'),
          contains('hello after restore'),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('a queued turn save survives immediate route disposal', (
    tester,
  ) async {
    final db = await database(tester);
    final repository = PreferencesRepository(db);
    final delayedWeights = _DelayedWeightRepository(db);
    await tester.pumpWidget(_app(db, weightRepository: delayedWeights));
    await tester.pumpAndSettle();

    delayedWeights.blockNextRead();
    final field = find.byKey(const Key('ai-coach-question-field'));
    await tester.enterText(field, 'Keep this turn after navigation');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump();
      if (delayedWeights.readBlocked) break;
    }
    expect(delayedWeights.readBlocked, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    delayedWeights.releaseRead();
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      final stored = await repository.get('intelligenceConversationV1');
      if (stored?.contains('Keep this turn after navigation') == true) break;
    }

    expect(
      await repository.get('intelligenceConversationV1'),
      contains('Keep this turn after navigation'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('compact hero and one-line composer remain above the keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = await database(tester);

    await tester.pumpWidget(
      _app(db, viewInsets: const EdgeInsets.only(bottom: 300)),
    );
    await tester.pumpAndSettle();

    final fieldFinder = find.byKey(const Key('ai-coach-question-field'));
    final field = tester.widget<TextField>(fieldFinder);
    expect(field.minLines, 1);
    expect(field.maxLines, 1);
    expect(find.text('Your BIL Coach'), findsOneWidget);
    expect(find.text('Speak your language'), findsOneWidget);
    expect(find.byKey(const Key('ai-coach-hero-start')), findsOneWidget);
    expect(tester.getBottomLeft(fieldFinder).dy, lessThanOrEqualTo(544));
    expect(fieldFinder.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

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
    'legacy conversation is preserved when the health context changes',
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

      await revealOlderMessage(tester, find.text('What is my weight trend?'));
      expect(find.text('What is my weight trend?'), findsOneWidget);
      expect(find.text('Stale body answer'), findsOneWidget);
      expect(
        await repository.get('intelligenceConversationV1'),
        allOf(contains('stale-question'), contains('stale-answer')),
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

  testWidgets(
    'confirmed coach target-weight action updates profile and active goal',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = await database(tester);
      await UserProfileRepository(db).save(
        gender: 'male',
        age: 35,
        height: 180,
        currentWeight: 87.4,
        targetWeight: 90,
        activityLevel: 'moderate',
        exercises: true,
      );

      await tester.pumpWidget(_app(db));
      await tester.pumpAndSettle();

      final field = find.byKey(const Key('ai-coach-question-field'));
      await tester.enterText(field, 'Set my target weight to 79 kg');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      // The request intentionally remains active while its action sheet is
      // open, so use bounded pumps instead of waiting for zero animations.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The durable message chip and the initially opened action sheet both
      // intentionally retain the proposal. Target the sheet row explicitly.
      final proposedAction = find.byKey(
        const Key('ai-coach-action-sheet-updateGoal-update-goal-79.0'),
      );
      expect(proposedAction, findsOneWidget);
      await tester.tap(proposedAction);
      await tester.pumpAndSettle();

      expect(find.text('Confirm action'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        if ((await UserProfileRepository(db).getProfile())?.targetWeight ==
            79) {
          break;
        }
      }

      expect((await UserProfileRepository(db).getProfile())?.targetWeight, 79);
      expect((await GoalRepository(db).getActive())?.targetWeight, 79);
      expect(
        find.textContaining('Target weight updated to 79.0 kg'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

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
    await Scrollable.ensureVisible(tester.element(report), alignment: .5);
    await tester.pump();
    expect(report.hitTestable(), findsOneWidget);
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

final class _DelayedConversationPreferences extends PreferencesRepository {
  _DelayedConversationPreferences(super.database);

  final Completer<void> _conversationRead = Completer<void>();
  bool conversationReadStarted = false;

  void releaseConversationRead() {
    if (!_conversationRead.isCompleted) _conversationRead.complete();
  }

  @override
  Future<String?> get(String key) async {
    if (key == 'intelligenceConversationV1' && !_conversationRead.isCompleted) {
      conversationReadStarted = true;
      await _conversationRead.future;
    }
    return super.get(key);
  }
}

final class _DelayedWeightRepository extends WeightRepository {
  _DelayedWeightRepository(super.database);

  Completer<void>? _nextRead;
  Completer<void>? _activeRead;

  bool get readBlocked =>
      _activeRead != null && _activeRead!.isCompleted == false;

  void blockNextRead() {
    _nextRead = Completer<void>();
  }

  void releaseRead() {
    final active = _activeRead;
    if (active != null && !active.isCompleted) active.complete();
  }

  @override
  Future<List<WeightEntry>> getAll() async {
    final gate = _nextRead;
    _nextRead = null;
    if (gate != null) {
      _activeRead = gate;
      await gate.future;
    }
    return super.getAll();
  }
}
