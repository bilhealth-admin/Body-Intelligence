import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/visual_reference_evidence_verifier.dart' as verifier;

const _referenceRoot = 'artifacts/release/visual_closure/reference';
final _hostOnlyVisualEvidenceAvailable = <String>[
  '$_referenceRoot/visual_reference_manifest.json',
  '$_referenceRoot/visual_reference_coverage.csv',
  '$_referenceRoot/visual_reference_truth_matrix.csv',
].every((path) => File(path).existsSync());

void main() {
  test(
    'visual evidence check is truthful and read-only',
    () async {
      const manifest = '$_referenceRoot/visual_reference_manifest.json';
      const coverage = '$_referenceRoot/visual_reference_coverage.csv';
      const truth = '$_referenceRoot/visual_reference_truth_matrix.csv';
      final manifestBefore = File(manifest).readAsStringSync();
      final coverageBefore = File(coverage).readAsStringSync();
      final truthBefore = File(truth).readAsStringSync();

      final summary = verifier.verifyVisualReferenceEvidence();

      expect(summary.synchronized, isFalse);
      expect(summary.artifacts, 177);
      expect(summary.approvedVisualEquivalence, 44);
      expect(summary.externalValidationPending, 34);
      expect(summary.uniqueVisualEvidence, 161);
      expect(File(manifest).readAsStringSync(), manifestBefore);
      expect(File(coverage).readAsStringSync(), coverageBefore);
      expect(File(truth).readAsStringSync(), truthBefore);
    },
    skip: _hostOnlyVisualEvidenceAvailable
        ? false
        : 'Requires the untracked, independently reviewed visual truth matrix.',
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
