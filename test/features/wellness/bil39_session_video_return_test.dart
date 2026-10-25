import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/wellness/domain/wellness_content_pack.dart';
import 'package:body_intelligence_log/features/wellness/presentation/bil_workout_routines_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _previewKey =
    'home-training:home-bodyweight-air-squat-standard-7s-original';

final _preview = WellnessContentItem(
  id: 'home-bodyweight-air-squat-standard-7s-original',
  type: WellnessContentType.workouts,
  locale: 'en',
  title: 'Verified movement fixture',
  description: 'Synthetic navigation data, never a workout instruction.',
  publisher: 'BIL QA',
  sourceUrl: Uri.parse('https://example.invalid/synthetic-workout'),
  licenseName: 'Synthetic fixture',
  verified: true,
  durationMinutes: 7,
  category: 'Strength',
  releaseBundleId: 'home-training',
  releaseKey: _previewKey,
);

String _movementRoute({required bool fromSession, String? id}) =>
    '/wellness/workouts/routines?item=${Uri.encodeQueryComponent(id ?? _previewKey)}&returnToSession=${fromSession ? 1 : 0}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('BIL-10 live session returns directly after movement details', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.byKey(const Key('fixture-start-session')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fixture-session-progress')), findsOneWidget);

    await tester.tap(find.byKey(const Key('fixture-open-movement')));
    await tester.pumpAndSettle();
    expect(find.byType(BilWorkoutRoutineDetailsPage), findsOneWidget);
    expect(find.text('Verified movement fixture'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fixture-session-progress')), findsOneWidget);
    expect(find.byType(BilWorkoutRoutinesPage), findsNothing);
    expect(find.byType(BilWorkoutRoutineDetailsPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BIL-10 ordinary discovery retains the library after details', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.byKey(const Key('fixture-open-library')));
    await tester.pumpAndSettle();
    expect(find.byType(BilWorkoutRoutineDetailsPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(BilWorkoutRoutinesPage), findsOneWidget);
    expect(find.byType(BilWorkoutRoutineDetailsPage), findsNothing);
  });

  testWidgets('BIL-10 cold session-flag link cannot pop a missing caller', (
    tester,
  ) async {
    await _mount(tester, initialLocation: _movementRoute(fromSession: true));
    expect(find.byType(BilWorkoutRoutineDetailsPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(BilWorkoutRoutinesPage), findsOneWidget);
    expect(find.byType(BilWorkoutRoutineDetailsPage), findsNothing);
  });

  testWidgets('BIL-10 unrecognized movement does not navigate or log', (
    tester,
  ) async {
    await _mount(
      tester,
      initialLocation: _movementRoute(
        fromSession: true,
        id: 'unknown-and-untrusted-item',
      ),
    );
    expect(find.byType(BilWorkoutRoutinesPage), findsOneWidget);
    expect(find.byType(BilWorkoutRoutineDetailsPage), findsNothing);
    expect(find.text('Verified movement fixture'), findsOneWidget);
  });
}

Future<GoRouter> _mount(
  WidgetTester tester, {
  String initialLocation = '/smart-plan',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/smart-plan',
        builder: (planContext, state) => Scaffold(
          appBar: AppBar(title: const Text('Plan fixture')),
          body: Column(
            children: [
              FilledButton(
                key: const Key('fixture-start-session'),
                onPressed: () {
                  Navigator.of(planContext).push<void>(
                    MaterialPageRoute<void>(
                      builder: (sessionContext) => Scaffold(
                        appBar: AppBar(title: const Text('Session fixture')),
                        body: Column(
                          children: [
                            const Text(
                              'Preserved step 2 of 5',
                              key: Key('fixture-session-progress'),
                            ),
                            FilledButton(
                              key: const Key('fixture-open-movement'),
                              onPressed: () => planContext.push(
                                _movementRoute(fromSession: true),
                              ),
                              child: const Text('View verified movement'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Start session'),
              ),
              FilledButton(
                key: const Key('fixture-open-library'),
                onPressed: () =>
                    planContext.push(_movementRoute(fromSession: false)),
                child: const Text('Browse movement'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/wellness/workouts/routines',
        pageBuilder: (context, state) => NoTransitionPage(
          child: BilWorkoutRoutinesPage(
            loader: (locale) async => [_preview],
            offline: true,
            initialItemId: state.uri.queryParameters['item'],
            returnToCallerAfterInitialItem:
                state.uri.queryParameters['returnToSession'] == '1',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        verifiedSubscriptionStateProvider.overrideWith(
          (ref) async => FreePlan.createState(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
