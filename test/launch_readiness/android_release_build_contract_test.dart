import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'historical local builder fails before mutating or building a candidate',
    () {
      final script = File(
        'tool/final_proof/build_android_release.ps1',
      ).readAsStringSync();

      final stop = script.indexOf('HISTORICAL_NON_CANDIDATE');
      expect(stop, greaterThanOrEqualTo(0));
      expect(stop, lessThan(script.indexOf('flutter pub get')));
      expect(stop, lessThan(script.indexOf("'build', 'appbundle'")));
      expect(
        script,
        contains('.github/workflows/bil_android_release_candidate.yml'),
      );
      expect(script, isNot(contains('storePassword=')));
      expect(script, isNot(contains('keyPassword=')));
    },
  );
}
