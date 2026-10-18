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

  test('five-item dock selects destinations directly with GoRouter', () {
    final dock = File(
      'lib/shared/widgets/bil_reference_bottom_bar.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();
    expect(dock, contains("'/intelligence-center'"));
    expect(dock, contains("'/community'"));
    expect(dock, contains("'/settings'"));
    expect(shell, contains('context.go(target)'));
    expect(shell, isNot(contains('animateToPage')));
  });
}
