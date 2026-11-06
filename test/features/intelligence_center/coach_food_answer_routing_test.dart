import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/workspace/coach_food_review_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

// Use the real page, query flow, food host and model API. Only the gateway and
// owner-scoped in-memory database are synthetic. Installed catalog storage is
// an empty temporary directory; no production call or user storage read occurs.
import 'coach_food_semantic_admission_test.dart' show factualMarkdownRequest;
import 'coach_review_actions_regression_test.dart' as scene;

void main() {
  const tts = MethodChannel('bil/tts');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tts, (call) async {
          expect(
            call.method,
            'stop',
            reason: 'Text-only routing must not synthesize or resend a reply',
          );
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tts, null);
  });
  for (final request in const [
    factualMarkdownRequest,
    'Add a brief Arabic translation.',
    'Explain how to log rice and add a brief Arabic translation.',
    'Record a short definition of a fact versus an opinion.',
    'اشرح الفرق بين الحقيقة والرأي. أضف ترجمة إنجليزية قصيرة.',
    'أضف ترجمة عربية مختصرة.',
    'Only answer: Explain what log and record mean. Add an Arabic translation.',
    'Add a workout scheduled for tomorrow',
  ]) {
    testWidgets('food purpose reaches the normal answer gateway: $request', (
      tester,
    ) async {
      final supportDirectory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('bil-answer-routing-'),
      ))!;
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _EmptyCatalogPaths(supportDirectory.path);
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'answer-routing-owner',
      );
      final gateway = scene.Gateway();
      try {
        await scene.mount(tester, database, gateway: gateway);
        // The real composer shows Voice for an empty draft and Send only
        // after text entry. Exercise that transition before checking its gate.
        expect(find.byKey(const Key('ai-coach-voice-button')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('ai-coach-question-field')),
          request,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pump();
        await scene.waitForCoachReady(tester, send: true);
        await tester.tap(find.byKey(const Key('ai-coach-send-button')));
        for (var attempt = 0; attempt < 100; attempt++) {
          // Workout topics consult the real bundled approval registry and
          // installed-pack filesystem before falling back to the model.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 100));
          if (find.text('Local diagnostic reply.').evaluate().isNotEmpty ||
              find.text('رد اختباري محلي.').evaluate().isNotEmpty) {
            break;
          }
        }
        expect(gateway.questions, hasLength(1));
        expect(gateway.questions.single, request.toLowerCase());
        expect(
          find.text('Local diagnostic reply.').evaluate().length +
              find.text('رد اختباري محلي.').evaluate().length,
          1,
        );
        expect(find.byType(CoachFoodReviewCard), findsNothing);
        expect(
          find.textContaining('How much ', findRichText: true),
          findsNothing,
        );
        expect(await database.select(database.meals).get(), isEmpty);
        expect(await database.select(database.mealItems).get(), isEmpty);
        expect(await database.select(database.weightEntries).get(), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        try {
          await scene.unmount(tester);
          await tester.runAsync(() async {
            await database.close();
            final packs = Directory(
              '${supportDirectory.path}${Platform.pathSeparator}wellness_packs',
            );
            if (await packs.exists()) await packs.delete();
            await supportDirectory.delete();
          });
        } finally {
          PathProviderPlatform.instance = previousPaths;
        }
      }
    });
  }
}

class _EmptyCatalogPaths extends PathProviderPlatform {
  _EmptyCatalogPaths(this.directory);
  final String directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}
