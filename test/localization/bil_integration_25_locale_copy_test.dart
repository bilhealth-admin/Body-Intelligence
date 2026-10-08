import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_integration_gap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('33 integration messages cover every production locale', () {
    expect(IntegrationRuntimeCopy.sources, hasLength(33));
    expect(
      IntegrationRuntimeCopy.rows.keys.toSet(),
      BilLocalePolicy.productionTags.toSet(),
    );
    expect(IntegrationRuntimeCopy.balanced, isTrue);
    for (final english in IntegrationRuntimeCopy.sources) {
      for (final tag in BilLocalePolicy.productionTags) {
        final translated = IntegrationRuntimeCopy.resolve(english, tag);
        expect(translated, isNotNull, reason: '$tag: $english');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $english');
        expect(
          RuntimeCopy.resolve(english, tag),
          translated,
          reason: '$tag: $english',
        );
        if (tag != 'en') {
          expect(translated, isNot(english), reason: '$tag: $english');
        }
      }
    }
  });

  test('security, rewards, and read-only copy keep their meaning', () {
    const guard = 'Read-only mode. No food was logged.';
    const approved = 'Approved · no AI token grant was confirmed';
    const receipt = '+5 AI tokens confirmed by the server receipt';
    const summary =
        'An eligible approved post may earn +5 AI tokens only when the server reward receipt confirms the grant. Approval alone does not guarantee a token award; daily limits may apply. AI tokens are not BIL Gold and cannot be cashed out. Opening or saving a draft earns nothing.';
    for (final tag in BilLocalePolicy.productionTags) {
      expect(RuntimeCopy.resolve(guard, tag), isNotNull);
      expect(RuntimeCopy.resolve(approved, tag), isNotNull);
      expect(RuntimeCopy.resolve(receipt, tag), contains('+5'));
      final body = RuntimeCopy.resolve(summary, tag);
      expect(body, contains('BIL Gold'), reason: tag);
      expect(body, contains('+5'), reason: tag);
    }
    expect(
      RuntimeCopy.resolve(guard, 'ar'),
      'وضع القراءة فقط. لم يُسجَّل أي طعام.',
    );
  });

  test('unrecognized English keys are not fabricated by integrated copy', () {
    expect(IntegrationRuntimeCopy.resolve('does not exist', 'fr'), isNull);
    expect(IntegrationRuntimeCopy.resolve('Hidden', 'xx-XX'), isNull);
    expect(
      IntegrationRuntimeCopy.resolve(
        'Only the memory you selected will be deleted.',
        'zh-Hans',
      ),
      '只会删除您选中的记忆。',
    );
  });
}
