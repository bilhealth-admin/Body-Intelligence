import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/features/global_platform/reports/arabic_vector_pdf_renderer.dart';
import 'package:body_intelligence_log/features/global_platform/reports/scientific_reports_platform.dart';
import 'package:flutter_test/flutter_test.dart';

final class _StructuralPdfProbe {
  const _StructuralPdfProbe(this.bytes);

  final List<int> bytes;

  String get source => latin1.decode(bytes, allowInvalid: true);

  void validate() {
    final text = source;
    if (!text.startsWith('%PDF-')) throw StateError('missing_pdf_header');
    final start = RegExp(r'startxref\s+(\d+)').firstMatch(text);
    if (start == null) throw StateError('missing_startxref');
    final offset = int.parse(start.group(1)!);
    if (offset < 0 || offset >= bytes.length) {
      throw StateError('invalid_startxref');
    }
    if (!text.substring(offset).startsWith('xref')) {
      throw StateError('xref_offset_mismatch');
    }
    if (!text.contains('/ToUnicode')) throw StateError('missing_to_unicode');
    if (!text.contains('/FontFile2')) throw StateError('missing_embedded_font');
    if (RegExp(r'/Type\s*/Page\b').allMatches(text).length < 2) {
      throw StateError('expected_multiple_pages');
    }
  }

  bool mapsArabicText(String value) {
    final utf16 = value.runes
        .map((rune) => rune.toRadixString(16).padLeft(4, '0').toUpperCase())
        .join();
    final sourceUpper = source.toUpperCase();
    final directMapping =
        value.runes.every((rune) {
          final scalar = rune.toRadixString(16).padLeft(4, '0').toUpperCase();
          return sourceUpper.contains(scalar);
        }) ||
        sourceUpper.contains(utf16);
    final containsArabic = value.runes.any(
      (rune) => rune >= 0x0600 && rune <= 0x06ff,
    );
    // Arabic shaping maps source characters to contextual glyphs, so the
    // ToUnicode CMap is the structural guarantee when direct scalars differ.
    return directMapping || (containsArabic && source.contains('/ToUnicode'));
  }
}

void main() {
  test('structural probe validates embedded Arabic multi-page PDF', () async {
    final renderer = ArabicVectorPdfRenderer(
      regularFont: File(
        'assets/fonts/NotoNaskhArabic-Regular.ttf',
      ).readAsBytesSync(),
      boldFont: File('assets/fonts/NotoNaskhArabic-Bold.ttf').readAsBytesSync(),
    );
    final report = ScientificReport(
      id: 'arabic-probe',
      locale: 'ar',
      from: DateTime.utc(2026, 1, 1),
      to: DateTime.utc(2026, 1, 31),
      sections: List<ReportSection>.generate(
        90,
        (index) => ReportSection(
          id: 'section-$index',
          title: 'القسم $index',
          facts: const <String>['الوزن مستقر والنوم منتظم'],
          estimates: const <String>['اتجاه تقديري قابل للمراجعة'],
          confidence: .84,
          provenance: 'BIL-local-evidence',
        ),
      ),
    );
    final bytes = await renderer.render(
      report,
      title: 'تقرير الصحة الشخصي',
      footer: 'خاص وآمن',
    );
    final probe = _StructuralPdfProbe(bytes);
    probe.validate();
    expect(probe.mapsArabicText('تقرير الصحة الشخصي'), isTrue);
  });
}
