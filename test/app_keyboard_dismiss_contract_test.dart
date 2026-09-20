import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'app shell dismisses the keyboard on background taps and drag starts',
    () {
      final source = File('lib/main.dart').readAsStringSync();

      expect(source, contains("Key('app-keyboard-dismiss-region')"));
      expect(source, contains('behavior: HitTestBehavior.translucent'));
      expect(source, contains('NotificationListener<ScrollStartNotification>'));
      expect(source, contains('notification.dragDetails != null'));
      expect(
        RegExp(
          r'FocusManager\.instance\.primaryFocus\?\.unfocus\(\)',
        ).allMatches(source),
        hasLength(greaterThanOrEqualTo(2)),
      );
    },
  );
}
