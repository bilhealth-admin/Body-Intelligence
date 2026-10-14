import 'dart:io';
import 'dart:ui' as ui;
import 'package:body_intelligence_log/app/theme/bil_pearl_finish.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_copy.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_message_nutrition_reader.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_meal_read_parser.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_verified_message_projection.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/health_query_adapter.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_message_presentation.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_presentation_view.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/coach_message_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../qa_next/feature_splashes_test_support.dart'
    show closeFeatureSplashDatabase;
import '../../visual_closure/visual_evidence_font.dart';
import 'coach_message_presentation_view_test.dart' as scene;
import 'support/coach_message_presentation_fixture.dart';

void main() {
  setUpAll(loadVisualEvidenceFont);
  for (final arabic in [false, true]) {
    for (final style in ['text', 'meal', 'day', 'comparison', 'weight']) {
      testWidgets(
        'actual Flutter synthetic assistant $style ${arabic ? 'AR light' : 'EN dark'}',
        (tester) async {
          final database = await openMessagePresentationDatabase(tester);
          final key = GlobalKey();
          CoachMessagePresentation? visual;
          try {
            await tester.runAsync(() async {
              await seedMessageFood(database);
              await seedMessageFood(
                database,
                operation: 'capture-dinner',
                meal: 'dinner',
                estimated: true,
              );
              final reader = CoachMessageNutritionReader(
                database,
                clock: () => presentationFixtureClock,
              );
              switch (style) {
                case 'meal':
                  visual = await reader.readMeals(
                    CoachMealReadRequest([
                      CoachMealReadColumnRequest(
                        presentationFixtureDay,
                        'lunch',
                      ),
                    ]),
                    checkAccess: () {},
                  );
                case 'day':
                  visual = await reader.readDay(
                    presentationFixtureDay,
                    checkAccess: () {},
                  );
                case 'comparison':
                  visual = await reader.readMeals(
                    CoachMealReadRequest([
                      CoachMealReadColumnRequest(
                        presentationFixtureDay,
                        'lunch',
                      ),
                      CoachMealReadColumnRequest(
                        presentationFixtureDay,
                        'dinner',
                      ),
                    ]),
                    checkAccess: () {},
                  );
                case 'weight':
                  final weights = WeightRepository(database);
                  await weights.addWeight(
                    81.4,
                    date: DateTime.utc(2026, 10, 1, 9),
                  );
                  await weights.addWeight(
                    81.7,
                    date: DateTime.utc(2026, 10, 2, 9),
                  );
                  await weights.addWeight(
                    81.5,
                    date: DateTime.utc(2026, 10, 31, 9),
                  );
                  final result =
                      await CoachHealthQueries(
                        database,
                        clock: () => DateTime.utc(2026, 10, 31, 12),
                      ).execute(
                        topic: 'progress',
                        from: DateTime(2026, 10, 1),
                        through: DateTime(2026, 10, 31),
                        checkAccess: () {},
                      );
                  visual =
                      await CoachVerifiedMessageProjection(
                        database,
                        clock: () => DateTime.utc(2026, 10, 31, 12),
                      ).health(
                        result,
                        checkAccess: () {},
                        notes: CoachHealthCopy(
                          arabic ? 'ar' : 'en',
                        ).readAnnotations(result),
                      );
                case 'text':
                  break;
              }
            });
            await scene.mountMessageBody(
              tester,
              (context) => RepaintBoundary(
                key: key,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BilPearlFinish.panel(
                    context,
                    radius: BorderRadius.circular(18),
                    shadow: false,
                  ),
                  child: CoachMessageBody(
                    text: arabic
                        ? 'خطوة بسيطة اليوم تكفي. اختر ما يناسب وقتك.'
                        : 'One small step is enough today. Choose what fits your time.',
                    archive: null,
                    presentation: visual,
                    expectedOwnerKey: presentationFixtureOwnerKey,
                    ownerVisitIsCurrent: () => true,
                    textBuilder: (text) => CoachMessageText(
                      textDirection: arabic
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      text: text,
                      createdAt: presentationFixtureClock,
                      showTime: false,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.55),
                    ),
                  ),
                ),
              ),
              arabic: arabic,
              dark: !arabic,
              width: style == 'comparison' ? 760 : 390,
            );
            expect(tester.takeException(), isNull);
            final directory = Directory(
              Platform.environment['BIL_COACH_MESSAGE_CAPTURE_DIR'] ??
                  'build/stage1-closure/live-ai-coach-vision-20261013/message-captures',
            );
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            debugPrint('BIL_MESSAGE_CAPTURE stage=before_image style=$style');
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await directory.create(recursive: true);
                await File(
                  '${directory.path}/${style}_${arabic ? 'ar_light' : 'en_dark'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
            debugPrint('BIL_MESSAGE_CAPTURE stage=after_image style=$style');
          } finally {
            debugPrint('BIL_MESSAGE_CAPTURE stage=before_unmount style=$style');
            await tester.pumpWidget(const SizedBox.shrink());
            debugPrint('BIL_MESSAGE_CAPTURE stage=after_unmount style=$style');
            await closeFeatureSplashDatabase(tester, database);
            debugPrint('BIL_MESSAGE_CAPTURE stage=after_close style=$style');
          }
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    }
  }
}
