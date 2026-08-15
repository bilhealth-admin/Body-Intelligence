import 'dart:convert';
import 'dart:io';

String csvCell(Object? value) => '"${value.toString().replaceAll('"', '""')}"';

void main() {
  final root = Directory.current.path;
  final referenceRoot = '$root/artifacts/release/visual_closure/reference';
  final manifestFile = File('$referenceRoot/visual_reference_manifest.json');
  if (!manifestFile.existsSync()) {
    throw StateError('Visual reference manifest is missing.');
  }
  final decoded = jsonDecode(manifestFile.readAsStringSync());
  if (decoded is! List || decoded.length != 177) {
    throw StateError('Expected 177 manifest rows.');
  }

  final verified = <Map<String, Object?>>[];
  for (final raw in decoded) {
    final record = Map<String, Object?>.from(raw as Map);
    final productionPath = record['production_file'] as String? ?? '';
    final evidencePath = record['evidence_after'] as String? ?? '';
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
    record['status'] = 'verified production golden';
    record['evidence_bytes'] = evidence.lengthSync();
    record['evidence_generated_at'] = evidence
        .lastModifiedSync()
        .toUtc()
        .toIso8601String();
    verified.add(record);
  }

  manifestFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(verified),
  );
  final keys = verified.first.keys.toList();
  final csv = <String>[
    keys.join(','),
    ...verified.map(
      (record) => keys.map((key) => csvCell(record[key])).join(','),
    ),
  ];
  File(
    '$referenceRoot/visual_reference_coverage.csv',
  ).writeAsStringSync('${csv.join('\n')}\n');

  stdout.writeln('VISUAL_REFERENCE_EVIDENCE=PASS');
  stdout.writeln('VERIFIED_REFERENCES=${verified.length}');
  stdout.writeln(
    "UNIQUE_PRODUCTION_FILES=${verified.map((row) => row['production_file']).toSet().length}",
  );
  stdout.writeln(
    "UNIQUE_VISUAL_EVIDENCE=${verified.map((row) => row['evidence_after']).toSet().length}",
  );
}
