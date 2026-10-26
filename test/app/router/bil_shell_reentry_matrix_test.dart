import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:body_intelligence_log/app/router/bil_navigation_focus_observer.dart';
import 'package:body_intelligence_log/app/router/bil_primary_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// This is a real Navigator/GoRouter mechanism matrix using production shell
// composition. Content probes isolate navigation; the separate Meal Planner
// journey exercises actual destination widgets and data repositories.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final productionShell = AppRouter.router.configuration.routes
      .whereType<ShellRoute>()
      .single;
  final targets = productionShell.routes
      .whereType<GoRoute>()
      .map((route) => route.path)
      .toList();
  tearDownAll(() => AppRouter.router.dispose());

  for (final language in ['en', 'ar']) {
    for (final origin in ['/dashboard', '/intelligence-center', '/settings']) {
      for (final target in targets) {
        testWidgets('shell re-entry $origin -> root -> $target $language', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          Widget page(BuildContext context, String path) => Scaffold(
            key: ValueKey('matrix-page:$path'),
            body: SafeArea(
              child: Column(
                children: [
                  Text('Visible content: $path'),
                  TextButton(
                    key: const Key('matrix-open-root'),
                    onPressed: () => unawaited(context.push('/matrix-root-a')),
                    child: const Text('Open root feature'),
                  ),
                ],
              ),
            ),
          );
          final router = GoRouter(
            observers: [
              BilNavigationFocusObserver(),
              BilNavigationFocusObserver(),
            ],
            initialLocation: origin,
            routes: [
              ShellRoute(
                pageBuilder: productionShell.pageBuilder,
                routes: [
                  for (final path in targets)
                    GoRoute(
                      path: path,
                      pageBuilder: (context, state) => bilNoTransitionPage(
                        state: state,
                        child: page(context, path),
                      ),
                    ),
                ],
              ),
              for (final root in ['a', 'b'])
                GoRoute(
                  path: '/matrix-root-$root',
                  builder: (context, _) => Scaffold(
                    body: Center(
                      child: TextButton(
                        key: const Key('matrix-open-next'),
                        onPressed: () => unawaited(
                          context.push(root == 'a' ? '/matrix-root-b' : target),
                        ),
                        child: Text('Root feature $root'),
                      ),
                    ),
                  ),
                ),
            ],
          );
          try {
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp.router(
                  locale: Locale(language),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    ...GlobalMaterialLocalizations.delegates,
                  ],
                  theme: ThemeData(platform: TargetPlatform.iOS),
                  routerConfig: router,
                ),
              ),
            );
            await tester.pumpAndSettle();
            final originalElement = tester.element(
              find.byKey(ValueKey('matrix-page:$origin')),
            );
            for (var cycle = 0; cycle < 2; cycle++) {
              await tester.tap(find.byKey(const Key('matrix-open-root')));
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const Key('matrix-open-next')));
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const Key('matrix-open-next')));
              await tester.pumpAndSettle();
              final visiblePage = find.byKey(ValueKey('matrix-page:$target'));
              expect(visiblePage, findsOneWidget);
              expect(
                GoRouterState.of(tester.element(visiblePage)).uri.path,
                target,
              );
              final navigators = tester
                  .widgetList<Navigator>(
                    find.byType(Navigator, skipOffstage: false),
                  )
                  .toList();
              expect(
                navigators.map((navigator) => navigator.key).toSet().length,
                navigators.length,
                reason: 'Root and both shell instances need distinct keys.',
              );
              expect(find.byType(ErrorWidget), findsNothing);
              expect(tester.takeException(), isNull);
              router.pop();
              await tester.pumpAndSettle();
              expect(find.text('Root feature b'), findsOneWidget);
              router.pop();
              await tester.pumpAndSettle();
              expect(find.text('Root feature a'), findsOneWidget);
              router.pop();
              await tester.pumpAndSettle();
              expect(
                tester.element(find.byKey(ValueKey('matrix-page:$origin'))),
                same(originalElement),
                reason: 'Return preserves the original shell element.',
              );
            }
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            router.dispose();
          }
        });
      }
    }
  }
}
