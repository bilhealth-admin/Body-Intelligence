import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'arabic_vector_pdf_renderer.dart';
import 'scientific_reports_platform.dart';

final class ReportTheme {
  const ReportTheme({
    required this.rtl,
    required this.locale,
    required this.title,
    required this.footer,
  });

  final bool rtl;
  final String locale;
  final String title;
  final String footer;
}

final class ReportRenderResult {
  const ReportRenderResult({
    required this.pdf,
    required this.xlsx,
    required this.csv,
    required this.json,
  });

  final Uint8List pdf;
  final Uint8List xlsx;
  final Uint8List csv;
  final Uint8List json;
}

final class WorldClassReportRuntime {
  WorldClassReportRuntime({required this.pdfRenderer});

  final ArabicVectorPdfRenderer pdfRenderer;

  Future<ReportRenderResult> render(
    ScientificReport report, {
    required ReportTheme theme,
  }) async => ReportRenderResult(
    pdf: await pdfRenderer.render(
      report,
      title: theme.title,
      footer: theme.footer,
    ),
    xlsx: _xlsx(report, theme),
    csv: ScientificReportRuntime().csv(report),
    json: ScientificReportRuntime().json(report),
  );

  Uint8List _xlsx(ScientificReport report, ReportTheme theme) {
    final archive = Archive();
    void add(String name, String content) {
      final file = ArchiveFile.string(name, content)
        ..lastModTime = DateTime.utc(1980).millisecondsSinceEpoch ~/ 1000;
      archive.addFile(file);
    }

    add('[Content_Types].xml', '''<?xml version="1.0"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
</Types>''');
    add('_rels/.rels', '''<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
</Relationships>''');
    add('docProps/core.xml', '''<?xml version="1.0" encoding="UTF-8"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:title>${const HtmlEscape().convert(theme.title)}</dc:title>
<dc:creator>Body Intelligence Log</dc:creator>
<dc:language>${theme.locale}</dc:language>
</cp:coreProperties>''');
    add('xl/workbook.xml', '''<?xml version="1.0"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<workbookPr date1904="false"/><bookViews><workbookView/></bookViews>
<sheets><sheet name="Summary" sheetId="1" r:id="rId1"/><sheet name="Evidence" sheetId="2" r:id="rId2"/></sheets>
</workbook>''');
    add('xl/_rels/workbook.xml.rels', '''<?xml version="1.0"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''');
    add('xl/styles.xml', '''<?xml version="1.0"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="1"><numFmt numFmtId="164" formatCode="yyyy-mm-dd hh:mm"/></numFmts>
<fonts count="3"><font/><font><b/></font><font><b/><sz val="14"/></font></fonts>
<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFD9EAF7"/></patternFill></fill></fills>
<borders count="1"><border/></borders>
<cellXfs count="4"><xf/><xf fontId="1" fillId="1" applyFill="1"/><xf fontId="2"/><xf numFmtId="164" applyNumberFormat="1"/></cellXfs>
</styleSheet>''');
    add(
      'xl/worksheets/sheet1.xml',
      _sheet(
        <List<String>>[
          <String>['BIL Report', theme.title],
          <String>['Locale', theme.locale],
          <String>['Direction', theme.rtl ? 'RTL' : 'LTR'],
          <String>['From', report.from.toIso8601String()],
          <String>['To', report.to.toIso8601String()],
        ],
        freeze: true,
        rtl: theme.rtl,
      ),
    );
    final rows = <List<String>>[
      <String>['Section', 'Type', 'Value', 'Confidence', 'Provenance'],
    ];
    for (final section in report.sections) {
      for (final fact in section.facts) {
        rows.add(<String>[
          section.title,
          'Fact',
          fact,
          '${section.confidence}',
          section.provenance,
        ]);
      }
      for (final estimate in section.estimates) {
        rows.add(<String>[
          section.title,
          'Estimate',
          estimate,
          '${section.confidence}',
          section.provenance,
        ]);
      }
    }
    add('xl/worksheets/sheet2.xml', _sheet(rows, freeze: true, rtl: theme.rtl));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  String _sheet(
    List<List<String>> rows, {
    required bool freeze,
    required bool rtl,
  }) {
    final xml = rows.asMap().entries.map((row) {
      return '<row r="${row.key + 1}">${row.value.asMap().entries.map((cell) {
        final column = String.fromCharCode(65 + cell.key);
        return '<c r="$column${row.key + 1}" t="inlineStr" s="${row.key == 0 ? 1 : 0}"><is><t xml:space="preserve">${const HtmlEscape().convert(cell.value)}</t></is></c>';
      }).join()}</row>';
    }).join();
    return '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetViews><sheetView workbookViewId="0" rightToLeft="${rtl ? 1 : 0}">${freeze ? '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>' : ''}</sheetView></sheetViews>
<cols><col min="1" max="5" width="28" customWidth="1"/></cols>
<sheetData>$xml</sheetData>
<autoFilter ref="A1:E${rows.length}"/>
</worksheet>''';
  }
}
