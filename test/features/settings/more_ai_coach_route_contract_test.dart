import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('More AI Coach opens canonical conversation surface', () {
    final source = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    expect(source, contains("copy('AI Coach')"));
    expect(source, contains("'/intelligence-center'"));
    expect(
      source,
      isNot(contains("_MoreRow('AI Coach', '/settings/ai-coach')")),
    );
  });
}
