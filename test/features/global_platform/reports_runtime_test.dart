import 'global_platform_test_support.dart';

void main() {
  test('reports generate valid PDF XLSX CSV and JSON formats', () {
    final runtime = ScientificReportRuntime();
    final report = ScientificReport(
      id: 'r',
      locale: 'en',
      from: DateTime.utc(2026),
      to: DateTime.utc(2026, 1, 7),
      sections: [
        const ReportSection(
          id: 'w',
          title: 'Weight',
          facts: ['100 kg'],
          estimates: ['trend'],
          confidence: .9,
          provenance: 'local',
        ),
      ],
    );
    expect(String.fromCharCodes(runtime.pdf(report).take(5)), '%PDF-');
    final x = runtime.xlsx(report);
    expect(x.take(2).toList(), [0x50, 0x4b]);
    expect(String.fromCharCodes(runtime.csv(report)), contains('section,type'));
    expect(String.fromCharCodes(runtime.json(report)), contains('"id":"r"'));
  });
}
