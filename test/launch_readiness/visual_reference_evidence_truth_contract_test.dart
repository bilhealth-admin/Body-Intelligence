import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/visual_reference_evidence_verifier.dart' as verifier;

const _referenceRoot = 'artifacts/release/visual_closure/reference';
const _historicalFixtureRoot =
    'test/fixtures/visual_reference_history_preserved_owner_source';

void main() {
  test(
    'preserved historical owner visual evidence is truthful and read-only',
    () async {
      // This preserved dataset tests metadata integrity, not current UI approval.
      // Real historical Dart bytes are reconstructed only outside the project.
      final provenance =
          jsonDecode(
                File(
                  '$_historicalFixtureRoot/provenance.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        provenance['dataset_scope'],
        'preserved_historical_owner_reference_dataset',
      );
      expect(provenance['not_git_2c518ee4_snapshot'], isTrue);
      expect(provenance['not_current_polish_evidence'], isTrue);
      expect(provenance['not_store_or_device_evidence'], isTrue);
      expect(provenance['no_new_visual_approvals'], isTrue);

      final temporaryRoot = Directory.systemTemp.createTempSync(
        'bil-preserved-visual-reference-',
      );
      addTearDown(() => temporaryRoot.delete(recursive: true));
      final records = (provenance['files'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final beforeHashes = <String, String>{};
      for (final record in records) {
        final repositoryPath = record['repository_path'] as String;
        final fixturePath = record['fixture_path'] as String;
        for (final relativePath in <String>[repositoryPath, fixturePath]) {
          expect(relativePath, isNot(startsWith('/')));
          expect(relativePath, isNot(contains(':')));
          expect(relativePath, isNot(contains(r'\')));
          expect(relativePath.split('/'), isNot(contains('..')));
        }
        if (record['kind'] == 'production_source_text') {
          expect(fixturePath, endsWith('.dart.txt'));
        }
        final original = File('$_historicalFixtureRoot/$fixturePath');
        final bytes = original.readAsBytesSync();
        final digest = sha256.convert(bytes).toString();
        expect(bytes.length, record['bytes'], reason: repositoryPath);
        expect(digest, record['sha256'], reason: repositoryPath);
        beforeHashes[repositoryPath] = digest;
        final reconstructed = File('${temporaryRoot.path}/$repositoryPath');
        reconstructed.parent.createSync(recursive: true);
        reconstructed.writeAsBytesSync(bytes);
      }

      final manifest =
          '${temporaryRoot.path}/$_referenceRoot/visual_reference_manifest.json';
      final coverage =
          '${temporaryRoot.path}/$_referenceRoot/visual_reference_coverage.csv';
      final truth =
          '${temporaryRoot.path}/$_referenceRoot/visual_reference_truth_matrix.csv';
      final manifestBefore = File(manifest).readAsStringSync();
      final coverageBefore = File(coverage).readAsStringSync();
      final truthBefore = File(truth).readAsStringSync();

      final summary = verifier.verifyVisualReferenceEvidence(
        rootPath: temporaryRoot.path,
      );

      expect(summary.synchronized, isFalse);
      expect(summary.artifacts, 177);
      expect(summary.approvedVisualEquivalence, 44);
      expect(summary.externalValidationPending, 34);
      expect(summary.uniqueVisualEvidence, 161);
      expect(File(manifest).readAsStringSync(), manifestBefore);
      expect(File(coverage).readAsStringSync(), coverageBefore);
      expect(File(truth).readAsStringSync(), truthBefore);
      for (final record in records) {
        final repositoryPath = record['repository_path'] as String;
        final fixturePath = record['fixture_path'] as String;
        expect(
          sha256
              .convert(
                File('$_historicalFixtureRoot/$fixturePath').readAsBytesSync(),
              )
              .toString(),
          beforeHashes[repositoryPath],
          reason: 'Preserved original changed: $repositoryPath',
        );
        expect(
          sha256
              .convert(
                File('${temporaryRoot.path}/$repositoryPath').readAsBytesSync(),
              )
              .toString(),
          beforeHashes[repositoryPath],
          reason: 'Read-only verification changed: $repositoryPath',
        );
      }
    },
  );

  test('artifact existence never upgrades visual-equivalence status', () {
    final source = File(
      'tool/visual_reference_evidence_verifier.dart',
    ).readAsStringSync();
    expect(
      source,
      isNot(contains("record['status'] = 'verified production golden'")),
    );
    expect(source, contains("truth['visual_review_status']"));
    expect(source, contains("record['evidence_sha256']"));
    expect(source, contains(r"truth['evidence_bytes'] != '$evidenceBytes'"));
    expect(source, contains(r"truth['evidence_bytes'] = '$evidenceBytes'"));
    expect(source, contains('_writeCsv(truthFile, truthRows)'));
    expect(source, isNot(contains("record['evidence_generated_at']")));
  });
}
