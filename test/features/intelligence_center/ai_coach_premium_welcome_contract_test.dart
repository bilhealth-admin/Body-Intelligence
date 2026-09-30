import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach entry welcome keeps premium black identity and typography', () {
    final source = File(
      'lib/features/intelligence_center/presentation/intelligence_center_widgets.dart',
    ).readAsStringSync();

    expect(source, contains('class _AiCoachEntryWelcome'));
    expect(source, contains('backgroundColor: const Color(0xFF030405)'));
    expect(source, contains('Color(0xFF173A62)'));
    expect(source, contains('Color(0xFF7568FF)'));
    expect(source, contains("'BILArabic'"));
    expect(source, contains("'BILDisplay'"));
    expect(source, contains("'Welcome to AI Coach'"));
    expect(source, contains("'Speak your language'"));
    expect(source, contains('BilCoachPortrait('));
  });
}
