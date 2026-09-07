import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dashboard water opens the focused water route and returns to dashboard',
    () {
      final grid = File(
        'lib/features/dashboard/widgets/dashboard_grid.dart',
      ).readAsStringSync();
      final reference = File(
        'lib/features/dashboard/widgets/dashboard_reference_phone.dart',
      ).readAsStringSync();

      for (final source in [grid, reference]) {
        expect(source, contains("'/daily-log/water?from=%2Fdashboard'"));
        expect(source, isNot(contains("'/daily-log?from=%2Fdashboard'")));
      }
    },
  );

  test('the shell owns the light dashboard system-bar contract', () {
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();
    expect(shell, contains('AnnotatedRegion<SystemUiOverlayStyle>'));
    expect(shell, contains('statusBarIconBrightness: Brightness.dark'));
    expect(shell, contains('statusBarBrightness: Brightness.light'));
  });

  test('account deletion remains reachable from Help only', () {
    final more = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    final help = File(
      'lib/features/settings/help_center_page.dart',
    ).readAsStringSync();
    expect(more, isNot(contains("copy('Delete account')")));
    expect(help, contains("id: 'delete-account'"));
    expect(help, contains("context.push('/help/delete-account')"));
  });
}
