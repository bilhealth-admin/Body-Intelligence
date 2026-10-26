import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:body_intelligence_log/shared/widgets/bil_reference_bottom_bar.dart';
import 'package:body_intelligence_log/app/router/responsive_app_shell.dart';
import 'package:body_intelligence_log/app/router/bil_primary_navigation.dart';
import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'primary and dashboard feature entries open without a side transition',
    () {
      void expectDirectRoute(String file, String path) {
        final source = File(file).readAsStringSync();
        final pathIndex = source.indexOf("path: '$path'");
        expect(pathIndex, isNot(-1), reason: '$path is declared in $file');
        final routeStart = source.lastIndexOf('GoRoute(', pathIndex);
        final nextRoute = source.indexOf('GoRoute(', pathIndex + path.length);
        final route = source.substring(
          routeStart,
          nextRoute < 0 ? source.length : nextRoute,
        );
        expect(route, contains('pageBuilder:'), reason: '$path uses a page');
        expect(
          route,
          contains('NoTransitionPage'),
          reason: '$path should reveal its splash immediately',
        );
      }

      for (final path in const [
        '/intelligence-center',
        '/nutrition-plans',
        '/settings',
      ]) {
        expectDirectRoute('lib/app/router/app_router.dart', path);
      }
      expectDirectRoute(
        'lib/app/router/app_community_routes.dart',
        '/community',
      );
      for (final path in const [
        '/wellness/sleep',
        '/wellness/workouts',
        '/wellness/workouts/routines',
        '/wellness/recipes',
      ]) {
        expectDirectRoute('lib/app/router/app_wellness_routes.dart', path);
      }
    },
  );

  for (final language in ['en', 'ar']) {
    for (final wide in [false, true]) {
      testWidgets(
        'primary navigation opens destinations and escapes details $language wide=$wide',
        (tester) async {
          tester.view.physicalSize = Size(wide ? 1200 : 390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final router = GoRouter(
            initialLocation: '/community',
            routes: [
              ShellRoute(
                pageBuilder: (_, state, child) => bilNoTransitionPage(
                  state: state,
                  child: ResponsiveAppShell(
                    currentUri: state.uri,
                    child: child,
                  ),
                ),
                routes: [
                  for (final path in {
                    ...ResponsiveAppShell.paths,
                    ...BilReferenceBottomBar.routes,
                  })
                    GoRoute(
                      path: path,
                      pageBuilder: (context, state) => bilNoTransitionPage(
                        state: state,
                        child: Scaffold(
                          key: ValueKey('dock-content:$path'),
                          body: Builder(
                            builder: (detailContext) {
                              void openDetail({bool guarded = false}) {
                                var canLeave = !guarded;
                                Navigator.of(detailContext).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => StatefulBuilder(
                                      builder: (_, update) => PopScope(
                                        canPop: canLeave,
                                        child: Scaffold(
                                          key: const Key('dock-legacy-detail'),
                                          body: TextButton(
                                            key: const Key('dock-release-save'),
                                            onPressed: () =>
                                                update(() => canLeave = true),
                                            child: const Text(
                                              'Finish pending save',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Column(
                                children: [
                                  TextButton(
                                    key: const Key('dock-open-legacy-detail'),
                                    onPressed: openDetail,
                                    child: Text(path),
                                  ),
                                  TextButton(
                                    key: const Key('dock-open-guarded-detail'),
                                    onPressed: () => openDetail(guarded: true),
                                    child: const Text('Open pending save'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
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
            Finder action(int index) => wide
                ? find
                      .descendant(
                        of: find.byKey(const Key('glass-top-navigation')),
                        matching: find.byType(InkWell),
                      )
                      .at(
                        index + 1,
                      ) // Profile is the first actual top-bar item.
                : find.byKey(Key('bil-reference-nav-$index'));
            if (wide) {
              expect(
                find.descendant(
                  of: find.byKey(const Key('glass-top-navigation')),
                  matching: find.byType(InkWell),
                ),
                findsNWidgets(7),
              );
            } else {
              for (var i = 0; i < 5; i++) {
                expect(find.byKey(Key('bil-reference-nav-$i')), findsOneWidget);
              }
            }
            for (final index
                in wide ? [0, 1, 2, 3, 4, 5, 5] : [0, 1, 3, 4, 4]) {
              router.go('/community');
              await tester.pumpAndSettle();
              final target = wide
                  ? ResponsiveAppShell.paths[index]
                  : BilReferenceBottomBar.routes[index];
              await tester.tap(action(index));
              await tester.pump();
              final visible = find.byKey(ValueKey('dock-content:$target'));
              expect(
                visible,
                findsOneWidget,
                reason:
                    'Direct selection must not await a page-slide animation.',
              );
              expect(
                GoRouterState.of(tester.element(visible)).uri.path,
                target,
              );
              await tester.pumpAndSettle();
              // The real Coach destination owns its immersive dock inside its
              // page. Use Community's outer dock for the nested-detail escape,
              // matching the user's profile reproduction.
              router.go(
                target == '/intelligence-center' ? '/community' : target,
              );
              await tester.pumpAndSettle();
              await tester.tap(
                find.byKey(const Key('dock-open-legacy-detail')),
              );
              await tester.pumpAndSettle();
              expect(
                find.byKey(const Key('dock-legacy-detail')),
                findsOneWidget,
              );
              await tester.tap(action(index));
              await tester.pumpAndSettle();
              expect(visible, findsOneWidget);
              expect(find.byKey(const Key('dock-legacy-detail')), findsNothing);
              expect(tester.takeException(), isNull);
            }
            router.go('/settings');
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('dock-open-guarded-detail')));
            await tester.pumpAndSettle();
            final moreIndex = wide ? 5 : 4;
            await tester.tap(action(moreIndex));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('dock-legacy-detail')),
              findsOneWidget,
              reason: 'Primary selection must honor an active save veto.',
            );
            await tester.tap(find.byKey(const Key('dock-release-save')));
            await tester.pumpAndSettle();
            await tester.tap(action(moreIndex));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('dock-legacy-detail')), findsNothing);
            expect(
              find.byKey(const ValueKey('dock-content:/settings')),
              findsOneWidget,
            );
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            router.dispose();
          }
        },
      );
    }
  }
}
