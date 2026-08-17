import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

final class VisualEvidenceSummary {
  const VisualEvidenceSummary({
    required this.artifacts,
    required this.approvedVisualEquivalence,
    required this.externalValidationPending,
    required this.uniqueProductionFiles,
    required this.uniqueVisualEvidence,
    required this.synchronized,
  });

  final int artifacts;
  final int approvedVisualEquivalence;
  final int externalValidationPending;
  final int uniqueProductionFiles;
  final int uniqueVisualEvidence;
  final bool synchronized;
}

String csvCell(Object? value) => '"${value.toString().replaceAll('"', '""')}"';

List<String> _csvRow(String line) {
  final values = <String>[];
  final value = StringBuffer();
  var quoted = false;
  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (character == '"') {
      if (quoted && index + 1 < line.length && line[index + 1] == '"') {
        value.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (character == ',' && !quoted) {
      values.add(value.toString());
      value.clear();
    } else {
      value.write(character);
    }
  }
  if (quoted) throw const FormatException('Unterminated quoted CSV field.');
  values.add(value.toString());
  return values;
}

List<Map<String, String>> _readCsv(File file) {
  if (!file.existsSync()) throw StateError('Missing ${file.path}.');
  final lines = file
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);
  if (lines.length < 2) throw StateError('Empty CSV: ${file.path}.');
  final headers = _csvRow(lines.first);
  return lines
      .skip(1)
      .map((line) {
        final values = _csvRow(line);
        if (values.length != headers.length) {
          throw FormatException(
            'CSV column mismatch in ${file.path}: '
            '${values.length} values for ${headers.length} headers.',
          );
        }
        return <String, String>{
          for (var index = 0; index < headers.length; index++)
            headers[index]: values[index],
        };
      })
      .toList(growable: false);
}

void _writeCsv(File file, List<Map<String, String>> rows) {
  if (rows.isEmpty) {
    throw StateError('Cannot write an empty CSV: ${file.path}.');
  }
  final headers = rows.first.keys.toList(growable: false);
  final csv = <String>[
    headers.map(csvCell).join(','),
    ...rows.map(
      (row) => headers.map((header) => csvCell(row[header] ?? '')).join(','),
    ),
  ];
  file.writeAsStringSync('${csv.join('\n')}\n');
}

