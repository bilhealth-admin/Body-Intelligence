import 'dart:convert';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_health_context_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('restored coach action chip opens its allow-listed route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final action = IntelligenceMessageAction.fromAction(
      const IntelligenceAction(
        id: 'open-goals',
        type: IntelligenceActionType.navigate,
        label: 'Open goals',
        requiresConfirmation: false,
        payload: <String, Object?>{'target': 'goals'},
      ),
    )!;
    final message = IntelligenceMessage(
      id: 'coach-route-answer',
      role: IntelligenceMessageRole.bil,
      kind: IntelligenceMessageKind.coach,
      text: 'Your goal settings are ready to review.',
      createdAt: DateTime.utc(2026, 9, 4),
      actionLinks: <IntelligenceMessageAction>[action],
    );
    await PreferencesRepository(database).set(
      'intelligenceConversationV1',
      jsonEncode(<Object?>[message.toJson()]),
    );

    final router = GoRouter(
      initialLocation: '/intelligence-center',
      routes: <RouteBase>[
        GoRoute(
          path: '/intelligence-center',
          builder: (_, _) => const IntelligenceCenterPage(),
        ),
        GoRoute(
          path: '/goals',
          builder: (_, _) => const Scaffold(body: Text('Goals destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          coachContextSnapshotProvider.overrideWith(
            (ref) async => CoachContextSnapshot.empty(),
          ),
          intelligenceHealthContextProvider.overrideWith(
            (ref) async => const IntelligenceHealthContext(
              primaryMessage: '',
              explanation: <String>[],
              confidence: 1,
              evidence: <String>[],
              missingData: <String>[],
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chip = find.byKey(const Key('ai-coach-action-navigate-open-goals'));
    expect(chip, findsOneWidget);
    await Scrollable.ensureVisible(tester.element(chip), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text('Goals destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'confirmed account deletion action opens the dedicated deletion flow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final router = GoRouter(
        initialLocation: '/intelligence-center',
        routes: <RouteBase>[
          GoRoute(
            path: '/intelligence-center',
            builder: (_, _) => const IntelligenceCenterPage(),
          ),
          GoRoute(
            path: '/help/delete-account',
            builder: (_, _) =>
                const Scaffold(body: Text('Account deletion destination')),
          ),
          GoRoute(
            path: '/community/profile',
            builder: (_, _) =>
                const Scaffold(body: Text('Community profile destination')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            coachContextSnapshotProvider.overrideWith(
              (ref) async => CoachContextSnapshot.empty(),
            ),
            intelligenceHealthContextProvider.overrideWith(
              (ref) async => const IntelligenceHealthContext(
                primaryMessage: '',
                explanation: <String>[],
                confidence: 1,
                evidence: <String>[],
                missingData: <String>[],
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai-coach-question-field')),
        'Delete my account',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai-coach-send-button')));
      final action = find.byKey(
        const Key(
          'ai-coach-action-sheet-requestAccountDeletion-request-account-deletion',
        ),
      );
      for (
        var attempt = 0;
        attempt < 30 && action.evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(action, findsOneWidget);
      await Scrollable.ensureVisible(tester.element(action), alignment: .5);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(action);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField).last, 'DELETE');
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Account deletion destination'), findsOneWidget);
      expect(find.text('Community profile destination'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
