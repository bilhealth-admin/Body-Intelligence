// This audited mapping intentionally uses compact guard clauses so the 177
// reference ranges remain readable as a table rather than deeply nested code.
// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:io';

typedef ReferenceMapping = ({String screen, String route, String capability});

String productionFileFor(String screen) => switch (screen) {
  'dashboard' ||
  'dashboard customization' ||
  'dashboard goals' ||
  'quick add' => 'lib/features/dashboard/dashboard_page.dart',
  'sleep' => 'lib/features/wellness/presentation/sleep_tracker_page.dart',
  'fasting' => 'lib/features/wellness/presentation/fasting_timer_page.dart',
  'learn' => 'lib/features/wellness/presentation/wellness_library_page.dart',
  'recipe discovery' || 'recipe collection' || 'workout discovery' =>
    'lib/features/wellness/presentation/professional_content_library_page.dart',
  'workout routines' || 'exercise entry' =>
    'lib/features/wellness/presentation/workout_library_page.dart',
  'subscription' =>
    'lib/features/commerce/presentation/bil_store_plans_page.dart',
  'apps and devices' || 'privacy and health access' =>
    'lib/features/connected_health/connected_health_page.dart',
  'community' ||
  'community navigation' ||
  'messages' => 'lib/features/community/presentation/community_hub_page.dart',
  'friends' =>
    'lib/features/community/presentation/community_connections_page.dart',
  'community profile' =>
    'lib/features/community/presentation/community_profile_page.dart',
  'profile' || 'goals' => 'lib/features/profile/premium_profile_page.dart',
  'water entry' ||
  'diary' ||
  'food logging' => 'lib/features/daily_log/daily_log_page.dart',
  'meal scan education' => 'lib/features/daily_log/daily_log_page_actions.dart',
  'barcode scan' =>
    'lib/features/nutrition/presentation/food_barcode_scanner_page.dart',
  'weight entry' => 'lib/features/daily_check_in/daily_check_in_page.dart',
  'food search' ||
  'food logging' => 'lib/features/daily_log/daily_log_page.dart',
  'saved food content' ||
  'custom food' => 'lib/features/nutrition/food_page.dart',
  'progress' ||
  'measurement progress' ||
  'nutrition analytics' => 'lib/features/analytics/analytics_page.dart',
  'weekly report' => 'lib/features/analytics/weekly_report_page.dart',
  'reminders' =>
    'lib/features/notifications/presentation/notification_settings_page.dart',
  'settings' ||
  'more' ||
  'export' => 'lib/features/settings/settings_page.dart',
  'legal' ||
  'privacy consent' ||
  'help' => 'lib/features/settings/trust_support_page.dart',
  _ => 'lib/app/router/app_router.dart',
};

String beforeStateFor(String screen) => switch (screen) {
  'dashboard' ||
  'weekly report' ||
  'profile' ||
  'goals' => 'implemented and previously visually tested',
  'subscription' ||
  'apps and devices' ||
  'community' ||
  'community navigation' ||
  'friends' ||
  'messages' =>
    'implemented with truthful unavailable states; production capture missing',
  _ => 'implemented; reference-specific visual evidence missing',
};

String gapFor(String screen) => switch (screen) {
  'subscription' => 'dense promotional hierarchy and excessive hero rounding',
  'community' ||
  'community navigation' ||
  'friends' ||
  'messages' => 'signed-out state lacked a mature actionable surface',
  'food search' || 'saved food content' =>
    'screen title and horizontal rhythm diverged from the mobile reference',
  'apps and devices' || 'privacy and health access' =>
    'content margins diverged from the canonical phone rhythm',
  'recipe discovery' || 'recipe collection' || 'workout discovery' =>
    'library margins diverged from the canonical phone rhythm',
  _ => 'required refreshed production evidence against the reference family',
};

String closureActionFor(String screen) => switch (screen) {
  'dashboard' ||
  'dashboard customization' ||
  'dashboard goals' ||
  'quick add' =>
    'production surface refined in dashboard header and top bar; refreshed golden required',
  'subscription' ||
  'community' ||
  'community navigation' ||
  'friends' ||
  'messages' ||
  'community profile' ||
  'food search' ||
  'food logging' ||
  'saved food content' ||
  'custom food' ||
  'apps and devices' ||
  'privacy and health access' ||
  'recipe discovery' ||
  'recipe collection' ||
  'workout discovery' => 'production page refined; refreshed golden required',
  _ =>
    'pre-existing production flow retained; refreshed golden proves current implementation',
};

