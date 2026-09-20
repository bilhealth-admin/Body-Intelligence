import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach keeps one retry surface for a failed turn', () {
    final page = File(
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
    ).readAsStringSync();
    final flow = File(
      'lib/features/intelligence_center/presentation/intelligence_query_flow.dart',
    ).readAsStringSync();
    final message = File(
      'lib/features/intelligence_center/presentation/intelligence_center_message_widgets.dart',
    ).readAsStringSync();

    expect(page, contains('retryableErrorMessageIds.isEmpty'));
    expect(page, contains('retryableErrorMessageIds.contains(message.id)'));
    expect(flow, contains('retryableErrorMessageIds.clear();'));
    expect(flow, contains('retryableErrorMessageIds.add(presented.id);'));
    expect(flow, contains('retryableErrorMessageIds.add(errorMessage.id);'));
    expect(message, contains("Key('ai-coach-retry')"));
    expect(message, isNot(contains("Key('ai-coach-retry-progress')")));
  });
}
