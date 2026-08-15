import 'dart:io';

List<String> parseCsvLine(String line) {
  final values = <String>[];
  final current = StringBuffer();
  var quoted = false;
  for (var index = 0; index < line.length; index++) {
    final char = line[index];
    if (char == '"') {
      if (quoted && index + 1 < line.length && line[index + 1] == '"') {
        current.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      values.add(current.toString());
      current.clear();
    } else {
      current.write(char);
    }
  }
  if (quoted) {
    throw const FormatException('Unterminated quoted CSV value.');
  }
  values.add(current.toString());
  return values;
}

Never _fail(String message) => throw StateError(message);

void main() {
  final root = Directory.current.path;
  final matrix = File(
    '$root/artifacts/release/visual_closure/reference/'
    'visual_reference_truth_matrix.csv',
  );
  if (!matrix.existsSync()) {
    _fail('The authoritative visual reference truth matrix is missing.');
  }

  final lines = matrix
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.length != 178) {
    _fail('Expected exactly 177 visual reference rows.');
  }

  final header = parseCsvLine(lines.first);
  const requiredColumns = <String>{
    'reference',
    'evidence_after',
    'external_blocker',
    'visual_review_status',
  };
  final missing = requiredColumns.difference(header.toSet());
  if (missing.isNotEmpty) {
    _fail('Truth matrix columns are incomplete: ${missing.join(', ')}');
  }

  final rows = lines.skip(1).map(parseCsvLine).toList();
  final referenceColumn = header.indexOf('reference');
  final evidenceColumn = header.indexOf('evidence_after');
  final blockerColumn = header.indexOf('external_blocker');
  final reviewColumn = header.indexOf('visual_review_status');
  final references = <String>{};
  final evidence = <String>{};
  var unverified = 0;
  var externalPending = 0;

  for (final row in rows) {
    if (row.length != header.length) {
      _fail('Truth matrix contains a malformed row.');
    }
    final reference = row[referenceColumn].trim();
    if (reference.isEmpty || !references.add(reference)) {
      _fail('Reference identifiers must be non-empty and unique: $reference');
    }

    final evidencePath = row[evidenceColumn].trim();
    if (evidencePath.isEmpty) {
      _fail('Reference $reference has no production evidence path.');
    }
    evidence.add(evidencePath);
    final evidenceFile = File('$root/$evidencePath');
    if (!evidenceFile.existsSync() || evidenceFile.lengthSync() < 1000) {
      _fail('Reference $reference evidence is missing or empty: $evidencePath');
    }

    if (row[reviewColumn].trim() != 'approved_visual_equivalence') {
      unverified++;
    }
    if (row[blockerColumn].trim().isNotEmpty) {
      externalPending++;
    }
  }

  stdout.writeln('REVIEWED_REFERENCES=${rows.length}');
  stdout.writeln('REVIEWED_UNIQUE_EVIDENCE=${evidence.length}');
  stdout.writeln('UNVERIFIED_REFERENCES=$unverified');
  stdout.writeln('EXTERNAL_VALIDATION_PENDING=$externalPending');

  if (unverified > 0 || externalPending > 0) {
    stdout.writeln('VISUAL_MANUAL_REVIEW=FAIL');
    stderr.writeln(
      'Visual closure is not approved: $unverified references still require '
      'visual-equivalence approval and $externalPending require external '
      'device/account validation.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln('VISUAL_MANUAL_REVIEW=PASS');
}
