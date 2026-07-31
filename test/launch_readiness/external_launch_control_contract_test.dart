import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'Missing required file: $path');
    return file.readAsStringSync();
  }

  test(
    'external launch ledger orders every gate and preserves dependencies',
    () {
      final ledger = read(
        'docs/external_launch/BIL_V1_EXTERNAL_LAUNCH_GATE_LEDGER.md',
      );

      expect(ledger, contains('113ef663f28c0e55f80d07a79cb6fbde52875036'));
      expect(ledger, contains('Global production launch: `NOT COMPLETE`'));
      for (var gate = 0; gate <= 10; gate++) {
        expect(ledger, contains('| $gate |'));
      }
      expect(ledger, contains('BLOCKED_EXTERNAL'));
      expect(ledger, contains('PENDING_DEPENDENCY'));
    },
  );

  test(
    'artifact provenance is exact and does not claim external completion',
    () {
      final provenance = read(
        'docs/external_launch/BIL_V1_EXTERNAL_LAUNCH_001_ARTIFACT_PROVENANCE.md',
      );
      final verifier = read(
        'tool/external_launch/verify_release_artifact_provenance.ps1',
      );

      for (final value in <String>[
        '1.0.0+1',
        '74229640',
        '0276C0628C9502A9436ACD915D953B5270916B5D883F138A2627E0E4A5821661',
      ]) {
        expect(provenance, contains(value));
        expect(verifier, contains(value));
      }

      expect(provenance, contains('does not prove production signing'));
      expect(verifier, contains('STORE_APPROVAL=NOT_CLAIMED'));
    },
  );

  test('BIL product invariants remain binding through external launch', () {
    final ledger = read(
      'docs/external_launch/BIL_V1_EXTERNAL_LAUNCH_GATE_LEDGER.md',
    );
    for (final invariant in <String>[
      'Privacy First',
      'Offline First',
      'Truth Engine',
      'Body Twin',
      'One Best Action',
      'Explainable Intelligence',
    ]) {
      expect(ledger, contains(invariant));
    }
  });
}
