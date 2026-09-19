import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup and first dashboard entry cannot animate side by side', () {
    final source = File('lib/app/router/app_router.dart').readAsStringSync();

    expect(
      source,
      contains(
        "pageBuilder: (_, state) => NoTransitionPage(\n"
        '          child: StartupPage(\n'
        '            initialAuthSession: state.extra is Session\n'
        '                ? state.extra! as Session\n'
        '                : null,\n'
        '          ),\n'
        '        ),',
      ),
    );
    expect(
      source,
      contains(
        'pageBuilder: (_, state, child) => NoTransitionPage(\n'
        '          child: ResponsiveAppShell(currentUri: state.uri, child: child),\n'
        '        ),',
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
