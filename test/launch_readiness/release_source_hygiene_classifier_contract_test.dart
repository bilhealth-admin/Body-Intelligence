import 'dart:convert';
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

  test(
    'source hygiene excludes local diagnostics and includes runtime inputs',
    () {
      final source = File(
        'tool/release_hygiene/release_source_staging_dry_run.ps1',
      ).readAsStringSync();

      expect(source, contains("category = 'local_codex_agent_configuration'"));
      expect(source, contains("category = 'local_test_failure_diagnostic'"));
      expect(source, contains(r"$Path -match '^\.agents/'"));
      expect(
        source,
        contains(r"$Path -match '^\.codex_server_reconciliation/'"),
      );
      expect(source, contains(r"$Path -match '^ai_coach_debug_bundle/'"));
      expect(
        source,
        contains("category = 'local_server_reconciliation_snapshot'"),
      );
      expect(source, contains("category = 'local_ai_coach_debug_bundle'"));
      expect(source, contains(r"$Path -match '^test/(?:.+/)?failures/'"));
      expect(source, contains(r"$Path -match '^cloudflare/workout-runtime/'"));
      expect(source, contains("category = 'workout_runtime_edge_source'"));
      expect(
        source,
        contains("'scripts/release/dispatch_bil_release_workflows.ps1'"),
      );
      expect(source, contains("category = 'exact_release_dispatch_guard'"));
      expect(
        source,
        isNot(contains(r"$Path -match '^scripts/release/'")),
        reason: 'Release scripts must remain exact-allowlisted.',
      );

      const runtimeInputs = <String>{
        'artifacts/workout_media/workout_discovery_catalog_v1.json',
        'artifacts/workout_media/gym_six_month_plan_runtime_v1.json',
        'artifacts/workout_media/cloudflare_runtime_v2/free_preview_keys_v1.json',
      };
      for (final path in runtimeInputs) {
        expect(source, contains("'$path'"), reason: path);
      }
    },
  );

  test(
    'release blockers inspect INCLUDE paths, not preserved EXCLUDE paths',
    () {
      final source = File(
        'tool/release_hygiene/release_source_staging_dry_run.ps1',
      ).readAsStringSync();
      final includeGate = source.indexOf(
        r"if ($classification.decision -eq 'INCLUDE') {",
      );
      final entryAppend = source.indexOf(r'$entries.Add', includeGate);

      expect(includeGate, greaterThanOrEqualTo(0));
      expect(entryAppend, greaterThan(includeGate));
      final gatedChecks = source.substring(includeGate, entryAppend);
      expect(gatedChecks, contains(r'$bytes -gt $githubHardFileLimitBytes'));
      expect(gatedChecks, contains('Get-ContentSecretFinding -Path \$path'));
      expect(gatedChecks, contains(r'$secretFindings.Add'));
    },
  );

  test(
    'candidate transfer is explicit, three-way, and never stages globally',
    () {
      final source = File(
        'tool/release_hygiene/apply_classified_source_to_candidate.ps1',
      ).readAsStringSync();

      expect(source, contains('[switch]\$Apply'));
      expect(
        source,
        contains('candidate worktree is not clean before transfer'),
      );
      expect(source, contains(r'$env:GIT_INDEX_FILE = $temporaryIndex'));
      expect(source, contains('--literal-pathspecs add -f -A'));
      expect(source, contains('--pathspec-from-file='));
      expect(source, contains('commit-tree \$classifiedTree -p \$sourceHead'));
      expect(source, contains('merge-tree --write-tree --name-only --no-messages'));
      expect(source, contains('read-tree --reset -u \$mergedTree'));
      expect(source, contains('merge-tree conflicts='));
      expect(source, contains('merged tree changed outside INCLUDE'));
      expect(source, contains('candidate changed outside INCLUDE'));
      expect(source, isNot(contains(' --ours')));
      expect(source, isNot(contains(' --theirs')));
      expect(source, isNot(contains('git add .')));
      expect(source, isNot(contains('git add -A')));
      expect(source, isNot(contains('git commit')));
    },
  );

  test('source hygiene exact-classifies the R074 candidate support paths', () {
    final source = File(
      'tool/release_hygiene/release_source_staging_dry_run.ps1',
    ).readAsStringSync();
    const repositoryControls = <String>{
      '.gitignore',
      '.gitattributes',
      'wrangler.site.jsonc',
    };
    const reviewedBrandCleanup = <String>{
      'artifacts/brand/bil_launch_badge.svg',
      'artifacts/brand/bil_splash_preview_1080x2400.png',
      'store_assets/evidence/asset_evidence_matrix.csv',
      'store_assets/evidence/asset_evidence_matrix.json',
      'store_assets/evidence/preview_index.html',
      'store_assets/evidence/sha256_manifest.txt',
      'store_assets/evidence/store_asset_inventory.csv',
      'store_assets/graphics/brand/bil_emblem_master.png',
      'store_assets/graphics/brand/bil_horizontal_dark.png',
      'store_assets/graphics/brand/bil_horizontal_light.png',
      'store_assets/graphics/google_play/feature_graphic.png',
      'store_assets/graphics/plans/free.png',
      'store_assets/graphics/plans/plus.png',
      'store_assets/graphics/plans/pro.png',
      'store_assets/source/BIL-Brand-Assets-v1/01-bil-app-icon.png',
      'store_assets/source/BIL-Brand-Assets-v1/02-bil-splash.png',
      'store_assets/source/BIL-Brand-Assets-v1/03-bil-horizontal-logo.png',
      'store_assets/source/BIL-Brand-Assets-v1/04-bil-onboarding-hero.png',
      'store_assets/source/BIL-Brand-Assets-v1/05-bil-store-feature-graphic.png',
      'store_assets/source/BIL-Brand-Assets-v1/06-bil-free-plus-pro.png',
      'store_assets/source/BIL-Brand-Assets-v1/README.md',
    };

    expect(repositoryControls, hasLength(3));
    expect(reviewedBrandCleanup, hasLength(21));
    expect(source, contains("category = 'release_repository_control'"));
    expect(
      source,
      contains("category = 'owner_controlled_brand_evidence_delta'"),
    );
    for (final path in {...repositoryControls, ...reviewedBrandCleanup}) {
      expect(source, contains("'$path'"), reason: path);
    }

    const forbiddenBroadIncludes = <String>{
      r"$Path -match '^artifacts/brand/'",
      r"$Path -match '^store_assets/evidence/'",
      r"$Path -match '^store_assets/graphics/'",
      r"$Path -match '^store_assets/source/'",
    };
    for (final rule in forbiddenBroadIncludes) {
      expect(
        source,
        isNot(contains(rule)),
        reason: 'R074 candidate support paths must remain exact-allowlisted.',
      );
    }
  });

  test('source hygiene excludes exact R074 preserve-only evidence', () {
    final source = File(
      'tool/release_hygiene/release_source_staging_dry_run.ps1',
    ).readAsStringSync();
    const previewWavs = <String>{
      'tool/bil_mic_end_preview.wav',
      'tool/bil_mic_end_vibration_preview.wav',
      'tool/bil_mic_open_preview.wav',
      'tool/bil_mic_open_vibration_preview.wav',
      'tool/bil_mic_tap_preview.wav',
    };

    expect(previewWavs, hasLength(5));
    expect(source, contains("category = 'local_supabase_fetch_probe'"));
    expect(
      source,
      contains(r"$Path -match '^\.codex_supabase_fetch_probe_20260901_2320/'"),
    );
    expect(source, contains(r"$Path -match '^videos/bil-product-launch/'"));
    expect(
      source,
      contains(r"$Path -eq 'macos/Flutter/GeneratedPluginRegistrant.swift'"),
    );
    expect(source, contains("category = 'local_audio_preview'"));
    for (final path in previewWavs) {
      expect(source, contains("'$path'"), reason: path);
    }

    final previewExclusionIndex = source.indexOf(
      "'tool/bil_mic_end_preview.wav'",
    );
    final genericToolIncludeIndex = source.indexOf(
      r"if ($Path -match '^tool/')",
    );
    expect(previewExclusionIndex, greaterThanOrEqualTo(0));
    expect(genericToolIncludeIndex, greaterThanOrEqualTo(0));
    expect(
      previewExclusionIndex,
      lessThan(genericToolIncludeIndex),
      reason: 'The five preview WAV exclusions must precede generic tool/**.',
    );
  });

  test('secret scanner contract keeps the PEM exception delimiter-only', () {
    final source = File(
      'tool/release_hygiene/release_source_staging_dry_run.ps1',
    ).readAsStringSync();
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/release/source_hygiene_secret_scanner_contract.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final cases = (fixture['cases'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final names = cases.map((entry) => entry['name'] as String).toSet();

    expect(fixture['schema_version'], 1);
    expect(cases, hasLength(9));
    expect(cases.where((entry) => entry['kind'] == 'positive'), hasLength(2));
    expect(cases.where((entry) => entry['kind'] == 'negative'), hasLength(7));
    expect(
      names,
      containsAll(<String>{
        'allow_exact_begin_starts_with',
        'allow_exact_end_ends_with',
        'block_standalone_begin',
        'block_actual_pem_body',
        'block_escaped_multiline_literal',
        'block_concatenated_key_text',
        'allow_delimiter_but_block_other_secret',
        'block_non_exact_validation_argument',
        'block_begin_marker_in_ends_with',
      }),
    );
    for (final entry in cases) {
      expect(
        () => base64Decode(entry['text_base64'] as String),
        returnsNormally,
        reason: entry['name'] as String,
      );
    }

    expect(source, contains('Test-IsExactPemDelimiterValidationLiteral'));
    expect(source, contains('Get-TextSecretFinding'));
    expect(source, contains(r'$RunSecretScannerContract'));
    expect(
      source,
      isNot(contains('apple_sign_in_token_lifecycle.ts')),
      reason: 'The scanner exception must not whitelist a production file.',
    );
  });

  test('historical R074 snapshot retains original fifteen REVIEW decisions', () {
    final companion = File(
      'docs/release/BIL_PLUS8_STAGING_MANIFEST_REVIEW_COMPANION_2026-09-05.md',
    ).readAsStringSync();
    final stagingManifest = File(
      'docs/release/BIL_PLUS8_STAGING_MANIFEST_2026-09-05.md',
    ).readAsStringSync();
    const reviewGoldens = <String>{
      'test/visual_closure/goldens/quick_add_ar_dark_phone.png',
      'test/visual_closure/goldens/quick_add_en_light_phone.png',
      'test/visual_closure/goldens/visual_closure_ai_coach_conversation_phone.png',
      'test/visual_closure/goldens/visual_closure_daily_log_empty_phone.png',
      'test/visual_closure/goldens/visual_closure_dashboard_nutrient_goal_card_phone.png',
      'test/visual_closure/goldens/visual_closure_dashboard_phone.png',
      'test/visual_closure/goldens/visual_closure_diary_settings_phone.png',
      'test/visual_closure/goldens/visual_closure_diary_sharing_phone.png',
      'test/visual_closure/goldens/visual_closure_food_catalog_phone.png',
      'test/visual_closure/goldens/visual_closure_more_lower_phone.png',
      'test/visual_closure/goldens/visual_closure_profile_goals_phone.png',
      'test/visual_closure/goldens/visual_closure_profile_phone.png',
      'test/visual_closure/goldens/visual_closure_quick_nutrition_form_phone.png',
      'test/visual_closure/goldens/visual_closure_sleep_phone_2.png',
      'test/visual_closure/goldens/visual_closure_sleep_phone.png',
    };

    expect(reviewGoldens, hasLength(15));
    expect(companion, contains('### Visual rows that remain REVIEW'));
    for (final path in reviewGoldens) {
      expect(companion, contains('`$path`'), reason: path);
    }
    expect(stagingManifest, contains('`CANDIDATE_FROZEN_OR_ACCEPTED: NO`'));
  });

  test('source hygiene includes only exact splash contract inputs', () {
    final source = File(
      'tool/release_hygiene/release_source_staging_dry_run.ps1',
    ).readAsStringSync();

    const splashContractInputs = <String>{
      'videos/bil-splash-motion/index.html',
      'videos/bil-splash-motion/render-manifest.json',
    };
    for (final path in splashContractInputs) {
      expect(source, contains("'$path'"), reason: path);
    }

    final exactIncludeRule = RegExp(
      r"""if \(\$Path -in @\(\s*"""
      r"""'videos/bil-splash-motion/index\.html',\s*"""
      r"""'videos/bil-splash-motion/render-manifest\.json'\s*"""
      r"""\)\) \{\s*return \[ordered\]@\{\s*"""
      r"""decision = 'INCLUDE'\s*"""
      r"""category = 'splash_runtime_contract_input'""",
      multiLine: true,
    );
    final exactMatch = exactIncludeRule.firstMatch(source);
    expect(
      exactMatch,
      isNotNull,
      reason:
          'The splash include rule must remain an exact two-path allowlist.',
    );

    const broadExcludeRule = r"if ($Path -match '^videos/bil-splash-motion/')";
    final broadExcludeIndex = source.indexOf(broadExcludeRule);
    expect(broadExcludeIndex, greaterThanOrEqualTo(0));
    expect(
      exactMatch!.start,
      lessThan(broadExcludeIndex),
      reason:
          'The exact include allowlist must run before the broad exclusion.',
    );
    expect(source, contains("category = 'media_authoring_archive'"));
    expect(
      RegExp(r'videos/bil-splash-motion/').allMatches(source).length,
      3,
      reason: 'Only the two exact paths and the broad fallback may appear.',
    );
  });
}
