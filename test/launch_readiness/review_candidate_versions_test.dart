import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final candidate in [('ios', 37), ('android', 33)]) {
    test(
      'review candidate ${candidate.$1} uses exact independent build number',
      () async {
        final result = await Process.run(
          Platform.isWindows ? 'python' : 'python3',
          [
            'tool/release/candidate_version_args.py',
            '--platform',
            candidate.$1,
          ],
        );
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(jsonDecode(result.stdout as String), [
          '--build-name=1.0.0',
          '--build-number=${candidate.$2}',
        ]);
        final metadata =
            jsonDecode(
                  File(
                    'tool/release/candidate_versions.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(
          metadata['source_branch'],
          'integration/bil-qa-media-policy-20261011',
        );
        expect(metadata['store_approved'], isFalse);
        expect(metadata['artifact_built'], isFalse);
        // Flutter propagates an explicit --build-number independently of the
        // historical pubspec fallback. Do not rewrite frozen build35/32 evidence.
        final native = File(
          candidate.$1 == 'ios'
              ? 'ios/Runner/Info.plist'
              : 'android/app/build.gradle.kts',
        ).readAsStringSync();
        expect(
          native,
          contains(
            candidate.$1 == 'ios'
                ? r'$(FLUTTER_BUILD_NUMBER)'
                : 'versionCode = flutter.versionCode',
          ),
        );
      },
    );
  }
}
