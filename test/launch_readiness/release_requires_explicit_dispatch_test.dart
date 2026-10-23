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
          expect(trigger, isNot(contains('upload_to_testflight:')));
          expect(source, isNot(contains("github.event_name == 'push'")));
          expect(source, contains("UPLOAD_TO_TESTFLIGHT: 'false'"));
        }
      },
    );
  }
  test(
    'TestFlight promotion is independently dispatched without a rebuild',
    () {
      final source = File(
        '.github/workflows/bil_ios_upload_existing_testflight.yml',
      ).readAsStringSync();
      final trigger = source.substring(
        source.indexOf('\non:'),
        source.indexOf('\npermissions:'),
      );
      expect(trigger, contains('workflow_dispatch:'));
      for (final forbidden in ['push:', 'workflow_run:', 'schedule:']) {
        expect(trigger, isNot(contains(forbidden)));
      }
      expect(source, contains('EXACT_SIGNED_IPA_38_BYTES_AND_SOURCE=PASS'));
      expect(source, isNot(contains('flutter build')));
    },
  );
}
