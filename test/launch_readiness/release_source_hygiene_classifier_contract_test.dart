import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source hygiene includes only exact retired safety-guard scripts', () {
    final source = File(
      'tool/release_hygiene/release_source_staging_dry_run.ps1',
    ).readAsStringSync();
    const guardedPaths = <String>{
      'artifacts/release/epic14/commit_epic14.ps1',
      'artifacts/release/epic14/run_epic14_gate.ps1',
      'artifacts/release/epic2/close_epic2.ps1',
      'artifacts/release/prepare_epic15_store_assets.ps1',
      'artifacts/release/run_epic15_gate.ps1',
      'artifacts/release/run_epic16_gate.ps1',
      'artifacts/release/visual_closure/commit_visual_closure.ps1',
      'scripts/release/finalize_bil_v1_rc.ps1',
    };

    expect(source, contains("category = 'retired_release_safety_guard'"));
    for (final path in guardedPaths) {
      expect(source, contains("'$path'"), reason: path);
    }
    expect(
      source,
      isNot(contains(r"$Path -match '^artifacts/release/'")),
      reason: 'Historical artifacts must never gain a broad include rule.',
    );
    expect(
      source,
      isNot(contains(r"$Path -match '^scripts/release/'")),
      reason: 'Release scripts must remain exact-allowlisted.',
    );
  });

  test('source hygiene excludes local diagnostics and includes runtime inputs', () {
    final source = File(
      'tool/release_hygiene/release_source_staging_dry_run.ps1',
    ).readAsStringSync();

    expect(source, contains("category = 'local_codex_agent_configuration'"));
    expect(source, contains("category = 'local_test_failure_diagnostic'"));
    expect(source, contains(r"$Path -match '^\.agents/'"));
    expect(source, contains(r"$Path -match '^test/(?:.+/)?failures/'"));
    expect(source, contains(r"$Path -match '^cloudflare/workout-runtime/'"));
    expect(source, contains("category = 'workout_runtime_edge_source'"));

    const runtimeInputs = <String>{
      'artifacts/workout_media/workout_discovery_catalog_v1.json',
      'artifacts/workout_media/gym_six_month_plan_runtime_v1.json',
      'artifacts/workout_media/cloudflare_runtime_v2/free_preview_keys_v1.json',
    };
    for (final path in runtimeInputs) {
      expect(source, contains("'$path'"), reason: path);
    }
  });
}
