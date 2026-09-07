import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup and first dashboard entry cannot animate side by side', () {
    final source = File('lib/app/router/app_router.dart').readAsStringSync();

    expect(
      source,
      contains(
        "pageBuilder: (_, _) => const NoTransitionPage(child: StartupPage())",
      ),
    );
    expect(
      source,
      contains(
        'pageBuilder: (_, _, child) =>\n'
        '            NoTransitionPage(child: ResponsiveAppShell(child: child)),',
      ),
    );
    expect(
      source,
      contains(
        "path: '/dashboard',\n            pageBuilder: (_, _) =>\n"
        '                const NoTransitionPage(child: DashboardPage()),',
      ),
    );
  });
}
