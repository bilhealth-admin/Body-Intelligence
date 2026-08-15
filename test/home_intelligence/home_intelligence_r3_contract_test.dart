@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone dashboard exposes three Bio Intelligence parity pages', () {
    final benchmark = File(
      'lib/features/dashboard/widgets/premium_dashboard_benchmark.dart',
    ).readAsStringSync();
    final carousel = File(
      'lib/features/dashboard/widgets/dashboard_primary_carousel.dart',
    ).readAsStringSync();

    expect(benchmark, contains('DashboardPrimaryCarousel('));
    expect(carousel, contains('DashboardTwinDeckShell('));
    expect(
      carousel,
      contains('DashboardPrimaryEmbeddedScope(child: bestAction)'),
    );
    expect(carousel, contains('DashboardPrimaryEmbeddedScope(child: summary)'));
    expect(
      carousel,
      contains('DashboardPrimaryEmbeddedScope(child: insights)'),
    );
    expect(carousel, contains("title: arabic ? 'أفضل خطوة الآن'"));
    expect(carousel, contains("title: arabic ? 'ملخص اليوم'"));
    expect(carousel, contains("title: arabic ? 'رؤى اليوم'"));
    expect(carousel, contains('twinBaseHeight(width)'));
    expect(carousel, contains('maximumTwinHeight'));
    expect(carousel, contains('return DashboardCarousel('));
    expect(carousel, contains('viewportFraction: 1'));
    expect(carousel, isNot(contains('return SizedBox(')));
    expect(carousel, isNot(contains('_PrimaryPage(')));
    expect(carousel, isNot(contains('SingleChildScrollView(')));
  });

  test('daily summary exposes real first metric page when embedded', () {
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();

    expect(summary, contains('final columns = phone ? 2'));
    expect(summary, contains('phone ? 1.20'));
    expect(summary, contains('phone ? 190 : 172'));
    expect(summary, contains('maxLines: 2'));
    expect(summary, contains('softWrap: true'));
    expect(summary, contains('DashboardPrimaryEmbeddedScope.active(context)'));
    expect(
      summary,
      contains('pages.isEmpty ? const SizedBox.shrink() : pages.first'),
    );
    expect(summary, isNot(contains('SizedBox.expand(child: carousel)')));
  });

  test('intelligence center remains task-oriented and bounded', () {
    final page = File(
      'lib/features/intelligence_center/presentation/intelligence_center_page.dart',
    ).readAsStringSync();
    final engine = File(
      'lib/features/intelligence_center/services/intelligence_center_engine.dart',
    ).readAsStringSync();

    expect(page, contains('اسأل عن جسمي'));
    expect(page, contains('لماذا وزني ثابت؟'));
    expect(page, contains('ماذا آكل الآن؟'));
    expect(page, contains('اعمل لي خطة'));
    expect(page, contains('راجع يومي'));

    expect(engine, contains('_isGreeting'));
    expect(engine, contains('_isPlanRequest'));
    expect(engine, contains('لن أعطيك خطة عامة وأدّعي أنها شخصية'));
    expect(engine, isNot(contains('local-bil-boundary')));
  });
}
