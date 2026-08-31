import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local onboarding failure remains safe and retryable', () {
    final source = File(
      'lib/features/onboarding/onboarding_page.dart',
    ).readAsStringSync();

    expect(source, contains("_loadFailed = true"));
    expect(source, contains("label: Text(t('Try again'))"));
    expect(source, contains('unawaited(_load())'));
    expect(source, contains('Icons.refresh'));
    expect(source, contains('Nothing was changed because BIL could not save'));
    expect(source, isNot(contains('private database detail')));
  });
}
