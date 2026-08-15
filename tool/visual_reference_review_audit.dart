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
  values.add(current.toString());
  return values;
}

void main() {
  final root = Directory.current.path;
  final coverage = File(
    '$root/artifacts/release/visual_closure/reference/'
    'visual_reference_coverage.csv',
  );
  final review = File('$root/docs/BIL_VISUAL_REVIEW_2026-08-05.md');
  if (!coverage.existsSync() || !review.existsSync()) {
    throw StateError('Visual coverage or manual review record is missing.');
  }
  final lines = coverage
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.length != 178) {
    throw StateError('Expected 177 visual reference rows.');
  }
  final header = parseCsvLine(lines.first);
  final evidenceColumn = header.indexOf('evidence_after');
  final statusColumn = header.indexOf('status');
  if (evidenceColumn < 0 || statusColumn < 0) {
    throw StateError('Coverage columns are incomplete.');
  }
  final rows = lines.skip(1).map(parseCsvLine).toList();
  final evidence = rows.map((row) => row[evidenceColumn]).toSet();
  final reviewText = review.readAsStringSync();
  if (!reviewText.contains('Decision: `PASS`')) {
    throw StateError('Manual visual review is not approved.');
  }
  for (final path in evidence) {
    if (!reviewText.contains('- $path')) {
      throw StateError('Manual visual review does not list $path.');
    }
    final file = File('$root/$path');
    if (!file.existsSync() || file.lengthSync() < 1000) {
      throw StateError('Reviewed evidence is missing or empty: $path');
    }
  }
  for (final row in rows) {
    if (!row[statusColumn].startsWith('verified production golden')) {
      throw StateError('Reference evidence has not passed verification.');
    }
  }
  stdout.writeln('VISUAL_MANUAL_REVIEW=PASS');
  stdout.writeln('REVIEWED_REFERENCES=${rows.length}');
  stdout.writeln('REVIEWED_UNIQUE_EVIDENCE=${evidence.length}');
}
