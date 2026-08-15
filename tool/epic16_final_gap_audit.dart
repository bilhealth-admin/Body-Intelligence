import 'dart:convert';
import 'dart:io';

Never _fail(String message) {
  stderr.writeln('EPIC16_FINAL_GAP_AUDIT_FAIL=$message');
  exit(1);
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing evidence: $path');
  final value = file.readAsStringSync();
  return value.startsWith('\uFEFF') ? value.substring(1) : value;
}

void _requireNonEmptyFile(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing evidence: $path');
  if (file.lengthSync() == 0) _fail('Empty evidence: $path');
}

void _require(bool condition, String message) {
  if (!condition) _fail(message);
}

void main() {
  final matrix =
      jsonDecode(_read('docs/release/BIL_EPIC16_FINAL_GAP_AUDIT.json'))
          as Map<String, Object?>;
  final areas = (matrix['areas']! as List<Object?>)
      .cast<Map<String, Object?>>();
  _require(
    areas.length >= 18,
    'Final matrix does not cover the release surface',
  );

  const unresolvedInternal = <String>{
    'partial',
    'mock_demo_placeholder',
    'disconnected',
    'missing',
  };
  final unresolved = areas
      .where((area) => unresolvedInternal.contains(area['status']))
      .map((area) => area['id'])
      .toList(growable: false);
  _require(
    unresolved.isEmpty,
    'Internal gaps remain: ${unresolved.join(', ')}',
  );

  for (final area in areas) {
    final id = '${area['id']}';
    final chain = '${area['chain']}'.trim();
    final evidence = (area['evidence']! as List<Object?>).cast<String>();
    _require(chain.contains('->'), '$id has no end-to-end chain');
    _require(evidence.isNotEmpty, '$id has no evidence');
    for (final path in evidence) {
      _read(path);
    }
  }

  final visual =
      (jsonDecode(
                _read(
                  'artifacts/release/visual_closure/reference/visual_reference_manifest.json',
                ),
              )
              as List<Object?>)
          .cast<Map<String, Object?>>();
  _require(visual.length == 177, 'Expected 177 visual references');
  for (final row in visual) {
    for (final key in const <String>[
      'bil_route',
      'before_state',
      'gap',
      'production_file',
      'status',
      'evidence_after',
    ]) {
      _require('${row[key]}'.trim().isNotEmpty, 'Visual row missing $key');
    }
    _read('${row['production_file']}');
    _requireNonEmptyFile('${row['evidence_after']}');
    _require(
      row['status'] == 'verified production golden',
      'Visual reference ${row['reference']} is not verified',
    );
  }

  final router = _read('lib/app/router/app_router.dart');
  const releaseRoutes = <String>[
    '/startup',
    '/login',
    '/register',
    '/verify-email',
    '/account-gateway',
    '/onboarding',
    '/daily-check-in',
    '/context',
    '/decision-memory',
    '/plan',
    '/experiments',
    '/share-studio',
    '/challenges',
    '/profile-settings',
    '/advanced-body-measurements',
    '/connected-health',
    '/plans',
    '/nutrition-plans',
    '/weekly-report',
    '/community',
    '/community/people',
    '/community/connections',
    '/community/food-review',
    '/community/profile',
    '/community/safety',
    '/community/chat/:userId',
    '/food-libraries',
    '/notification-settings',
    '/advertising-privacy',
    '/wellness-library',
    '/wellness/sleep',
    '/wellness/workouts',
    '/wellness/workouts/log',
    '/wellness/fasting',
    '/wellness/recipes',
    '/wellness/content-packs',
    '/location-settings',
    '/trust-support',
    '/settings/analytics',
    '/dashboard',
    '/dashboard/decision-explanation',
    '/daily-log',
    '/intelligence-center',
    '/nutrition',
    '/history',
    '/analytics',
    '/settings',
  ];
  for (final route in releaseRoutes) {
    _require(router.contains("'$route'"), 'Missing release route $route');
  }

  final quickAdd = _read('lib/features/daily_log/daily_log_page_actions.dart');
  for (final action in const <String>['barcode', 'voice', 'photo']) {
    _require(
      quickAdd.toLowerCase().contains(action),
      'Daily Log quick add is missing $action',
    );
  }

  final settings = _read('lib/features/settings/settings_page.dart');
  for (final entry in const <String>[
    'settings-connected-health-entry',
    'settings-notifications-entry',
    'settings-weekly-report-entry',
    'settings-advertising-privacy-entry',
  ]) {
    _require(settings.contains(entry), 'Missing Settings reachability: $entry');
  }

  final environment = _read('lib/app/environment/app_environment.dart');
  for (final flag in const <String>[
    'BIL_COMMUNITY_ENABLED',
    'BIL_PUSH_ENABLED',
    'BIL_PAYMENTS_ENABLED',
    'BIL_ADS_ENABLED',
    'BIL_AD_PROVIDER_READY',
  ]) {
    _require(environment.contains(flag), 'Missing fail-closed flag $flag');
  }
  final mealVision = _read(
    'lib/features/nutrition/services/meal_image_analysis_service.dart',
  );
  _require(
    mealVision.contains('AppEnvironment.mealVisionEndpoint') &&
        environment.contains('BIL_MEAL_VISION_ENDPOINT'),
    'Missing fail-closed meal-image endpoint configuration',
  );

  final external = matrix['external_gates']! as List<Object?>;
  _require(external.length >= 10, 'External release gates were collapsed');
  _require(
    matrix['release_claim'] ==
        'repository_ready_only_external_gates_remain_unclaimed',
    'Final audit overclaims publication or external verification',
  );

  stdout.writeln('EPIC16_FINAL_GAP_AUDIT=PASS');
  stdout.writeln('AUDITED_AREAS=${areas.length}');
  stdout.writeln('VISUAL_REFERENCES=${visual.length}');
  stdout.writeln('ROUTES_AUDITED=${releaseRoutes.length}');
  stdout.writeln('INTERNAL_UNRESOLVED=0');
  stdout.writeln('EXTERNAL_GATES=${external.length}');
}
