import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

final class BilPdfRenderer {
  Uint8List render(String title, List<String> lines) {
    final text = ([
      title,
      ...lines,
    ].join(' • ')).replaceAll('(', '[').replaceAll(')', ']');
    final stream = 'BT /F1 10 Tf 40 760 Td ($text) Tj ET';
    final objects = <String>[
      '1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj',
      '2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj',
      '3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj',
      '4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj',
      '5 0 obj << /Length ${stream.length} >> stream\n$stream\nendstream endobj',
    ];
    final out = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (final object in objects) {
      offsets.add(utf8.encode(out.toString()).length);
      out.writeln(object);
    }
    final xref = utf8.encode(out.toString()).length;
    out.writeln('xref\n0 ${objects.length + 1}\n0000000000 65535 f ');
    for (final offset in offsets.skip(1)) {
      out.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
    }
    out.write(
      'trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF',
    );
    return Uint8List.fromList(utf8.encode(out.toString()));
  }
}

final class BilXlsxRenderer {
  Uint8List render(List<List<Object?>> rows) {
    final archive = Archive();
    void add(String name, String content) => archive.addFile(
      ArchiveFile(name, utf8.encode(content).length, utf8.encode(content)),
    );
    add(
      '[Content_Types].xml',
      '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/></Types>',
    );
    add(
      '_rels/.rels',
      '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    );
    add(
      'xl/workbook.xml',
      '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="BIL" sheetId="1" r:id="rId1"/></sheets></workbook>',
    );
    add(
      'xl/_rels/workbook.xml.rels',
      '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
    );
    final xmlRows = rows
        .asMap()
        .entries
        .map(
          (entry) =>
              '<row r="${entry.key + 1}">${entry.value.asMap().entries.map((cell) => '<c r="${String.fromCharCode(65 + cell.key)}${entry.key + 1}" t="inlineStr"><is><t>${htmlEscape.convert('${cell.value ?? ''}')}</t></is></c>').join()}</row>',
        )
        .join();
    add(
      'xl/worksheets/sheet1.xml',
      '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>$xmlRows</sheetData></worksheet>',
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}
