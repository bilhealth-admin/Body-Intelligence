import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first Coach message remains single-flight and single-rendered', () {
    final flow = File(
      'lib/features/intelligence_center/presentation/intelligence_query_flow.dart',
    ).readAsStringSync();
    final gateway = File(
      'lib/features/intelligence_center/services/local_model_gateway_io.dart',
    ).readAsStringSync();

    expect(
      flow,
      allOf(
        contains('if (!conversationReady ||'),
        contains('consentPromptVisible ||'),
        contains('foodImageFlowOpening)'),
      ),
    );
    expect(flow, contains('final generation = ++requestGeneration;'));
    expect(flow, contains('if (addUserMessage) {'));
    expect(flow, contains('addUserMessage: false'));
    expect(flow, contains('repeatedServiceNotice'));
    expect(
      gateway,
      isNot(contains('_readRemoteAiConsentWithSafeRetry')),
      reason: 'Consent preflight must not regain the old automatic retry path.',
    );
  });
}
