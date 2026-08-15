import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

final class ReportSection {
  const ReportSection({
    required this.id,
    required this.title,
    required this.facts,
    required this.estimates,
    required this.confidence,
    required this.provenance,
  });
  final String id, title, provenance;
  final List<String> facts, estimates;
  final double confidence;
}

final class ScientificReport {
  ScientificReport({
    required this.id,
    required this.locale,
    required this.sections,
    required DateTime from,
    required DateTime to,
  }) : from = from.toUtc(),
       to = to.toUtc();
  final String id, locale;
  final List<ReportSection> sections;
  final DateTime from, to;

  void validate() {
    if (id.trim().isEmpty) throw ArgumentError.value(id, 'id');
    if (locale.trim().isEmpty) throw ArgumentError.value(locale, 'locale');
    if (to.isBefore(from)) {
      throw ArgumentError('Report end cannot precede its start.');
    }
    for (final section in sections) {
      if (section.id.trim().isEmpty || section.title.trim().isEmpty) {
        throw ArgumentError('Report sections require an id and title.');
      }
      if (!section.confidence.isFinite ||
          section.confidence < 0 ||
          section.confidence > 1) {
        throw ArgumentError.value(section.confidence, 'confidence');
      }
      if (section.provenance.trim().isEmpty) {
        throw ArgumentError('Every report section requires provenance.');
      }
      if (section.facts.isEmpty && section.estimates.isEmpty) {
        throw ArgumentError('A report section cannot be empty.');
      }
    }
  }
}

final class ScientificReportRuntime {
  Uint8List pdf(ScientificReport report) {
    report.validate();
    final text = _plainText(
      report,
    ).replaceAll('(', r'\(').replaceAll(')', r'\)');
    final content =
        'BT /F1 10 Tf 50 780 Td (${text.replaceAll('\n', ') Tj 0 -14 Td (')}) Tj ET';
    final objects = <String>[
      '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj',
      '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj',
      '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj',
      '4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj',
      '5 0 obj << /Length ${utf8.encode(content).length} >> stream\n$content\nendstream endobj',
    ];
    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (final object in objects) {
      offsets.add(utf8.encode(buffer.toString()).length);
      buffer.writeln(object);
    }
    final xref = utf8.encode(buffer.toString()).length;
    buffer.writeln('xref');
    buffer.writeln('0 ${objects.length + 1}');
    buffer.writeln('0000000000 65535 f ');
    for (final offset in offsets.skip(1)) {
      buffer.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
    }
    buffer.writeln('trailer << /Size ${objects.length + 1} /Root 1 0 R >>');
    buffer.writeln('startxref');
    buffer.writeln(xref);
    buffer.writeln('%%EOF');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Uint8List xlsx(ScientificReport report) {
    report.validate();
    final archive = Archive();
    void add(String name, String value) =>
        archive.addFile(ArchiveFile.string(name, value));
    add(
      '[Content_Types].xml',
      '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
    );
    add(
      '_rels/.rels',
      '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    );
    add(
      'xl/workbook.xml',
      '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="BIL Report" sheetId="1" r:id="rId1"/></sheets></workbook>',
    );
    add(
      'xl/_rels/workbook.xml.rels',
      '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
    );
    final rows = <List<String>>[
      <String>['Section', 'Type', 'Value', 'Confidence', 'Provenance'],
      for (final section in report.sections) ...<List<String>>[
        for (final fact in section.facts)
          <String>[
            section.title,
            'fact',
            fact,
            '${section.confidence}',
            section.provenance,
          ],
        for (final estimate in section.estimates)
          <String>[
            section.title,
            'estimate',
            estimate,
            '${section.confidence}',
            section.provenance,
          ],
      ],
    ];
    final xmlRows = <String>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final cells = <String>[];
      for (
        var columnIndex = 0;
        columnIndex < rows[rowIndex].length;
        columnIndex++
      ) {
        final reference =
            '${String.fromCharCode(65 + columnIndex)}${rowIndex + 1}';
        final escaped = const HtmlEscape().convert(rows[rowIndex][columnIndex]);
        cells.add(
          '<c r="$reference" t="inlineStr"><is><t>$escaped</t></is></c>',
        );
      }
      xmlRows.add('<row r="${rowIndex + 1}">${cells.join()}</row>');
    }
    add(
      'xl/worksheets/sheet1.xml',
      '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${xmlRows.join()}</sheetData></worksheet>',
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Uint8List csv(ScientificReport report) {
    report.validate();
    return Uint8List.fromList(
      utf8.encode(
        'section,type,value,confidence,provenance\n${[
          for (final section in report.sections) ...[for (final fact in section.facts) '"${_csv(section.title)}",fact,"${_csv(fact)}",${section.confidence},"${_csv(section.provenance)}"', for (final estimate in section.estimates) '"${_csv(section.title)}",estimate,"${_csv(estimate)}",${section.confidence},"${_csv(section.provenance)}"'],
        ].join('\n')}',
      ),
    );
  }

  Uint8List json(ScientificReport report) {
    report.validate();
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'id': report.id,
          'locale': report.locale,
          'from': report.from.toIso8601String(),
          'to': report.to.toIso8601String(),
          'sections': [
            for (final section in report.sections)
              <String, Object?>{
                'id': section.id,
                'title': section.title,
                'facts': section.facts,
                'estimates': section.estimates,
                'confidence': section.confidence,
                'provenance': section.provenance,
              },
          ],
        }),
      ),
    );
  }

  String _csv(String value) => value.replaceAll('"', '""');
  String _plainText(ScientificReport report) => [
    'BIL Scientific Report ${report.id}',
    '${report.from.toIso8601String()} - ${report.to.toIso8601String()}',
    for (final section in report.sections)
      '${section.title}\nFacts: ${section.facts.join('; ')}\nEstimates: ${section.estimates.join('; ')}\nConfidence: ${section.confidence}\nProvenance: ${section.provenance}',
  ].join('\n');
}
