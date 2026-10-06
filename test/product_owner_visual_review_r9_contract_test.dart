import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile shell restores page area above the navigation bar', () {
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();
    final dock = File(
      'lib/shared/widgets/bil_reference_bottom_bar.dart',
    ).readAsStringSync();

    expect(shell, contains('extendBody: false'));
    // The owner's current Coach reference supersedes the old 68dp/18dp dock.
    // Native widget tests verify these ratios at three widths and 100%/200%.
    expect(shell, contains('child: BilReferenceBottomBar('));
    expect(dock, contains('final rise = 6 * opticalScale'));
    expect(
      dock,
      contains('final surfaceHeight = 79 * opticalScale + labelGrowth'),
    );
    expect(dock, contains('final contentHeight = rise + surfaceHeight'));
    expect(dock, contains('height: contentHeight + safeBottom'));
    expect(dock, contains('MediaQuery.paddingOf(context).bottom'));
    expect(shell, contains('moreAttentionCount:'));
    expect(shell, contains("key: const Key('shell-quick-add')"));
    expect(
      shell,
      contains('showBilQuickAdd(context, originPath: paths[index])'),
    );
    expect(dock, contains('Color(0xFF121B28)'));
    expect(dock, contains('Color(0xFFFFFFFF)'));
    expect(shell, isNot(contains('FloatingActionButtonLocation.centerDocked')));
  });
}
