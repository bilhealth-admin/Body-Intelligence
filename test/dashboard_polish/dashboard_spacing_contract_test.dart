import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _normalized(String source) =>
    source.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  test('dashboard spacing remains presentation-only and responsive', () {
    const productionFiles = <String>[
      'lib/features/dashboard/widgets/dashboard_layout_metrics.dart',
      'lib/features/dashboard/widgets/dashboard_experience_frame.dart',
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
      'lib/features/dashboard/widgets/daily_return_card.dart',
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ];

    final metrics = _normalized(File(productionFiles[0]).readAsStringSync());
    final frame = _normalized(File(productionFiles[1]).readAsStringSync());
    final benchmark = _normalized(File(productionFiles[2]).readAsStringSync());
    final daily = _normalized(File(productionFiles[3]).readAsStringSync());
    final grid = _normalized(File(productionFiles[4]).readAsStringSync());

    expect(metrics, contains('regionGap: 16'));
    expect(metrics, contains('regionGap: 18'));
    expect(metrics, contains('regionGap: 20'));
    expect(
      metrics,
      contains('regionGap: width >= ultraWideBreakpoint ? 22 : 20'),
    );
    expect(
      frame,
      contains(
        'final contentGap = compactVerticalRhythm ? 12.0 : PremiumDesignTokens.spaceMd',
      ),
    );
    expect(
      benchmark,
      contains(
        'final sectionGap = constraints.maxWidth >= 900 ? 12.0 : PremiumDesignTokens.spaceMd',
      ),
    );
    expect(benchmark, contains('const SizedBox(height: 6)'));
    expect(daily, contains('heading, const SizedBox(height: 6), carousel'));
    expect(
      grid,
      contains('const SizedBox(height: PremiumDesignTokens.spaceMd)'),
    );
    expect(grid, contains('DashboardAnalyticsCenter('));

    final diff = Process.runSync('git', <String>[
      'diff',
      '--unified=0',
      '--',
      ...productionFiles,
    ], runInShell: true);
    expect(diff.exitCode, 0, reason: diff.stderr.toString());

    final addedLines = diff.stdout
        .toString()
        .split(RegExp(r'\r?\n'))
        .where((line) => line.startsWith('+') && !line.startsWith('+++'))
        .map((line) => line.substring(1))
        .join('\n');

    expect(addedLines, isNot(contains('Provider')));
    expect(addedLines, isNot(contains('Repository')));
    expect(addedLines, isNot(contains('Engine().')));
    expect(addedLines, isNot(contains('ref.watch(')));
    expect(addedLines, isNot(contains('ref.read(')));
  });
}
