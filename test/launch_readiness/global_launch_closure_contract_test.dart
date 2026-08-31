import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'Missing required file: $path');
    return file.readAsStringSync();
  }

  test('global launch closure preserves the accepted package sequence', () {
    final closure = read(
      'docs/launch_readiness/BIL_V1_GLOBAL_LAUNCH_CLOSURE.md',
    );

    for (var package = 1; package <= 6; package++) {
      final suffix = package.toString().padLeft(3, '0');
      expect(closure, contains('BIL-V1-LAUNCH-$suffix'));
    }

    expect(closure, contains('repository closure'));
    expect(closure, contains('not complete'));
    expect(closure, contains('Google Play Console'));
    expect(closure, contains('App Store Connect'));
    expect(closure, contains('representative Android and Apple device matrix'));
  });

  test('release identity and predecessor gates remain explicit', () {
    final pubspec = read('pubspec.yaml');
    final boundary = read(
      'docs/launch_readiness/BIL_GLOBAL_LAUNCH_BOUNDARY.md',
    );
    final candidate = read(
      'docs/launch_readiness/BIL_RELEASE_CANDIDATE_GATE.md',
    );

    expect(pubspec, contains('version: 1.0.0+5'));
    expect(boundary, contains('BIL-V1-LAUNCH-006'));
    expect(candidate, contains('1.0.0+5'));
    expect(candidate.toLowerCase(), contains('external'));
  });

  test('closure is honest about external authorization boundaries', () {
    final closure = read(
      'docs/launch_readiness/BIL_V1_GLOBAL_LAUNCH_CLOSURE.md',
    );

    for (final boundary in <String>[
      'Production Android keystore',
      'Apple distribution certificates',
      'final legal approval',
      'Store review',
      'rollback decisions',
    ]) {
      expect(closure, contains(boundary));
    }
  });
}
