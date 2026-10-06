import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_next_workspace.dart';
import 'package:body_intelligence_log/features/community/presentation/community_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'reference_regression_r2_cases.dart';

void main() {
  registerReferenceRegressionCases();
  test(
    'workspace copy covers every production locale with exact placeholders',
    () {
      final tokens = RegExp(r'\{[^}]+\}');
      final sources = NextWorkspaceRuntimeCopy.sources;
      expect(sources.toSet(), hasLength(sources.length));
      for (final tag in BilLocalePolicy.productionTags) {
        for (final source in sources) {
          final translated = NextWorkspaceRuntimeCopy.resolve(source, tag);
          expect(translated, isNotNull, reason: '$tag / $source');
          expect(translated!.trim(), isNotEmpty);
          if (tag != 'en') expect(translated, isNot(source));
          expect(
            tokens.allMatches(translated).map((m) => m[0]).toList(),
            tokens.allMatches(source).map((m) => m[0]).toList(),
          );
          expect(RuntimeCopy.resolve(source, tag), translated);
        }
      }
    },
  );
  test('inbox acknowledgement resolves the translated copy', () {
    for (final tag in BilLocalePolicy.productionTags) {
      for (final source in NextWorkspaceRuntimeCopy.sources.take(2)) {
        expect(
          communityTextForLanguage(tag, source, 'unused'),
          NextWorkspaceRuntimeCopy.resolve(source, tag),
        );
      }
    }
  });
}
