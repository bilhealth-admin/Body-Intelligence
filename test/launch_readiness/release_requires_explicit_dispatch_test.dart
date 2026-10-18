import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in ['ios', 'android']) {
    test(
      '$platform signing cannot be triggered by an ordinary source push',
      () {
        final path = platform == 'ios'
            ? '.github/workflows/bil_ios_signed_release.yml'
            : '.github/workflows/bil_android_release_candidate.yml';
        final source = File(path).readAsStringSync();
        final trigger = source.substring(
          source.indexOf('\non:'),
          source.indexOf('\npermissions:'),
        );
        expect(trigger, contains('workflow_dispatch:'));
        expect(trigger, isNot(contains('push:')));
        expect(trigger, isNot(contains('workflow_run:')));
        expect(trigger, isNot(contains('schedule:')));
        if (platform == 'ios') {
          expect(trigger, contains('upload_to_testflight:'));
          expect(trigger, contains('default: false'));
          expect(source, isNot(contains("github.event_name == 'push'")));
          expect(
            source,
            contains('if: \u0024{{ inputs.upload_to_testflight }}'),
          );
        }
      },
    );
  }
}
