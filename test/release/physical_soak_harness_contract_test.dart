import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('physical soak harness cannot compress or fabricate ten days', () {
    final source = File(
      'tool/device_lab/record_physical_soak_day.ps1',
    ).readAsStringSync();

    expect(source, contains("[ValidateRange(1, 10)]"));
    expect(source, contains(r'$records.Count -ne ($Day - 1)'));
    expect(source, contains(r'$today -le $previousDate.Date'));
    expect(source, contains(r'TotalDays -lt 9'));
    expect(source, contains('soak evidence is append-only'));
    expect(source, contains('EvidenceFile must be a real file'));
    expect(source, contains(r'Get-FileHash -LiteralPath $resolvedEvidence'));
    expect(source, contains(r'Get-FileHash -LiteralPath $resolvedArtifact'));
    expect(source, contains("'apple-watch-via-healthkit'"));
    expect(source, contains("'wear-os-via-health-connect'"));
    expect(source, contains("'ble-fitness'"));
    expect(source, isNot(contains("'ble-medical'")));
    expect(source, contains(r'$missingSurfaces.Count -eq 0'));
    expect(source, contains('required_surfaces ='));
    expect(source, contains('schema_version = 2'));
    expect(source, contains('artifact_sha256 ='));
    expect(source, contains('MISSING_SURFACES='));
    expect(source, contains("outcome -ne 'pass'"));
    expect(source, contains('STATE_MUTATED=False'));
  });
}
