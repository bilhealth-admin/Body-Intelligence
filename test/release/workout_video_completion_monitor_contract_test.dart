import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completion monitor is read-only and validates the full gym batch', () {
    final source = File(
      'artifacts/release/monitor_workout_video_gym_completion.ps1',
    ).readAsStringSync();

    expect(source, contains("'bulk_1000.run.lock'"));
    expect(source, contains(r'$observedGeneratorIds.Add($GeneratorProcessId)'));
    expect(source, contains(r"$lockText -match '^pid=(\d+)$'"));
    expect(source, contains(r'$idlePolls -ge 2'));
    expect(source, contains(r'$preflightIds.Count -ne 102'));
    expect(source, contains(r'$files.Count -eq 102'));
    expect(source, contains('-count_frames'));
    expect(source, contains(r'$frames -eq 300'));
    expect(source, contains(r'[int]$stream.width -eq 720'));
    expect(source, contains(r'[int]$stream.height -eq 1280'));
    expect(source, contains("r_frame_rate -ceq '30/1'"));
    expect(source, contains(r'[math]::Abs($duration - 10.0)'));
    expect(source, contains('Get-FileHash'));
    expect(source, isNot(contains('Invoke-RestMethod')));
    expect(source, isNot(contains('authorize-paid')));
    expect(source, isNot(contains('FAL_KEY')));
  });
}
