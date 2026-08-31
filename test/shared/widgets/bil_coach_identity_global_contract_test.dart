import 'dart:io';

import 'package:body_intelligence_log/shared/widgets/bil_coach_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'only the owner-approved AI Boost coach artwork ships as coach identity',
    () {
      const canonical =
          'assets/images/commerce/bil_ai_boost_coach_icon_512.png';
      final retiredName = <String>['bil_male', 'smart_coach_v1.png'].join('_');
      final retiredDirectory = <String>['assets/images', 'ai_coach'].join('/');

      expect(bilApprovedAiCoachAsset, canonical);
      expect(File(canonical).existsSync(), isTrue);
      expect(File('$retiredDirectory/$retiredName').existsSync(), isFalse);

      final sources = <File>[
        File('pubspec.yaml'),
        ...Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
        ...<String>[
          'docs/marketing/BIL_FAL_LONGCAT_STORE_PROMO_STORYBOARD_2026-08-29.md',
          'docs/audits/dark_static_image_replacement_manifest_v1.md',
        ].map(File.new),
      ];
      for (final file in sources) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains(retiredName)), reason: file.path);
        expect(
          source,
          isNot(contains('$retiredDirectory/')),
          reason: file.path,
        );
      }
    },
  );
}
