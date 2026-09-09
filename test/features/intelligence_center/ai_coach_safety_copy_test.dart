import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/ai_coach_safety_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach safety block copy is explicit for all 25 locales', () {
    expect(
      AiCoachSafetyCopy.values.keys.toSet(),
      BilLocalePolicy.productionTags,
    );
    for (final tag in BilLocalePolicy.productionTags) {
      final value = AiCoachSafetyCopy.resolve(tag);
      expect(value.trim(), isNotEmpty, reason: tag);
      expect(value, AiCoachSafetyCopy.values[tag], reason: tag);
    }
  });

  test('unknown locale safely resolves to English without a retry label', () {
    final value = AiCoachSafetyCopy.resolve('unsupported');
    expect(value, AiCoachSafetyCopy.values['en']);
    expect(value, contains('no message was charged'));
    expect(value.toLowerCase(), isNot(contains('try again')));
    expect(value.toLowerCase(), isNot(contains('retry')));
  });
}
