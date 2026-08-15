@Skip('Superseded by the approved current dashboard contracts (R25/R26).')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home intelligence package reuses existing AI and exposes center', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final engine = File(
      'lib/features/intelligence_center/services/intelligence_center_engine.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/dashboard/widgets/dashboard_grid.dart',
    ).readAsStringSync();

    expect(router, contains('/intelligence-center'));
    expect(engine, contains('AiCoachResponse'));
    expect(engine, contains('ExternalKnowledgeProvider'));
    expect(dashboard, contains('DashboardIntelligenceCenterCard'));
  });

  test('regional barcode is offline first then network cached', () {
    final authority = File(
      'lib/features/nutrition/services/food_runtime_search_authority.dart',
    ).readAsStringSync();
    final resolver = File(
      'lib/features/nutrition/services/regional_barcode_network_resolver.dart',
    ).readAsStringSync();

    expect(authority, contains('_resolveOnlineBarcode'));
    expect(resolver, contains('world.openfoodfacts.org'));
    expect(resolver, contains('api.nal.usda.gov'));
    expect(resolver, contains('regional_barcode_cache'));
    expect(resolver, contains('BIL_USDA_API_KEY'));
  });

  test('dashboard header and daily cards are compact and readable', () {
    final header = File(
      'lib/features/dashboard/widgets/dashboard_top_bar.dart',
    ).readAsStringSync();
    final summary = File(
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
    ).readAsStringSync();

    expect(header, contains('fontSize: 34'));
    expect(summary, contains('minHeight: compact ? 148'));
    expect(summary, contains('maxLines: 2'));
  });
}