String referenceStateFor(int number) {
  if (number <= 4827)
    return 'dashboard summary, calorie, macro, hydration or activity card';
  if (number <= 4831) return 'sleep overview, stages, trend or education state';
  if (number == 4832) return 'food search entry state';
  if (number <= 4850)
    return 'recipe discovery, collection, detail or empty state';
  if (number <= 4852) return 'subscription offer and entitlement state';
  if (number <= 4860) return 'workout discovery, detail or routine state';
  if (number <= 4865) return 'device source, connection or permission state';
  if (number <= 4869) return 'friend discovery, request or empty state';
  if (number <= 4872) return 'community profile state';
  if (number <= 4877)
    return 'profile, body, calorie, macro or nutrient goal state';
  if (number <= 4889) return 'dashboard goal selection and customization state';
  if (number == 4890) return 'quick-action menu';
  if (number == 4891) return 'water amount entry';
  if (number == 4892) return 'dated weight entry';
  if (number <= 4910)
    return 'exercise search, selection, custom or multi-add state';
  if (number <= 4913) return 'meal-photo education, camera or review state';
  if (number == 4914) return 'barcode camera state';
  if (number <= 4916) return 'food search results and source tabs';
  if (number <= 4919) return 'saved meal, recipe or food state';
  if (number <= 4921) return 'custom food or quick nutrition form';
  if (number <= 4924) return 'daily diary meal and nutrient state';
  if (number == 4925) return 'dashboard goal card state';
  if (number <= 4929) return 'progress chart, range or measurement state';
  if (number <= 4931) return 'feature directory state';
  if (number == 4932) return 'empty measurement progress state';
  if (number == 4933) return 'fasting plan and timer state';
  if (number <= 4940) return 'weekly report summary, trend or chart state';
  if (number <= 4943) return 'calorie, macro or nutrient analytics state';
  if (number == 4944) return 'private data export state';
  if (number <= 4947) return 'saved recipes, meals and foods state';
  if (number == 4948) return 'reminder schedule state';
  if (number <= 4953) return 'community home, profile or navigation state';
  if (number <= 4965) return 'education library category or article state';
  if (number == 4966) return 'friends empty state';
  if (number <= 4968) return 'message inbox, chat or sent state';
  if (number <= 4977)
    return 'settings, account, units or diary preference state';
  if (number <= 4979) return 'terms or privacy policy state';
  if (number == 4980) return 'optional technology consent state';
  if (number <= 4987) return 'sharing, account security or health-access state';
  return 'help, troubleshooting, feedback or account-deletion state';
}

String evidenceFor(String screen) => switch (screen) {
  'dashboard' ||
  'dashboard customization' ||
  'dashboard goals' ||
  'quick add' =>
    'test/visual_closure/goldens/visual_closure_dashboard_phone.png',
  'weekly report' => 'test/goldens/epic8_weekly_report_phone_ltr_light.png',
  'subscription' =>
    'test/visual_closure/goldens/visual_closure_store_plans_phone.png',
  'recipe discovery' || 'recipe collection' =>
    'test/visual_closure/goldens/visual_closure_recipe_library_phone.png',
  'workout discovery' =>
    'test/visual_closure/goldens/visual_closure_workout_library_phone.png',
  'workout routines' || 'exercise entry' =>
    'test/visual_closure/goldens/visual_closure_workout_log_phone.png',
  'sleep' => 'test/visual_closure/goldens/visual_closure_sleep_phone.png',
  'fasting' => 'test/visual_closure/goldens/visual_closure_fasting_phone.png',
  'learn' =>
    'test/visual_closure/goldens/visual_closure_wellness_library_phone.png',
  'community' || 'community navigation' =>
    'test/visual_closure/goldens/visual_closure_community_signed_out_phone.png',
  'friends' =>
    'test/visual_closure/goldens/visual_closure_community_connections_phone.png',
  'messages' =>
    'test/visual_closure/goldens/visual_closure_community_messages_phone.png',
  'community profile' =>
    'test/visual_closure/goldens/visual_closure_community_profile_phone.png',
  'apps and devices' || 'privacy and health access' =>
    'test/visual_closure/goldens/visual_closure_connected_health_permission_phone.png',
  'legal' || 'privacy consent' || 'help' =>
    'test/visual_closure/goldens/visual_closure_trust_support_rtl_dark_phone.png',
  'settings' ||
  'more' ||
  'export' => 'test/visual_closure/goldens/visual_closure_settings_phone.png',
  'reminders' =>
    'test/visual_closure/goldens/visual_closure_notification_settings_phone.png',
  'profile' => 'test/visual_closure/goldens/visual_closure_profile_phone.png',
  'goals' =>
    'test/visual_closure/goldens/visual_closure_profile_goals_phone.png',
  'progress' || 'nutrition analytics' =>
    'test/visual_closure/goldens/visual_closure_analytics_progress_phone.png',
  'measurement progress' =>
    'test/visual_closure/goldens/visual_closure_analytics_empty_phone.png',
  'saved food content' =>
    'test/visual_closure/goldens/visual_closure_food_catalog_phone.png',
  'food search' || 'food logging' =>
    'test/visual_closure/goldens/visual_closure_daily_log_meal_entry_phone.png',
  'custom food' =>
    'test/visual_closure/goldens/visual_closure_custom_food_phone.png',
  'meal scan education' =>
    'test/visual_closure/goldens/visual_closure_meal_photo_unavailable_phone.png',
  'water entry' =>
    'test/visual_closure/goldens/visual_closure_daily_log_water_entry_phone.png',
  'diary' =>
    'test/visual_closure/goldens/visual_closure_daily_log_empty_phone.png',
  'barcode scan' =>
    'test/visual_closure/goldens/visual_closure_barcode_unavailable_phone.png',
  'weight entry' =>
    'test/visual_closure/goldens/visual_closure_daily_check_in_phone.png',
  _ => 'test/goldens/epic3_compact_en_light.png',
};

