import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/ai_coach_chat_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach action state copy is authored for all 25 BIL locales', () {
    expect(AiCoachChatCopy.values.keys.toSet(), BilLocalePolicy.productionTags);
    for (final tag in BilLocalePolicy.productionTags) {
      final localized = AiCoachChatCopy.values[tag];
      expect(localized, isNotNull, reason: tag);
      expect(localized!.keys.toSet(), AiCoachChatCopy.keys, reason: tag);
      for (final key in AiCoachChatCopy.keys) {
        expect(localized[key]?.trim(), isNotEmpty, reason: '$tag:$key');
        expect(
          AiCoachChatCopy.resolve(tag, key),
          localized[key],
          reason: '$tag:$key',
        );
      }
    }
  });

  test('regional locale normalization retains distinct Portuguese copy', () {
    expect(
      AiCoachChatCopy.resolve('pt_BR', AiCoachChatCopy.navigationFailed),
      contains('tela'),
    );
    expect(
      AiCoachChatCopy.resolve('pt-PT', AiCoachChatCopy.navigationFailed),
      contains('ecrã'),
    );
  });
}
