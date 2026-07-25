import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/reports/arabic_vector_pdf_renderer.dart';
import 'package:body_intelligence_log/features/global_platform/reports/scientific_reports_platform.dart';
import 'package:body_intelligence_log/features/global_platform/reports/world_class_report_platform.dart';

void main() {
  test(
    'Arabic multi-page PDF and rich XLSX preserve text and evidence metadata',
    () async {
      final report = ScientificReport(
        id: 'r',
        locale: 'ar',
        from: DateTime.utc(2026),
        to: DateTime.utc(2026, 2),
        sections: <ReportSection>[
          for (var i = 0; i < 40; i++)
            ReportSection(
              id: '$i',
              title: 'قسم $i',
              facts: const <String>['حقيقة'],
              estimates: const <String>['تقدير'],
              confidence: .8,
              provenance: 'local',
            ),
        ],
      );
      const theme = ReportTheme(
        rtl: true,
        locale: 'ar',
        title: 'تقرير',
        footer: 'BIL',
      );
      final runtime = WorldClassReportRuntime(
        pdfRenderer: ArabicVectorPdfRenderer(
          regularFont: File(
            'assets/fonts/NotoNaskhArabic-Regular.ttf',
          ).readAsBytesSync(),
          boldFont: File(
            'assets/fonts/NotoNaskhArabic-Bold.ttf',
          ).readAsBytesSync(),
        ),
      );
      final first = await runtime.render(report, theme: theme);
      final second = await runtime.render(report, theme: theme);
      final pdfText = utf8.decode(first.pdf, allowMalformed: true);
      expect(first.pdf.length, greaterThan(1500));
      expect(pdfText, matches(RegExp(r'/Subtype\s*/Type0')));
      expect(pdfText, matches(RegExp(r'/Encoding\s*/Identity-H')));
      expect(pdfText, isNot(contains('????')));
      expect(first.pdf, second.pdf);

      final archive = ZipDecoder().decodeBytes(first.xlsx);
      final names = archive.files.map((file) => file.name).toSet();
      expect(
        names,
        containsAll(<String>{
          'xl/worksheets/sheet1.xml',
          'xl/worksheets/sheet2.xml',
          'xl/styles.xml',
          'docProps/core.xml',
        }),
      );
      final evidence = utf8.decode(
        archive.files
                .singleWhere((file) => file.name == 'xl/worksheets/sheet2.xml')
                .content
            as List<int>,
      );
      expect(evidence, contains('حقيقة'));
      expect(evidence, contains('rightToLeft="1"'));
      expect(evidence, contains('<autoFilter'));
      expect(first.xlsx, second.xlsx);
    },
  );
}
