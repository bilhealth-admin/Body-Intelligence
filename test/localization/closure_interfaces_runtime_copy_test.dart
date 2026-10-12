import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_closure_access.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_closure_coach.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_closure_food.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_closure_review.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final tag in BilLocalePolicy.productionTags) {
    test('closure controls and review copy resolve in $tag', () {
      for (final (sources, rows) in [
        (ClosureAccessRuntimeCopy.sources, ClosureAccessRuntimeCopy.rows),
        (ClosureCoachRuntimeCopy.sources, ClosureCoachRuntimeCopy.rows),
        (ClosureFoodRuntimeCopy.sources, ClosureFoodRuntimeCopy.rows),
        (ClosureReviewRuntimeCopy.sources, ClosureReviewRuntimeCopy.rows),
      ]) {
        expect(rows.keys.toSet(), BilLocalePolicy.productionTags.toSet());
        for (var i = 0; i < sources.length; i++) {
          final value = RuntimeCopy.resolve(sources[i], tag);
          expect(value, rows[tag]![i]);
          expect(value!.trim(), isNotEmpty);
        }
      }
      for (final source in ClosureReviewRuntimeCopy.sources) {
        expect(
          communityTextForLanguage(
            tag,
            source,
            ClosureReviewRuntimeCopy.resolve(source, 'ar')!,
          ),
          ClosureReviewRuntimeCopy.resolve(source, tag),
        );
      }
      expect(RuntimeCopy.resolve('g', tag), tag == 'ar' ? 'غ' : 'g');
    });
  }
}
