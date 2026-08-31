import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_ai_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exhaustionKeys = <String>[
    'Your available AI tokens are exhausted. No message was charged. Reactivate the smart coach with Premium AI Coach or add AI Boost tokens.',
    'Your Premium AI Coach subscription is active, but its available AI tokens are exhausted. No message was charged. Add AI Boost tokens to continue now.',
    'Get AI Boost',
  ];

  test('AI access and exhaustion copy is complete in all 25 locales', () {
    expect(RuntimeCopy.supported, hasLength(25));
    expect(AiAccessRuntimeCopy.supported, RuntimeCopy.supported);
    expect(AiAccessRuntimeCopy.balanced, isTrue);

    for (final locale in RuntimeCopy.supported) {
      for (final key in exhaustionKeys) {
        final localized = RuntimeCopy.resolve(key, locale);
        expect(localized, isNotNull, reason: '$locale:$key is missing');
        expect(localized!.trim(), isNotEmpty, reason: '$locale:$key is empty');
        if (locale != 'en') {
          expect(
            localized,
            isNot(key),
            reason: '$locale:$key fell back to English',
          );
        }
      }
    }
  });

  test('credit-exhaustion surfaces use the reviewed catalog keys', () {
    final engine = File(
      'lib/features/intelligence_center/services/intelligence_center_engine.dart',
    ).readAsStringSync();
    final queryFlow = File(
      'lib/features/intelligence_center/presentation/intelligence_query_flow.dart',
    ).readAsStringSync();

    expect(engine, contains(exhaustionKeys[0]));
    expect(engine, contains(exhaustionKeys[2]));
    expect(queryFlow, contains(exhaustionKeys[1]));
  });
}