VisualEvidenceSummary verifyVisualReferenceEvidence({
  String? rootPath,
  bool synchronize = false,
}) {
  final root = rootPath ?? Directory.current.path;
  final referenceRoot = '$root/artifacts/release/visual_closure/reference';
  final manifestFile = File('$referenceRoot/visual_reference_manifest.json');
  final coverageFile = File('$referenceRoot/visual_reference_coverage.csv');
  final truthFile = File('$referenceRoot/visual_reference_truth_matrix.csv');
  if (!manifestFile.existsSync()) {
    throw StateError('Visual reference manifest is missing.');
  }
  final decoded = jsonDecode(manifestFile.readAsStringSync());
  if (decoded is! List || decoded.length != 177) {
    throw StateError('Expected 177 manifest rows.');
  }
  final truthRows = _readCsv(truthFile);
  final coverageRows = _readCsv(coverageFile);
  if (truthRows.length != 177) {
    throw StateError('Expected 177 visual truth rows.');
  }
  if (coverageRows.length != 177) {
    throw StateError('Expected 177 visual coverage rows.');
  }
  final truthByReference = <String, Map<String, String>>{};
  for (final row in truthRows) {
    final reference = row['reference']?.trim() ?? '';
    if (reference.isEmpty || truthByReference.containsKey(reference)) {
      throw StateError('Invalid or duplicate truth reference: $reference.');
    }
    truthByReference[reference] = row;
  }
  final coverageByReference = <String, Map<String, String>>{};
  for (final row in coverageRows) {
    final reference = row['reference']?.trim() ?? '';
    if (reference.isEmpty || coverageByReference.containsKey(reference)) {
      throw StateError('Invalid or duplicate coverage reference: $reference.');
    }
    coverageByReference[reference] = row;
  }

  final synchronized = <Map<String, Object?>>[];
  final seen = <String>{};
  for (final raw in decoded) {
    final record = Map<String, Object?>.from(raw as Map);
    final reference = '${record['reference']}'.trim();
    final truth = truthByReference[reference];
    final coverage = coverageByReference[reference];
    if (truth == null || coverage == null || !seen.add(reference)) {
      throw StateError('Missing or duplicate manifest reference: $reference.');
    }
    final productionPath = truth['production_file']?.trim() ?? '';
    final evidencePath = truth['evidence_after']?.trim() ?? '';
    final route = truth['route']?.trim() ?? '';
    final visualStatus = truth['visual_review_status']?.trim() ?? '';
    if (productionPath.isEmpty ||
        evidencePath.isEmpty ||
        route.isEmpty ||
        visualStatus.isEmpty) {
      throw StateError('Incomplete truth row for reference $reference.');
    }
    final production = File('$root/$productionPath');
    final evidence = File('$root/$evidencePath');
    if (!production.existsSync()) {
      throw StateError('Missing production file: $productionPath');
    }
    if (!evidence.existsSync() || evidence.lengthSync() < 1000) {
      throw StateError('Missing or empty visual evidence: $evidencePath');
    }
    final signature = evidence.openSync()..setPositionSync(0);
    final header = signature.readSync(8);
    signature.closeSync();
    const png = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (header.length != png.length ||
        List.generate(
          png.length,
          (index) => header[index] == png[index],
        ).contains(false)) {
      throw StateError('Evidence is not a PNG: $evidencePath');
    }
    final evidenceSha256 = sha256
        .convert(evidence.readAsBytesSync())
        .toString();
    final evidenceBytes = evidence.lengthSync();

    // Artifact integrity and visual-equivalence approval are separate facts.
    // Only the independently reviewed truth matrix may supply the status.
    if (!synchronize &&
        (record['bil_route'] != route ||
            record['production_file'] != productionPath ||
            record['evidence_after'] != evidencePath ||
            record['status'] != visualStatus ||
            record['evidence_bytes'] != evidenceBytes ||
            record['evidence_sha256'] != evidenceSha256 ||
            truth['evidence_bytes'] != '$evidenceBytes' ||
            coverage['bil_route'] != route ||
            coverage['production_file'] != productionPath ||
            coverage['evidence_after'] != evidencePath ||
            coverage['status'] != visualStatus ||
            coverage['evidence_bytes'] != '$evidenceBytes' ||
            coverage['evidence_sha256'] != evidenceSha256)) {
      throw StateError(
        'Manifest metadata differs from truth for reference $reference. '
        'Review the truth row, then run with --sync.',
      );
    }
    record['bil_route'] = route;
    record['production_file'] = productionPath;
    record['evidence_after'] = evidencePath;
    record['status'] = visualStatus;
    record['evidence_bytes'] = evidenceBytes;
    record.remove('evidence_generated_at');
    record['evidence_sha256'] = evidenceSha256;
    truth['evidence_bytes'] = '$evidenceBytes';
    synchronized.add(record);
  }
  if (seen.length != truthByReference.length) {
    throw StateError('Manifest and truth references do not match exactly.');
  }

  if (synchronize) {
    manifestFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(synchronized)}\n',
    );
    final keys = synchronized.first.keys.toList();
    final csv = <String>[
      keys.join(','),
      ...synchronized.map(
        (record) => keys.map((key) => csvCell(record[key])).join(','),
      ),
    ];
    File(
      '$referenceRoot/visual_reference_coverage.csv',
    ).writeAsStringSync('${csv.join('\n')}\n');
    _writeCsv(truthFile, truthRows);
  }

  final exact = truthRows
      .where(
        (row) => row['visual_review_status'] == 'approved_visual_equivalence',
      )
      .length;
  final externallyBlocked = truthRows
      .where((row) => (row['external_blocker'] ?? '').trim().isNotEmpty)
      .length;
  return VisualEvidenceSummary(
    artifacts: synchronized.length,
    approvedVisualEquivalence: exact,
    externalValidationPending: externallyBlocked,
    uniqueProductionFiles: synchronized
        .map((row) => row['production_file'])
        .toSet()
        .length,
    uniqueVisualEvidence: synchronized
        .map((row) => row['evidence_after'])
        .toSet()
        .length,
    synchronized: synchronize,
  );
}

void main(List<String> arguments) {
  final synchronize = arguments.contains('--sync');
  final unsupported = arguments.where((value) => value != '--sync').toList();
  if (unsupported.isNotEmpty) {
    throw ArgumentError('Unsupported arguments: ${unsupported.join(', ')}');
  }
  final summary = verifyVisualReferenceEvidence(synchronize: synchronize);
  stdout.writeln('VISUAL_REFERENCE_EVIDENCE=PASS');
  stdout.writeln('MODE=${summary.synchronized ? 'SYNC' : 'CHECK'}');
  stdout.writeln('VERIFIED_ARTIFACTS=${summary.artifacts}');
  stdout.writeln(
    'APPROVED_VISUAL_EQUIVALENCE=${summary.approvedVisualEquivalence}',
  );
  stdout.writeln(
    'EXTERNAL_VALIDATION_PENDING=${summary.externalValidationPending}',
  );
  stdout.writeln('UNIQUE_PRODUCTION_FILES=${summary.uniqueProductionFiles}');
  stdout.writeln('UNIQUE_VISUAL_EVIDENCE=${summary.uniqueVisualEvidence}');
}
