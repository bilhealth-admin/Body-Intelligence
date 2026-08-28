import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile shell restores page area above the navigation bar', () {
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();

    expect(shell, contains('extendBody: false'));
    expect(shell, contains('height: 72'));
    expect(shell, contains("key: const Key('shell-quick-add')"));
    expect(shell, contains('Color(0xB807111D)'));
    expect(shell, contains('Color(0xB8F4F8FC)'));
    expect(shell, isNot(contains('FloatingActionButtonLocation.centerDocked')));
  });
}
