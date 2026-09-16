import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard typography hierarchy is explicit and presentation-only', () {
    final files = <String>[
      'lib/features/dashboard/widgets/personal_health_ai_panel.dart',
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
      'lib/features/dashboard/widgets/daily_return_card.dart',
      'lib/features/dashboard/widgets/dashboard_grid.dart',
      'lib/features/dashboard/widgets/dashboard_section_heading.dart',
    ];
    final source = files
        .map((path) => File(path).readAsStringSync())
        .join('\n');
    // The approved compact fitness group emphasizes only its numeric weight
    // value. All headings, labels and body copy keep the lighter hierarchy.
    final numericWeightStyle = RegExp(
      r'Text\(\s*value!,\s*textDirection: TextDirection\.ltr,\s*'
      r'style: Theme\.of\(context\)\.textTheme\.labelMedium\s*'
      r'\?\.copyWith\(\s*fontWeight: FontWeight\.w800,\s*'
      r'fontSize: 14,\s*\),\s*\)',
    );
    final dailyReturn = File(files[2]).readAsStringSync();
    expect(numericWeightStyle.allMatches(dailyReturn), hasLength(1));
    expect(
      source.replaceAll(numericWeightStyle, ''),
      isNot(contains('FontWeight.w800')),
    );
    expect(source, isNot(contains('FontWeight.w900')));
    expect(source, contains('FontWeight.w700'));
    expect(source, contains('letterSpacing: -0.15'));
    expect(source, contains('height: 1.12'));
    expect(source, contains('height: 1.45'));
    expect(source, isNot(contains('Repository(')));
    expect(source, isNot(contains('ProviderScope(')));
  });

  test('flagship theme keeps the approved mobile typography and geometry', () {
    final source = File(
      'lib/app/theme/bil_flagship_theme.dart',
    ).readAsStringSync();
    final tokens = File(
      'lib/app/theme/bil_flagship_tokens.dart',
    ).readAsStringSync();

    expect(source, contains('centerTitle: true'));
    expect(source, isNot(contains('FontWeight.w300')));
    expect(source, isNot(contains('FontWeight.w500')));
    expect(source, isNot(contains('FontWeight.w800')));
    expect(source, isNot(contains('FontWeight.w900')));
    expect(tokens, contains('static const double radiusMd = 12'));
    expect(
      tokens,
      contains('static const Color canvasLight = Color(0xFFF5F5F8)'),
    );
  });
}
