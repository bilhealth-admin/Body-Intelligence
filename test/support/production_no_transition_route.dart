import 'package:body_intelligence_log/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Execute the production route factory instead of matching its source spelling.
NoTransitionPage<dynamic> expectProductionNoTransitionRoute(
  WidgetTester tester,
  String path,
) {
  final configuration = AppRouter.router.configuration;
  final matches = configuration.findMatch(Uri.parse(path));
  expect(matches.isError, isFalse, reason: path);
  final match = matches.lastOrNull!;
  final state = match.buildState(configuration, matches);
  final context = tester.element(find.byKey(const Key('route-factory-host')));
  final page = match.route.pageBuilder!(context, state);
  expect(page, isA<NoTransitionPage<dynamic>>(), reason: path);
  expect(
    page.key,
    state.pageKey,
    reason: 'Each destination owns its page key.',
  );
  final result = page as NoTransitionPage<dynamic>;
  expectNoTransitionDurations(context, result);
  return result;
}

void expectNoTransitionDurations(BuildContext context, Page<dynamic> page) {
  final route = page.createRoute(context) as PageRoute<dynamic>;
  expect(route.transitionDuration, Duration.zero);
  expect(route.reverseTransitionDuration, Duration.zero);
  route.dispose();
}
