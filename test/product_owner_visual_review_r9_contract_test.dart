import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile shell restores page area above the navigation bar', () {
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();

    expect(
      shell,
      contains('extendBody: true'),
      reason:
          'The body must render behind the translucent bottom bar instead of ending at its reserved top edge.',
    );
    expect(shell, contains('FloatingActionButtonLocation.centerDocked'));
    expect(shell, contains('height: 76'));
    expect(shell, contains('Color(0xB807111D)'));
    expect(shell, contains('Color(0xB8F4F8FC)'));
    expect(shell, isNot(contains('EdgeInsets.only(bottom: 82)')));
  });
}
