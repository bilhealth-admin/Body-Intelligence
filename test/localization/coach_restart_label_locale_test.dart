import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_closure_coach.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adding the restart label preserves balanced existing Coach rows', () {
    expect(ClosureCoachRuntimeCopy.balanced, isTrue);
    expect(
      ClosureCoachRuntimeCopy.sources.toSet().length,
      ClosureCoachRuntimeCopy.sources.length,
    );
  });
  for (final tag in BilLocalePolicy.productionTags) {
    test('restart label resolves through the app runtime resolver: $tag', () {
      final label = RuntimeCopy.resolve('Start new conversation', tag);
      expect(label, isNotNull);
      expect(label!.trim(), isNotEmpty);
      if (tag != 'en') {
        expect(
          label,
          isNot('Start new conversation'),
          reason: 'The new pull action cannot fall back to English.',
        );
      }
      if (tag == 'ar') expect(label, 'بدء محادثة جديدة');
    });
  }
}
