import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_next_batch_closure.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/localization/smart_plan_copy_sources.dart';

void main() {
  test('new source and profile copy resolves in every release locale', () {
    expect(NextBatchClosureRuntimeCopy.balanced, isTrue);
    expect(
      NextBatchClosureRuntimeCopy.translations.keys.toSet(),
      BilLocalePolicy.productionTags.toSet(),
    );
    for (final tag in BilLocalePolicy.productionTags) {
      for (final source in NextBatchClosureRuntimeCopy.sources) {
        final translated = NextBatchClosureRuntimeCopy.resolve(source, tag);
        expect(translated, isNotNull, reason: '$tag: $source');
        expect(translated!.trim(), isNotEmpty, reason: '$tag: $source');
        expect(RuntimeCopy.resolve(source, tag), translated);
        if (tag != 'en') expect(translated, isNot(source));
        if (source.contains('BIL')) expect(translated, contains('BIL'));
      }
      for (final index in const [1, 5]) {
        final source = NextBatchClosureRuntimeCopy.sources[index];
        expect(
          communityTextForLanguage(
            tag,
            source,
            NextBatchClosureRuntimeCopy.translations['ar']![index],
          ),
          NextBatchClosureRuntimeCopy.resolve(source, tag),
          reason: tag,
        );
      }
    }
  });

  test('current English and Arabic source disclosures stay exact', () {
    const arabic = <String>[
      'يطبّق BIL إرشادات القوة المنشورة في برنامج عام للبالغين وليس لتأهيل الإصابات. لا تزيد المجموعات أو المقاومة تلقائيًا؛ راجع أي تعديل ووافق عليه.',
      'تعذر تحميل هذا الملف الشخصي. أعد المحاولة.',
      'تأتي قيم الوجبة من الوصفة الموثقة وحصتها من المصدر. افتح الكتاب بجانب عنوان الوجبة للاطلاع على المكونات والحصص والمصادر الأصلية. الأهداف اليومية المحفوظة منفصلة عن الطعام المستهلك.',
      'مصادر الخطة',
      'المراجع غير متاحة. اضغط لإعادة المحاولة.',
      'هذا الملف الشخصي غير متاح.',
      'مراجع التدريب',
    ];
    for (var i = 0; i < NextBatchClosureRuntimeCopy.sources.length; i++) {
      final source = NextBatchClosureRuntimeCopy.sources[i];
      expect(RuntimeCopy.resolve(source, 'en'), source);
      expect(RuntimeCopy.resolve(source, 'ar'), arabic[i]);
    }
    expect(
      NextBatchClosureRuntimeCopy.resolve('Not a source key', 'fr'),
      isNull,
    );
    expect(NextBatchClosureRuntimeCopy.resolve('Plan sources', 'xx'), isNull);
  });

  test(
    'Smart Plan source owner includes context helper and current labels',
    () async {
      final sources = await smartPlanCopySources();
      expect(
        sources,
        containsAll([
          'The reference could not be opened. Try again.',
          'Plan sources',
          'Training references',
          'References unavailable. Tap to retry.',
          NextBatchClosureRuntimeCopy.sources[0],
          NextBatchClosureRuntimeCopy.sources[2],
        ]),
      );
    },
  );
}
