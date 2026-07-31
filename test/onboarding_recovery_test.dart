import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local onboarding failure remains safe and retryable', () {
    final source = File(
      'lib/features/onboarding/onboarding_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("context.strings.text('Could not restore your local setup')"),
    );
    expect(source, contains("context.strings.text('Try again')"));
    expect(source, contains('loadInitialState();'));
    expect(source, contains('Icons.refresh'));
    expect(source, contains('loadFailed = true'));
    expect(source, isNot(contains('private database detail')));
  });
}
