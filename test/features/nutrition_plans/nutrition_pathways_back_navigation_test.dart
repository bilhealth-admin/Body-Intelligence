import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/nutrition_plans/presentation/nutrition_pathways_page.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget app(GoRouter router) => ProviderScope(
    overrides: [
      activeNutritionPathwayProvider.overrideWithValue(const AsyncData(null)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );

  testWidgets('back returns to the page that opened Nutrition pathways', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/source',
      routes: [
        GoRoute(
          path: '/source',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/nutrition-plans'),
              child: const Text('Open pathways'),
            ),
          ),
        ),
        GoRoute(
          path: '/nutrition-plans',
          builder: (_, _) => const NutritionPathwaysPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open pathways'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nutrition-pathways-back')));
    await tester.pumpAndSettle();

    expect(find.text('Open pathways'), findsOneWidget);
    expect(find.byType(NutritionPathwaysPage), findsNothing);
  });

  testWidgets('back falls back to Today when no route is behind the page', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/nutrition-plans',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('Today fallback')),
        ),
        GoRoute(
          path: '/nutrition-plans',
          builder: (_, _) => const NutritionPathwaysPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nutrition-pathways-back')));
    await tester.pumpAndSettle();

    expect(find.text('Today fallback'), findsOneWidget);
    expect(find.byType(NutritionPathwaysPage), findsNothing);
  });
}
