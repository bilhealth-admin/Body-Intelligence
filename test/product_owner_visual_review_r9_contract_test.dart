import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile shell restores page area above the navigation bar', () {
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();

    expect(shell, contains('extendBody: false'));
    expect(shell, contains('final dockHeight = 68.0 +'));
    expect(shell, contains('const quickAddRise = 18.0'));
    expect(shell, contains('final reservedHeight = dockHeight + quickAddRise'));
    expect(shell, contains('height: reservedHeight'));
    expect(shell, contains("key: const Key('shell-quick-add')"));
    expect(shell, contains('quickAdd: quickButton'));
    expect(shell, contains('Color(0xF20B1725)'));
    expect(shell, contains('Color(0xF7FFFFFF)'));
    expect(shell, isNot(contains('FloatingActionButtonLocation.centerDocked')));
  });
}
