import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('historical release tools stop before mutation or candidate claims', () {
    final tools = <String, String>{
      'artifacts/release/epic14/run_epic14_gate.ps1':
          'HISTORICAL_NON_AUTHORITATIVE',
      'artifacts/release/run_epic15_gate.ps1': 'HISTORICAL_NON_AUTHORITATIVE',
      'artifacts/release/run_epic16_gate.ps1': 'HISTORICAL_NON_AUTHORITATIVE',
      'tool/final_proof/build_android_release.ps1': 'HISTORICAL_NON_CANDIDATE',
      'tool/android_launch_readiness/verify_android_launch_readiness.ps1':
          'HISTORICAL_NON_AUTHORITATIVE',
      'tool/google_play_preparation/verify_google_play_preparation.ps1':
          'HISTORICAL_NON_AUTHORITATIVE',
      'scripts/release/finalize_bil_v1_rc.ps1': 'HISTORICAL_NON_AUTHORITATIVE',
      'artifacts/release/epic14/commit_epic14.ps1':
          'HISTORICAL_NON_AUTHORITATIVE',
      'artifacts/release/visual_closure/commit_visual_closure.ps1':
          'HISTORICAL_NON_AUTHORITATIVE',
      'artifacts/release/epic2/close_epic2.ps1': 'HISTORICAL_NON_AUTHORITATIVE',
    };

    for (final entry in tools.entries) {
      final source = read(entry.key);
      final stop = source.indexOf(entry.value);
      expect(stop, greaterThanOrEqualTo(0), reason: entry.key);
      expect(
        source,
        contains('.github/workflows/bil_android_release_candidate.yml'),
        reason: entry.key,
      );
      for (final operation in <String>[
        'flutter build appbundle',
        "'build', 'appbundle'",
        "@('build','appbundle'",
        'New-Item -ItemType Directory',
        'Copy-Item',
        'Expand-Archive',
        'git tag',
        'git add',
        'git commit',
      ]) {
        final operationIndex = source.indexOf(operation);
        if (operationIndex >= 0) {
          expect(
            stop,
            lessThan(operationIndex),
            reason: '${entry.key} must stop before $operation',
          );
        }
      }
      for (final claim in <String>[
        'Release AAB artifact" "PASSED"',
        "Record 'Release AAB artifact' 'PASSED'",
        'EPIC14_GATE=PASS',
        'EPIC15_GATE=PASS',
        'EPIC16_GATE=PASS',
      ]) {
        final claimIndex = source.indexOf(claim);
        if (claimIndex >= 0) {
          expect(
            stop,
            lessThan(claimIndex),
            reason: '${entry.key} must stop before claiming $claim',
          );
        }
      }
    }
  });

  test('startup verifier requires the fitness-only BLE bridge', () {
    final script = read('tool/startup_readiness/verify_startup_readiness.ps1');
    expect(
      RegExp(
        r"com/bilhealth/bodyintelligencelog/BILFitnessBleBridge\.kt'",
      ).allMatches(script).length,
      2,
    );
    expect(
      script,
      isNot(
        contains('com/bilhealth/bodyintelligencelog/BILMedicalBleBridge.kt'),
      ),
    );
  });

  test('legacy Epic 15 asset preparation cannot restore medical artwork', () {
    final script = read('artifacts/release/prepare_epic15_store_assets.ps1');
    final stop = script.indexOf('HISTORICAL_NON_AUTHORITATIVE');
    expect(stop, greaterThanOrEqualTo(0));
    expect(stop, lessThan(script.indexOf(r'$storeRoot')));
    expect(script, isNot(contains('bil_medical_hub.png')));
    expect(script, contains('fitness-only connected-device source asset'));
  });

  test('current signed workflows carry the reviewed production contract', () {
    final android = read('.github/workflows/bil_android_release_candidate.yml');
    final ios = read('.github/workflows/bil_ios_signed_release.yml');
    const baseDefines = <String>{
      'BIL_ENVIRONMENT=production',
      'BIL_PAYMENTS_ENABLED=true',
      'BIL_TERMS_URL=https://www.bilhealth.com/terms',
      'BIL_PRIVACY_URL=https://www.bilhealth.com/privacy',
      'BIL_MEAL_VISION_ENDPOINT=https://tgmanzhqulksykhslrzb.supabase.co/functions/v1/analyze-meal',
      'BIL_WELLNESS_MANIFEST_URL=https://workouts.bilhealth.com/v2/manifest/wellness-workouts-v2-af6082ff28856f9154216067f16fe6a7147548c9a29f8e205b43bb81bc34efe8.json',
      'BIL_RECIPE_IMAGE_DELIVERY_ENABLED=true',
      'BIL_FACEBOOK_LOGIN_ENABLED=true',
      'BIL_FACEBOOK_LOGIN_READY=true',
      'BIL_ADS_ENABLED=false',
      'BIL_AD_PROVIDER_READY=false',
      'BIL_ENABLE_CATALOG_TEST_ACCESS=false',
    };
    final expectedByPlatform = <String, ({String source, Set<String> defines})>{
      'Android': (
        source: android,
        defines: {
          ...baseDefines,
          'BIL_MOBILE_INTEGRITY_REQUIRED=true',
          r'BIL_PLAY_INTEGRITY_PROJECT_NUMBER="$PLAY_INTEGRITY_PROJECT_NUMBER"',
        },
      ),
      'iOS': (
        source: ios,
        defines: {...baseDefines, 'BIL_MOBILE_INTEGRITY_REQUIRED=true'},
      ),
    };
    for (final entry in expectedByPlatform.entries) {
      final defines = RegExp(
        r'--dart-define=([^\s\\]+)',
      ).allMatches(entry.value.source).map((match) => match.group(1)!).toList();
      expect(defines, hasLength(entry.value.defines.length), reason: entry.key);
      expect(defines, unorderedEquals(entry.value.defines), reason: entry.key);
      expect(
        entry.value.source,
        contains('FACEBOOK_LOGIN_COMPILED_GATE=ENABLED_AND_READY'),
        reason: entry.key,
      );
      expect(
        entry.value.source,
        contains('FACEBOOK_LOGIN_SIGNED_DEVICE_GATE=REQUIRED'),
        reason: entry.key,
      );
    }
    expect(android, contains('Facebook OAuth via Supabase Custom Tabs'));
    expect(ios, contains('Facebook OAuth via Supabase SFSafariViewController'));
    expect(android, contains('BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID'));
    expect(ios, contains('BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID'));
    expect(
      read('.github/workflows/bil_ios_unsigned_release.yml'),
      isNot(contains('--dart-define=BIL_ENVIRONMENT=production')),
    );
  });

  test(
    'Facebook login remains fail-closed outside reviewed release builds',
    () {
      final environment = read('lib/app/environment/app_environment.dart');
      for (final define in <String>[
        'BIL_FACEBOOK_LOGIN_ENABLED',
        'BIL_FACEBOOK_LOGIN_READY',
      ]) {
        expect(
          environment,
          contains("'$define',\n    defaultValue: false"),
          reason: define,
        );
      }
    },
  );
}
