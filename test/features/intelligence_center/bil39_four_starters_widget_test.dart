import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_health_brief_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_overview_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/coach_conversation_entry.dart';

final _now = DateTime(2026, 10, 25, 12);
final _snapshot = CoachContextSnapshot(
  generatedAt: _now,
  profile: const {'targetWeightKg': 79, 'displayName': 'Fixture member'},
  weights: [CoachWeightPoint(at: _now, kg: 81.5)],
  nutritionDays: const [],
  waterHistory: const [],
  computedHealth: const {
    'dailyTargets': {'caloriesKcal': 2103},
  },
);

class _RecordingGateway implements LocalModelGateway {
  _RecordingGateway(this.reply);
  final String reply;
  final questions = <String>[];
  final contexts = <CoachContextSnapshot>[];

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
    // A model may propose a screen. A review request must retain its answer
    // in this conversation and cannot be converted into automatic navigation.
    return LocalModelResult.answer(
      LocalModelAnswer(
        text: reply,
        processedOnDevice: false,
        action: const {
          'name': 'navigate',
          'arguments': {'target': 'daily_log'},
        },
        evidence: const ['fixture verified context'],
      ),
    );
  }
}

void main() {
  for (final arabic in [false, true]) {
    final labels = arabic
        ? ['راجع يومي', 'راجع التغذية', 'اشرح نومي', 'أفضل تركيز تالٍ']
        : [
            'Review my day',
            'Check nutrition',
            'Explain sleep',
            'Next best focus',
          ];
    for (final label in labels) {
      testWidgets('actual starter stays read-only in chat: $label', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(430, 932));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final reply = arabic
            ? 'هذه مراجعة تستند إلى سياقك الموثق، دون تغيير أي سجل.'
            : 'This review uses your verified context without changing a record.';
        final gateway = _RecordingGateway(reply);
        final router = GoRouter(
          initialLocation: '/intelligence-center',
          routes: [
            GoRoute(
              path: '/intelligence-center',
              builder: (_, _) => const IntelligenceCenterPage(),
            ),
            for (final path in [
              '/daily-log',
              '/smart-plan',
              '/goals',
              '/dashboard',
            ])
              GoRoute(
                path: path,
                builder: (_, _) =>
                    Scaffold(body: Text('UNEXPECTED ROUTE $path')),
              ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              intelligenceConversationClockProvider.overrideWithValue(
                () => _now,
              ),
              intelligenceCenterModelGatewayProvider.overrideWithValue(gateway),
              coachContextSnapshotProvider.overrideWith(
                (ref) async => _snapshot,
              ),
              coachHealthBriefProvider.overrideWith((ref) async => _snapshot),
              coachOverviewContextProvider.overrideWith(
                (ref) async => CoachOverviewContext(snapshot: _snapshot),
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
            child: MaterialApp.router(
              routerConfig: router,
              locale: Locale(arabic ? 'ar' : 'en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
          ),
        );
        await openCoachConversationFromOverview(tester);
        final button = find.widgetWithText(ActionChip, label);
        expect(button, findsOneWidget);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(button.hitTestable(), findsOneWidget);
        await tester.tap(button);
        for (var n = 0; n < 80 && gateway.questions.isEmpty; n++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(
          gateway.questions,
          hasLength(1),
          reason:
              'The actual button must reach the model path once, not Food or a plan.',
        );
        expect(gateway.contexts.single.profile['targetWeightKg'], 79);
        expect(gateway.contexts.single.weights.single.kg, 81.5);
        expect(gateway.contexts.single.computedHealth['dailyTargets'], {
          'caloriesKcal': 2103,
        });
        expect(
          router.routeInformationProvider.value.uri.path,
          '/intelligence-center',
        );
        expect(find.text(reply), findsOneWidget);
        expect(find.textContaining('UNEXPECTED ROUTE'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          expect(await db.select(db.weightEntries).get(), isEmpty);
          expect(await db.select(db.meals).get(), isEmpty);
          expect(await db.select(db.waterEntries).get(), isEmpty);
        });
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