ReferenceMapping mappingFor(int number) {
  if (number <= 4827)
    return (
      screen: 'dashboard',
      route: '/dashboard',
      capability: 'daily summary and goal cards',
    );
  if (number <= 4831)
    return (
      screen: 'sleep',
      route: '/wellness/sleep',
      capability: 'sleep education and recorded sleep state',
    );
  if (number == 4832)
    return (
      screen: 'food search',
      route: '/daily-log?focus=meal',
      capability: 'search, barcode, voice, photo and quick add',
    );
  if (number <= 4848)
    return (
      screen: 'recipe discovery',
      route: '/wellness/recipes',
      capability: 'trusted pictured recipe collections',
    );
  if (number <= 4850)
    return (
      screen: 'recipe collection',
      route: '/wellness/recipes',
      capability: 'recipe grid and category details',
    );
  if (number <= 4852)
    return (
      screen: 'subscription',
      route: '/plans',
      capability: 'honest store plans and entitlements',
    );
  if (number <= 4858)
    return (
      screen: 'workout discovery',
      route: '/wellness/workouts',
      capability: 'trusted professional workout collections',
    );
  if (number <= 4860)
    return (
      screen: 'workout routines',
      route: '/wellness/workouts/log',
      capability: 'saved and custom routines',
    );
  if (number <= 4865)
    return (
      screen: 'apps and devices',
      route: '/connected-health',
      capability: 'supported health and device sources',
    );
  if (number <= 4869)
    return (
      screen: 'friends',
      route: '/community/connections',
      capability: 'friends, requests and invitations',
    );
  if (number <= 4872)
    return (
      screen: 'community profile',
      route: '/community/profile',
      capability: 'profile and community identity',
    );
  if (number <= 4874)
    return (
      screen: 'profile',
      route: '/profile-settings',
      capability: 'profile identity and health goals',
    );
  if (number <= 4877)
    return (
      screen: 'goals',
      route: '/profile-settings',
      capability: 'weight, macro and nutrient goals',
    );
  if (number <= 4889)
    return (
      screen: 'dashboard customization',
      route: '/dashboard',
      capability: 'goal cards and source selection',
    );
  if (number == 4890)
    return (
      screen: 'quick add',
      route: '/dashboard',
      capability:
          'food, barcode, voice, photo, water, weight and exercise shortcuts',
    );
  if (number == 4891)
    return (
      screen: 'water entry',
      route: '/daily-log?action=water',
      capability: 'validated water entry',
    );
  if (number == 4892)
    return (
      screen: 'weight entry',
      route: '/daily-check-in',
      capability: 'dated weight entry',
    );
  if (number <= 4910)
    return (
      screen: 'exercise entry',
      route: '/wellness/workouts/log',
      capability: 'exercise search, custom exercise and multi-add',
    );
  if (number <= 4913)
    return (
      screen: 'meal scan education',
      route: '/daily-log?action=photo',
      capability: 'photo analysis, selection and review',
    );
  if (number == 4914)
    return (
      screen: 'barcode scan',
      route: '/daily-log?action=barcode',
      capability: 'camera and manual barcode lookup',
    );
  if (number <= 4916)
    return (
      screen: 'food logging',
      route: '/daily-log?focus=meal',
      capability: 'food search and trusted catalog results',
    );
  if (number <= 4919)
    return (
      screen: 'saved food content',
      route: '/nutrition',
      capability: 'saved meals, recipes and foods',
    );
  if (number <= 4921)
    return (
      screen: 'custom food',
      route: '/nutrition',
      capability: 'custom food and quick nutrition entry',
    );
  if (number <= 4924)
    return (
      screen: 'diary',
      route: '/daily-log',
      capability: 'meals, exercise, water, nutrition and notes',
    );
  if (number == 4925)
    return (
      screen: 'dashboard goals',
      route: '/dashboard',
      capability: 'dashboard goal presentation',
    );
  if (number <= 4929)
    return (
      screen: 'progress',
      route: '/analytics',
      capability: 'measurements, ranges and charts',
    );
  if (number <= 4931)
    return (
      screen: 'more',
      route: '/settings',
      capability: 'complete feature directory',
    );
  if (number == 4932)
    return (
      screen: 'measurement progress',
      route: '/analytics',
      capability: 'empty measurement state and add action',
    );
  if (number == 4933)
    return (
      screen: 'fasting',
      route: '/wellness/fasting',
      capability: 'safe fasting education and timer',
    );
  if (number <= 4940)
    return (
      screen: 'weekly report',
      route: '/weekly-report',
      capability: 'truthful seven-day report and empty charts',
    );
  if (number <= 4943)
    return (
      screen: 'nutrition analytics',
      route: '/analytics',
      capability: 'calories, nutrients and macros',
    );
  if (number == 4944)
    return (
      screen: 'export',
      route: '/settings',
      capability: 'private data export',
    );
  if (number <= 4947)
    return (
      screen: 'saved food content',
      route: '/nutrition',
      capability: 'recipes, meals and foods',
    );
  if (number == 4948)
    return (
      screen: 'reminders',
      route: '/notification-settings',
      capability: 'scheduled reminder settings',
    );
  if (number <= 4951)
    return (
      screen: 'community',
      route: '/community',
      capability: 'community profile and navigation',
    );
  if (number <= 4953)
    return (
      screen: 'community navigation',
      route: '/community',
      capability: 'community routes and profile',
    );
  if (number <= 4965)
    return (
      screen: 'learn',
      route: '/wellness-library',
      capability: 'trusted education, recipes and tools',
    );
  if (number == 4966)
    return (
      screen: 'friends',
      route: '/community/connections',
      capability: 'friends empty state',
    );
  if (number <= 4968)
    return (
      screen: 'messages',
      route: '/community',
      capability: 'message inbox and sent states',
    );
  if (number <= 4977)
    return (
      screen: 'settings',
      route: '/settings',
      capability: 'profile, appearance, diary and privacy settings',
    );
  if (number <= 4979)
    return (
      screen: 'legal',
      route: '/trust-support',
      capability: 'terms and privacy',
    );
  if (number == 4980)
    return (
      screen: 'privacy consent',
      route: '/trust-support',
      capability: 'optional technology consent',
    );
  if (number <= 4987)
    return (
      screen: 'privacy and health access',
      route: '/connected-health',
      capability: 'sharing, account security and least-privilege health access',
    );
  return (
    screen: 'help',
    route: '/trust-support',
    capability: 'help, feedback, troubleshooting and deletion',
  );
}

