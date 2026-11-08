import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coach_review_actions_regression_test.dart' as scene;
import 'coach_weight_concept_routing_test.dart'
    show physical42WeightConceptQuestion;

const _table =
    '## الهدف والقياس\n\n'
    '| المفهوم | المعنى |\n|---|---|\n'
    '| الوزن المستهدف | هدف مستقبلي يختاره المستخدم |\n'
    '| الوزن المقاس | ملاحظة فعلية من الميزان بتاريخ معلوم |';

class _ConceptGateway extends scene.Gateway {
  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    questions.add(question);
    contexts.add(context);
    return const LocalModelResult.answer(
      LocalModelAnswer(
        text: _table,
        // Even a remote unsolicited write cannot override this turn's veto.
        action: {
          'name': 'log_weight',
          'arguments': {'weightKg': 60},
        },
      ),
    );
  }
}

void _registerRecordedWeightReadTests() {
  for (final request in const [
    'Show my recorded weight in a table.',
    'اشرح تطور وزني بجدول',
  ]) {
    testWidgets(
      'recorded-weight read retains its actual local owner: $request',
      (tester) async {
        final database = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'weight-history-read-owner',
        );
        final weights = WeightRepository(database);
        await weights.addWeight(82, date: DateTime(2026, 10, 25));
        await weights.addWeight(80, date: DateTime(2026, 10, 30));
        final before = await database.select(database.weightEntries).get();
        final gateway = _ConceptGateway();
        final snapshot = CoachContextSnapshot(
          generatedAt: DateTime(2026, 11, 8),
          profile: const {'targetWeightKg': 60},
          weights: [
            CoachWeightPoint(at: DateTime(2026, 10, 25), kg: 82),
            CoachWeightPoint(at: DateTime(2026, 10, 30), kg: 80),
          ],
          weightReadStatus: CoachWeightReadStatus.verified,
          nutritionDays: const [],
          waterHistory: const [],
          computedHealth: const {},
        );
        try {
          await scene.mount(
            tester,
            database,
            gateway: gateway,
            snapshot: snapshot,
            arabic: true,
          );
          await tester.enterText(
            find.byKey(const Key('ai-coach-question-field')),
            request,
          );
          FocusManager.instance.primaryFocus?.unfocus();
          tester.testTextInput.hide();
          await tester.pump();
          await scene.waitForCoachReady(tester, send: true);
          await tester.tap(find.byKey(const Key('ai-coach-send-button')));
          for (var n = 0; n < 80; n++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 20));
            if (tester
                .widgetList<CoachMessageText>(find.byType(CoachMessageText))
                .any((body) => body.text.contains('82.0'))) {
              break;
            }
          }
          await tester.pumpAndSettle();
          final replies = tester.widgetList<CoachMessageText>(
            find.byType(CoachMessageText),
          );
          expect(gateway.questions, isEmpty);
          expect(
            replies.where(
              (body) =>
                  body.text.contains('82.0') &&
                  body.text.contains('80.0') &&
                  body.text.contains('2026-10-25') &&
                  body.text.contains('2026-10-30'),
            ),
            hasLength(1),
          );
          expect(await database.select(database.weightEntries).get(), before);
          expect(tester.takeException(), isNull);
        } finally {
          await scene.unmount(tester);
          await tester.runAsync(database.close);
        }
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tts = MethodChannel('bil/tts');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tts, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tts, null);
  });
  _registerRecordedWeightReadTests();
  for (final request in const [
    physical42WeightConceptQuestion,
    'اشرح الفرق بين الوزن المستهدف والوزن المقاس في جدول قصير دون تعديل بياناتي.',
  ]) {
    testWidgets(
      'actual composer routes a weight definition to its answer: $request',
      (tester) async {
        final database = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: 'weight-concept-routing-owner',
        );
        final weights = WeightRepository(database);
        await weights.addWeight(82, date: DateTime(2026, 10, 25));
        await weights.addWeight(80, date: DateTime(2026, 10, 30));
        final before = await database.select(database.weightEntries).get();
        final gateway = _ConceptGateway();
        final snapshot = CoachContextSnapshot(
          generatedAt: DateTime(2026, 11, 8),
          profile: const {'targetWeightKg': 60},
          weights: [
            CoachWeightPoint(at: DateTime(2026, 10, 25), kg: 82),
            CoachWeightPoint(at: DateTime(2026, 10, 30), kg: 80),
          ],
          weightReadStatus: CoachWeightReadStatus.verified,
          nutritionDays: const [],
          waterHistory: const [],
          computedHealth: const {},
        );
        try {
          final router = await scene.mount(
            tester,
            database,
            gateway: gateway,
            snapshot: snapshot,
            arabic: true,
          );
          await tester.enterText(
            find.byKey(const Key('ai-coach-question-field')),
            request,
          );
          FocusManager.instance.primaryFocus?.unfocus();
          tester.testTextInput.hide();
          await tester.pump();
          await scene.waitForCoachReady(tester, send: true);
          await tester.tap(find.byKey(const Key('ai-coach-send-button')));
          for (var n = 0; n < 100 && gateway.questions.isEmpty; n++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 20));
          }
          await tester.pumpAndSettle();
          // Production normalization can lower case / add its existing Arabic
          // weight marker, but cannot replace the question with a history read.
          expect(gateway.questions, hasLength(1));
          expect(gateway.questions.single, contains(request.toLowerCase()));
          expect(gateway.contexts.single.weights, isEmpty);
          expect(gateway.contexts.single.profile, isEmpty);
          expect(
            router.routeInformationProvider.value.uri.path,
            '/intelligence-center',
          );
          final bodies = tester.widgetList<CoachMessageText>(
            find.byType(CoachMessageText),
          );
          expect(bodies.where((body) => body.text == _table), hasLength(1));
          expect(find.text(_table), findsOneWidget);
          expect(find.textContaining('راجعت 2 قياسات'), findsNothing);
          expect(find.textContaining('تحديث الوزن المستهدف'), findsNothing);
          expect(await database.select(database.weightEntries).get(), before);
          expect(await database.select(database.meals).get(), isEmpty);
          expect(await database.select(database.waterEntries).get(), isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await scene.unmount(tester);
          await tester.runAsync(database.close);
        }
      },
    );
  }
}
