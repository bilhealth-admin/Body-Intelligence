import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'scientific_reports_platform.dart';

/// Arabic PDF renderer backed by embedded Noto Naskh Arabic font programs.
/// The caller supplies licensed font bytes, making output independent of host fonts.
final class ArabicVectorPdfRenderer {
  ArabicVectorPdfRenderer({
    required Uint8List regularFont,
    required Uint8List boldFont,
  }) : _regular = pw.Font.ttf(ByteData.sublistView(regularFont)),
       _bold = pw.Font.ttf(ByteData.sublistView(boldFont));

  final pw.Font _regular;
  final pw.Font _bold;

  Future<Uint8List> render(
    ScientificReport report, {
    required String title,
    required String footer,
  }) async {
    final document = pw.Document(
      version: PdfVersion.pdf_1_4,
      title: title,
      author: 'Body Intelligence Log',
      subject: 'Explainable health report',
      creator: 'BIL Arabic Report Runtime — Noto Naskh Arabic (SIL OFL)',
      compress: false,
    );
    final theme = pw.ThemeData.withFont(base: _regular, bold: _bold);
    document.addPage(
      pw.MultiPage(
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (_) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(title, style: pw.TextStyle(font: _bold, fontSize: 18)),
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(footer),
            pw.Text('${context.pageNumber}/${context.pagesCount}'),
          ],
        ),
        build: (_) => <pw.Widget>[
          pw.Text(
            '${report.from.toIso8601String()} — ${report.to.toIso8601String()}',
          ),
          pw.SizedBox(height: 12),
          for (final section in report.sections) ...<pw.Widget>[
            pw.Header(
              level: 1,
              text: section.title,
              textStyle: pw.TextStyle(font: _bold, fontSize: 15),
            ),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(font: _bold),
              cellStyle: pw.TextStyle(font: _regular),
              headers: const <String>['النوع', 'المعلومة'],
              data: <List<String>>[
                for (final fact in section.facts) <String>['حقيقة', fact],
                for (final estimate in section.estimates)
                  <String>['تقدير', estimate],
                <String>['الثقة', '${(section.confidence * 100).round()}%'],
                <String>['المصدر', section.provenance],
              ],
              cellAlignment: pw.Alignment.centerRight,
            ),
            pw.SizedBox(height: 10),
          ],
        ],
      ),
    );
    return _normalizeDeterministicMetadata(await document.save());
  }

  Uint8List _normalizeDeterministicMetadata(Uint8List bytes) {
    var source = String.fromCharCodes(bytes);
    source = source.replaceAllMapped(
      RegExp(r'/CreationDate\(D:[^)]+\)'),
      (match) => '/CreationDate(${''.padLeft(match[0]!.length - 15, '0')})',
    );
    source = source.replaceAllMapped(RegExp(r'/ID\[<([^>]+)><([^>]+)>\]'), (
      match,
    ) {
      final first = ''.padLeft(match[1]!.length, '0');
      final second = ''.padLeft(match[2]!.length, '0');
      return '/ID[<$first><$second>]';
    });
    return Uint8List.fromList(source.codeUnits);
  }
}
