import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile shell restores page area above the navigation bar', () {
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();

    expect(shell, contains('extendBody: false'));
    expect(shell, contains('final dockHeight = 90.0 +'));
    expect(shell, contains('height: dockHeight'));
    expect(shell, contains("key: const Key('shell-quick-add')"));
    expect(shell, contains('quickAdd: quickButton'));
    expect(shell, contains('Color(0xF20B1725)'));
    expect(shell, contains('Color(0xF7FFFFFF)'));
    expect(shell, isNot(contains('FloatingActionButtonLocation.centerDocked')));
  });
}