List<String> parseCsvLine(String line) {
  final cells = <String>[];
  var value = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        value.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      cells.add(value.toString());
      value = StringBuffer();
    } else {
      value.write(char);
    }
  }
  cells.add(value.toString());
  return cells;
}

String csvCell(Object? value) => '"${value.toString().replaceAll('"', '""')}"';

String htmlCell(Object? value) => const HtmlEscape().convert(value.toString());

void main() {
  final root = Directory.current.path;
  final reference = Directory(
    '$root/artifacts/release/visual_closure/reference',
  );
  final inventory = File('${reference.path}/reference_inventory.csv');
  if (!inventory.existsSync())
    throw StateError('Reference inventory is missing.');

  final lines = inventory
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.length != 178)
    throw StateError('Expected 177 references, found ${lines.length - 1}.');
  final header = parseCsvLine(
    lines.first,
  ).map((value) => value.toLowerCase()).toList();
  int column(String token) =>
      header.indexWhere((value) => value.contains(token));
  final nameColumn = column('name') >= 0 ? column('name') : 0;
  final shaColumn = column('sha');
  final records = <Map<String, Object?>>[];
  final coverage = <String>[
    'reference,name,sha256,reference_preview,screen,language,brightness,state,bil_route,capability,before_state,gap,closure_action,production_file,status,evidence_after',
  ];

  for (final line in lines.skip(1)) {
    final cells = parseCsvLine(line);
    final name = cells[nameColumn];
    final match = RegExp(r'IMG_(\d+)\.', caseSensitive: false).firstMatch(name);
    if (match == null) throw StateError('Unexpected reference name: $name');
    final number = int.parse(match.group(1)!);
    final mapping = mappingFor(number);
    final sha = shaColumn >= 0 && shaColumn < cells.length
        ? cells[shaColumn]
        : '';
    final record = <String, Object?>{
      'reference': number,
      'name': name,
      'sha256': sha,
      'reference_preview':
          'artifacts/release/visual_closure/reference/previews/IMG_$number.jpg',
      'screen': mapping.screen,
      'language': 'en',
      'brightness': 'light',
      'state': referenceStateFor(number),
      'bil_route': mapping.route,
      'capability': mapping.capability,
      'before_state': beforeStateFor(mapping.screen),
      'gap': gapFor(mapping.screen),
      'closure_action': closureActionFor(mapping.screen),
      'production_file': productionFileFor(mapping.screen),
      'status': 'awaiting refreshed production golden verification',
      'evidence_after': evidenceFor(mapping.screen),
    };
    records.add(record);
    coverage.add(record.values.map(csvCell).join(','));
  }

  final numbers = records.map((record) => record['reference']).toSet();
  if (records.length != 177 ||
      numbers.length != 177 ||
      !numbers.contains(4821) ||
      !numbers.contains(4997)) {
    throw StateError('Visual reference coverage is incomplete.');
  }
  File('${reference.path}/visual_reference_manifest.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(records));
  File(
    '${reference.path}/visual_reference_coverage.csv',
  ).writeAsStringSync('${coverage.join('\n')}\n');
  final comparisonCards = records
      .map((record) {
        final referenceName = record['name'];
        final previewName = referenceName.toString().replaceAll('.PNG', '.jpg');
        final evidence = record['evidence_after'];
        return '''
<article>
  <header><strong>IMG_${record['reference']}</strong> · ${htmlCell(record['screen'])}</header>
  <div class="pair">
    <figure><img src="previews/$previewName" alt="Reference ${record['reference']}"><figcaption>Reference</figcaption></figure>
    <figure><img src="../../../../$evidence" alt="BIL production evidence"><figcaption>BIL production</figcaption></figure>
  </div>
  <dl>
    <dt>Before</dt><dd>${htmlCell(record['before_state'])}</dd>
    <dt>Gap</dt><dd>${htmlCell(record['gap'])}</dd>
    <dt>Closure</dt><dd>${htmlCell(record['closure_action'])}</dd>
    <dt>Production</dt><dd><code>${htmlCell(record['production_file'])}</code></dd>
    <dt>Route</dt><dd><code>${htmlCell(record['bil_route'])}</code></dd>
  </dl>
</article>''';
      })
      .join('\n');
  File('${reference.path}/visual_reference_comparison.html').writeAsStringSync(
    '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>BIL visual reference closure</title><style>
body{margin:0;background:#f3f4f7;color:#111827;font:14px system-ui,sans-serif}main{max-width:1440px;margin:auto;padding:24px;display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:18px}article{background:white;border:1px solid #e5e7eb;border-radius:14px;overflow:hidden}header{padding:14px 16px;border-bottom:1px solid #e5e7eb}.pair{display:grid;grid-template-columns:1fr 1fr;gap:1px;background:#e5e7eb}.pair figure{margin:0;background:white}.pair img{display:block;width:100%;height:420px;object-fit:contain;background:#f9fafb}.pair figcaption{text-align:center;padding:8px}dl{display:grid;grid-template-columns:80px 1fr;gap:6px 12px;padding:14px 16px;margin:0}dt{color:#6b7280}dd{margin:0;overflow-wrap:anywhere}
</style></head><body><main>$comparisonCards</main></body></html>''',
  );
  stdout.writeln('VISUAL_REFERENCE_MANIFEST=PASS');
  stdout.writeln('REFERENCE_COUNT=${records.length}');
  stdout.writeln(
    "ROUTE_COUNT=${records.map((record) => record['bil_route']).toSet().length}",
  );
}
