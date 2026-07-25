import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/reports/arabic_vector_pdf_renderer.dart';
import 'package:body_intelligence_log/features/global_platform/reports/scientific_reports_platform.dart';

void main() {
  test('Arabic PDF embeds Noto font and paginates with valid xref', () async {
    final regular = File(
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    ).readAsBytesSync();
    final bold = File(
      'assets/fonts/NotoNaskhArabic-Bold.ttf',
    ).readAsBytesSync();
    final report = ScientificReport(
      id: 'arabic-vector-report',
      locale: 'ar',
      from: DateTime.utc(2026),
      to: DateTime.utc(2026, 2),
      sections: List.generate(
        80,
        (i) => ReportSection(
          id: 'section-$i',
          title: 'القسم $i',
          facts: ['الوزن مستقر'],
          estimates: ['اتجاه تقديري'],
          confidence: .8,
          provenance: 'BIL',
        ),
      ),
    );
    final bytes = await ArabicVectorPdfRenderer(
      regularFont: regular,
      boldFont: bold,
    ).render(report, title: 'تقرير الصحة', footer: 'سري');
    final latin = String.fromCharCodes(bytes);
    expect(latin, startsWith('%PDF-'));
    expect(latin, contains('startxref'));
    expect(RegExp(r'/Type\s*/Page\b').allMatches(latin).length, greaterThan(1));
    expect(bytes.length, greaterThan(regular.length));
  });
}
