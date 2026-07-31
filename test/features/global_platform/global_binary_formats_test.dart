import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/reports/binary_report_renderers.dart';

void main() {
  test('PDF renderer emits a structurally valid PDF document', () {
    final bytes = BilPdfRenderer().render('BIL Report', ['weight=95.1']);
    expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF-1.'));
    expect(String.fromCharCodes(bytes), contains('%%EOF'));
  });
  test('XLSX renderer emits a ZIP/OpenXML workbook', () {
    final bytes = BilXlsxRenderer().render([
      ['metric', 'value'],
      ['weight', 95.1],
    ]);
    expect(bytes.take(2).toList(), [0x50, 0x4b]);
    expect(bytes.length, greaterThan(500));
  });
}
