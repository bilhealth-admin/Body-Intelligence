import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/production_no_transition_route.dart';

void main() {
  testWidgets('startup and first dashboard entry cannot animate side by side', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox(key: Key('route-factory-host'))),
    );
    final startup = expectProductionNoTransitionRoute(tester, '/startup');
    final dashboard = expectProductionNoTransitionRoute(tester, '/dashboard');
    expect(startup.key, isNot(dashboard.key));

    final configuration = AppRouter.router.configuration;
    final matches = configuration.findMatch(Uri.parse('/dashboard'));
    final state = matches.lastOrNull!.buildState(configuration, matches);
    final context = tester.element(find.byKey(const Key('route-factory-host')));
    final shell = configuration.routes.whereType<ShellRoute>().single;
    final page = shell.pageBuilder!(context, state, const SizedBox());
    expect(page, isA<NoTransitionPage<dynamic>>());
    expect(page.key, state.pageKey);
    expectNoTransitionDurations(context, page);
  });
}
