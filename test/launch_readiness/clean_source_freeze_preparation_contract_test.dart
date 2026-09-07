import 'dart:io';

import 'package:body_intelligence_log/app/environment/release_manifest_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final planner = File(
    'tool/release_hygiene/prepare_clean_source_freeze.ps1',
  ).readAsStringSync();
  final verifier = File(
    'tool/release_hygiene/verify_clean_source_freeze_transfer.ps1',
  ).readAsStringSync();

  test('clean freeze preparation is fail-closed and read-only', () {
    for (final required in <String>[
      'git diff --cached --quiet',
      "git rev-parse HEAD",
      "git rev-parse 'HEAD^{tree}'",
      'status --porcelain=v1 --untracked-files=all',
      'manifest path is absent from current status',
      'current status has',
      'source bytes changed after classification',
      'deleted HEAD blob changed after classification',
      "decision -notin @('INCLUDE', 'EXCLUDE')",
      "operation = if (\$exists) { 'copy' } else { 'delete' }",
      'status_pathset_sha256',
      'include_pathset_sha256',
      'exclude_pathset_sha256',
      'source_state_sha256',
      'full_expected_pathset_sha256',
      'full_expected_state_sha256',
      'finalization_path',
      'classification_manifest_sha256',
      'classifier_sha256',
      'CLEAN_SOURCE_FREEZE_PREPARATION=PASS',
    ]) {
      expect(planner, contains(required), reason: required);
    }

    for (final forbidden in <RegExp>[
      RegExp(r'git\s+(?:-C\s+\S+\s+)?worktree\s+add'),
      RegExp(r'git\s+(?:-C\s+\S+\s+)?add(?:\s|$)'),
      RegExp(r'git\s+(?:-C\s+\S+\s+)?commit(?:\s|$)'),
      RegExp(r'git\s+(?:-C\s+\S+\s+)?push(?:\s|$)'),
      RegExp(r'git\s+(?:-C\s+\S+\s+)?reset(?:\s|$)'),
      RegExp(r'git\s+(?:-C\s+\S+\s+)?clean(?:\s|$)'),
      RegExp(r'git\s+(?:-C\s+\S+\s+)?stash(?:\s|$)'),
      RegExp(r'\bCopy-Item\b'),
      RegExp(r'\bRemove-Item\b'),
      RegExp(r'\bMove-Item\b'),
      RegExp(r'\bSet-Content\b'),
      RegExp(r'\bOut-File\b'),
      RegExp(r'\bNew-Item\b'),
      RegExp(r'\bflutter\b'),
    ]) {
      for (final script in <String>[planner, verifier]) {
        expect(script, isNot(matches(forbidden)), reason: forbidden.pattern);
      }
    }

    final jsonBranch = planner.indexOf(r'if ($EmitJson) {');
    final diagnosticsBranch = planner.indexOf(
      "Write-Host \"CLEAN_FREEZE_HEAD=\$headCommit\"",
    );
    expect(jsonBranch, greaterThanOrEqualTo(0));
    expect(diagnosticsBranch, greaterThan(jsonBranch));
    expect(
      planner.substring(jsonBranch, diagnosticsBranch),
      contains('} else {'),
      reason: '-EmitJson must emit only the plan; diagnostics belong to else.',
    );
  });

  test('clean freeze preparation rejects non-literal transfer states', () {
    expect(planner, contains("status -match '[URCT]'"));
    expect(planner, contains("status -in @('AA', 'DD')"));
    expect(planner, contains('path escapes repository'));
    expect(planner, contains('duplicate current status path'));
    expect(planner, contains('duplicate manifest path'));
    expect(planner, contains('symbolic/reparse source is unsupported'));
    expect(planner, contains('missing source is not an explicit deletion'));
    expect(planner, contains('source index is not clean'));
  });

  test(
    'transfer verifier checks full HEAD plus INCLUDE and protects EXCLUDE',
    () {
      for (final required in <String>[
        "ValidateSet('PreFinalization', 'PostFinalization')",
        'candidate cannot be the dirty source worktree',
        'candidate is not a registered side worktree',
        "ls-tree -r --full-tree HEAD",
        'full HEAD plus INCLUDE overlay is inconsistent',
        'Get-ChildItem -LiteralPath \$candidate -Recurse -Force -File',
        'full candidate path mismatch',
        'Get-GitBlobOid -AbsolutePath',
        'full candidate hash mismatches',
        'candidate status count differs from INCLUDE operations',
        'tracked EXCLUDE baseline is missing',
        'untracked EXCLUDE crossed into candidate',
        'final manifest marker is invalid',
        'CLEAN_TRANSFER_UNEXPECTED=0',
        'CLEAN_TRANSFER_MISSING=0',
        'CLEAN_TRANSFER_HASH_MISMATCH=0',
        'CLEAN_TRANSFER_EXCLUDE_VIOLATION=0',
        'CLEAN_SOURCE_TRANSFER_VERIFICATION=PASS',
      ]) {
        expect(verifier, contains(required), reason: required);
      }
    },
  );

  test(
    'validator targets the current non-self-referential Android 9 manifest',
    () {
      const currentManifestPath =
          'docs/release/BIL_ANDROID_V9_FROZEN_SOURCE_MANIFEST_2026-09-06.md';
      final validator = File(
        'tool/release/validate_release_configuration.dart',
      ).readAsStringSync();
      final manifestSource = File(currentManifestPath).readAsStringSync();
      final metadata = ReleaseManifestMetadata.parse(manifestSource);

      expect(validator, contains(currentManifestPath));
      expect(
        validator,
        isNot(contains('BIL_PLUS8_STAGING_MANIFEST_2026-09-05.md')),
      );
      expect(metadata.unresolvedReviewCount, 0);
      expect(metadata.releaseVersion, '1.0.0');
      expect(metadata.releaseBuildNumber, 9);
      expect(
        metadata.stagingManifestComplete,
        metadata.candidateFrozenOrAccepted,
        reason: 'The current manifest must transition from NO/NO to YES/YES.',
      );
      expect(manifestSource, contains('BIL_ANDROID_V9_AUDITED_SOURCE_SHA'));
      expect(
        manifestSource,
        contains('BIL_ANDROID_V9_STAGING_MANIFEST_SHA256'),
      );
      expect(manifestSource, contains('not self-referential'));
    },
  );
}
