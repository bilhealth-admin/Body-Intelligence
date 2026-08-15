import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen keeps detailed Coach reply while speech is compact', () {
    final page = File(
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
    ).readAsStringSync();
    expect(page, contains('Text(message.text)'));
    expect(page, contains('_compactSpokenCoachReply(message.text)'));
    expect(page, contains('CoachLanguageResolver()'));
    expect(page, contains('input: message.text'));
    expect(page, contains('plain.length <= 140'));
    expect(page, contains('substring(0, 137)'));
  });
}
