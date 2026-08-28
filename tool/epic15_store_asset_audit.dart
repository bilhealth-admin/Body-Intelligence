import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Never _fail(String message) => throw StateError(message);

Map<String, Object?> _json(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing required JSON: $path');
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

({int width, int height, int colorType}) _png(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('Missing PNG: $path');
  final bytes = file.readAsBytesSync();
  if (bytes.length < 26 ||
      bytes[0] != 0x89 ||
      ascii.decode(bytes.sublist(1, 4)) != 'PNG') {
    _fail('Invalid PNG: $path');
  }
  final data = ByteData.sublistView(bytes);
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    colorType: bytes[25],
  );
}

void _expectPng(
  String path,
  int width,
  int height, {
  bool requireOpaque = false,
}) {
  final image = _png(path);
  if (image.width != width || image.height != height) {
    _fail('$path is ${image.width}x${image.height}; expected ${width}x$height');
  }
  if (requireOpaque && const {4, 6}.contains(image.colorType)) {
    _fail('$path contains an alpha channel');
  }
}

int _characters(String value) => value.runes.length;

void main() {
  final metadata = _json('docs/release/BIL_EPIC15_STORE_METADATA.json');
  final rights = _json('docs/release/BIL_EPIC15_CONTENT_RIGHTS.json');
  final platform = _json('docs/release/BIL_EPIC15_PLATFORM_METADATA.json');
  final ownerInputs = _json(
    'docs/release/BIL_EPIC15_OWNER_INPUT_AND_BLOCKERS.json',
  );
  final official = _json('docs/release/BIL_EPIC15_OFFICIAL_REQUIREMENTS.json');
  final locales = metadata['locales'] as Map<String, Object?>;
  const expectedLocales = {'ar', 'en-US', 'es-ES', 'fr-FR', 'tr-TR'};
  if (locales.keys.toSet().difference(expectedLocales).isNotEmpty ||
      expectedLocales.difference(locales.keys.toSet()).isNotEmpty) {
    _fail('Store metadata must contain exactly the five BIL locales');
  }
  for (final entry in locales.entries) {
    final copy = entry.value as Map<String, Object?>;
    final title = copy['title']! as String;
    final subtitle = copy['subtitle']! as String;
    final shortDescription = copy['short_description']! as String;
    final promotionalText = copy['promotional_text']! as String;
    final keywords = copy['keywords']! as String;
    final fullDescription = copy['full_description']! as String;
    if (_characters(title) > 30) {
      _fail('${entry.key} title exceeds 30 characters');
    }
    if (_characters(subtitle) > 30) {
      _fail('${entry.key} subtitle exceeds 30 characters');
    }
    if (_characters(shortDescription) > 80) {
      _fail('${entry.key} short description exceeds 80 characters');
    }
    if (_characters(promotionalText) > 170) {
      _fail('${entry.key} promotional text exceeds 170 characters');
    }
    if (_characters(keywords) > 100) {
      _fail('${entry.key} keywords exceed 100 characters');
    }
    if (_characters(fullDescription) > 4000) {
      _fail('${entry.key} description exceeds 4000 characters');
    }
    if (fullDescription.trim().isEmpty ||
        (copy['release_notes']! as String).trim().isEmpty) {
      _fail('${entry.key} has empty release metadata');
    }
  }

  final allMetadata = jsonEncode(metadata);
  if (RegExp(
    r'https?://(?:example|localhost|127\.0\.0\.1)',
    caseSensitive: false,
  ).hasMatch(allMetadata)) {
    _fail('Fake or local public URL found in store metadata');
  }
  final legal = metadata['legal_and_support'] as Map<String, Object?>;
  if (legal['domain'] != 'bilhealth.com' ||
      legal['support_email'] != 'support@bilhealth.com' ||
      !'${legal['status']}'.startsWith('OWNER_CONFIRMED_PUBLISHED_')) {
    _fail('Owner-confirmed legal identity or publication blocker is stale');
  }
  final releaseSources = [
    'docs/release/BIL_EPIC15_STORE_METADATA.json',
    'docs/release/BIL_EPIC15_PLATFORM_METADATA.json',
    'docs/release/BIL_EPIC15_PUBLIC_PAGES.md',
    'docs/release/BIL_EPIC15_STORE_CHECKLISTS.md',
  ].map((path) => File(path).readAsStringSync()).join('\n');
  if (RegExp(
    r'\b(?:TODO|TBD|CHANGEME)\b',
    // Store copy legitimately uses Spanish "Todo". Release placeholders are
    // required to be uppercase, so a case-insensitive scan is a false alarm.
    caseSensitive: true,
  ).hasMatch(releaseSources)) {
    _fail(
      'Unknown placeholder found; use a precise OWNER_INPUT_REQUIRED marker',
    );
  }
  if (RegExp(
    r'https?://(?:example\.|localhost|127\.0\.0\.1)',
    caseSensitive: false,
  ).hasMatch(releaseSources)) {
    _fail('Fake or local URL found in release materials');
  }

  _expectPng(
    'store_assets/graphics/google_play/feature_graphic.png',
    1024,
    500,
    requireOpaque: true,
  );
  _expectPng('store_assets/graphics/google_play/play_icon_512.png', 512, 512);
  if (File('store_assets/graphics/google_play/play_icon_512.png').lengthSync() >
      1024 * 1024) {
    _fail('Google Play icon exceeds 1 MB');
  }
  for (final plan in const ['free', 'plus', 'pro']) {
    _expectPng(
      'store_assets/graphics/plans/$plan.png',
      1080,
      1440,
      requireOpaque: true,
    );
  }
  _expectPng(
    'store_assets/graphics/brand/bil_horizontal_light.png',
    1600,
    900,
    requireOpaque: true,
  );

  const androidForegrounds = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
  };
  for (final entry in androidForegrounds.entries) {
    _expectPng(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_foreground.png',
      entry.value,
      entry.value,
    );
  }
  _expectPng(
    'android/app/src/main/res/drawable/ic_launcher_monochrome.png',
    432,
    432,
  );
  final adaptive = File(
    'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
  ).readAsStringSync();
  if (!adaptive.contains('<foreground') || !adaptive.contains('<monochrome')) {
    _fail('Android adaptive/monochrome launcher wiring is incomplete');
  }
  _expectPng(
    'ios/Runner/Assets.xcassets/BILLaunchWordmark.imageset/'
    'BILLaunchWordmark.png',
    864,
    864,
  );
  _expectPng(
    'android/app/src/main/res/drawable-nodpi/'
    'bil_splash_identity.png',
    864,
    864,
  );

  final apple = Directory('store_assets/screenshots/apple')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.png'))
      .toList();
  final google = Directory('store_assets/screenshots/google_play')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.png'))
      .toList();
  if (apple.length != 23) {
    _fail('Expected 23 Apple screenshots, found ${apple.length}');
  }
  if (google.length != 19) {
    _fail('Expected 19 Google screenshots, found ${google.length}');
  }
  for (final file in apple) {
    _expectPng(file.path, 1290, 2796, requireOpaque: true);
  }
  for (final file in google) {
    _expectPng(file.path, 1080, 1920, requireOpaque: true);
  }
  final productEvidence = Directory('store_assets/evidence/screenshots')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.png'))
      .toList();
  if (productEvidence.length != 2) {
    _fail('Expected real recipe/workout evidence captures');
  }

  const requiredScreenshotTokens = {
    'epic15_iphone_69_en_01_dashboard.png',
    'epic15_iphone_69_en_00_onboarding.png',
    'epic15_iphone_69_en_02_daily_log.png',
    'epic15_iphone_69_en_025_food_search.png',
    'epic15_iphone_69_en_03_progress.png',
    'epic15_iphone_69_en_04_plans.png',
    'epic15_iphone_69_en_05_connected_health.png',
    'epic15_iphone_69_en_06_privacy_settings.png',
    'epic15_iphone_69_en_07_weekly_report.png',
    'epic15_iphone_69_en_08_nutrition_pathways.png',
    'epic15_iphone_69_ar_00_onboarding.png',
    'epic15_iphone_69_ar_01_dashboard.png',
    'epic15_iphone_69_ar_02_daily_log.png',
    'epic15_iphone_69_ar_025_food_search.png',
    'epic15_iphone_69_ar_03_progress_dark.png',
    'epic15_iphone_69_ar_04_plans.png',
    'epic15_iphone_69_ar_05_weekly_report.png',
    'epic15_iphone_69_ar_06_connected_health.png',
    'epic15_iphone_69_ar_07_profile.png',
    'epic15_iphone_69_ar_08_privacy_settings_dark.png',
    'epic15_iphone_69_fr_plans.png',
    'epic15_iphone_69_es_plans.png',
    'epic15_iphone_69_tr_plans.png',
  };
  final appleNames = apple.map((file) => file.uri.pathSegments.last).toSet();
  if (!appleNames.containsAll(requiredScreenshotTokens)) {
    _fail('Apple screenshot evidence is missing required routes/locales');
  }

  final evidenceCsv = File('store_assets/evidence/asset_evidence_matrix.csv');
  final evidenceJson = File('store_assets/evidence/asset_evidence_matrix.json');
  if (!evidenceCsv.existsSync() || !evidenceJson.existsSync()) {
    _fail('Asset evidence matrix is missing');
  }
  final evidence = jsonDecode(evidenceJson.readAsStringSync()) as List<Object?>;
  if (evidence.length < 54) _fail('Asset evidence matrix is incomplete');
  for (final row in evidence.cast<Map<String, Object?>>()) {
    final path = row['path']! as String;
    if (!File(path).existsSync()) {
      _fail('Evidence points to missing file: $path');
    }
    if ((row['sha256']! as String).length != 64) {
      _fail('Missing SHA-256 for $path');
    }
    if (row['rights_status'] != 'BIL_OWNED_OR_ORIGINAL_GENERATED_FOR_BIL' ||
        row['status'] != 'PASS') {
      _fail('Unresolved rights or status for $path');
    }
  }
  if (!File('store_assets/evidence/preview_index.html').existsSync()) {
    _fail('Final asset preview index is missing');
  }
  for (final path in const [
    'store_assets/evidence/store_asset_inventory.csv',
    'store_assets/evidence/screenshot_matrix.csv',
    'store_assets/evidence/localization_matrix.csv',
    'store_assets/evidence/store_metadata_matrix.csv',
    'store_assets/evidence/sha256_manifest.txt',
  ]) {
    if (!File(path).existsSync() || File(path).lengthSync() < 100) {
      _fail('Required evidence ledger is missing or empty: $path');
    }
  }

  final generated = rights['generated_for_bil_2026_08_05'] as List<Object?>;
  final supplied =
      rights['owner_supplied_brand_archive'] as Map<String, Object?>;
  if (supplied['sha256'] !=
      'c8fba5b1cd4c9a0ef31f59cffddde0980cfebc68ade6a90e333f21e3be8730ee') {
    _fail('Owner-supplied BIL brand archive provenance is not pinned');
  }
  for (final path in const [
    'store_assets/source/BIL-Brand-Assets-v1/README.md',
    'store_assets/source/BIL-Brand-Assets-v1/01-bil-app-icon.png',
    'store_assets/source/BIL-Brand-Assets-v1/02-bil-splash.png',
    'store_assets/source/BIL-Brand-Assets-v1/03-bil-horizontal-logo.png',
    'store_assets/source/BIL-Brand-Assets-v1/04-bil-onboarding-hero.png',
    'store_assets/source/BIL-Brand-Assets-v1/05-bil-store-feature-graphic.png',
    'store_assets/source/BIL-Brand-Assets-v1/06-bil-free-plus-pro.png',
  ]) {
    if (!File(path).existsSync()) {
      _fail('Owner-approved brand source is missing: $path');
    }
  }
  for (final item in generated.cast<Map<String, Object?>>()) {
    if (!File(item['path']! as String).existsSync()) {
      _fail('Rights record points to missing generated asset: ${item['path']}');
    }
  }
  final screenshotTest = File(
    'test/epic15_store_screenshot_golden_test.dart',
  ).readAsStringSync();
  for (final token in const [
    'DashboardPage',
    'DailyLogPage',
    'AnalyticsPage',
    'BilStorePlansPage',
    'ConnectedHealthPage',
    'SettingsPage',
    'WellnessLibraryPage',
    '1290',
    '2796',
    '1080',
    '1920',
  ]) {
    if (!screenshotTest.contains(token)) {
      _fail('Production capture is missing $token');
    }
  }

  final appIconDir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
  final appIcons = appIconDir.listSync().whereType<File>().where(
    (file) => file.path.endsWith('.png'),
  );
  if (appIcons.length < 15) _fail('Incomplete iOS AppIcon set');
  for (final icon in appIcons) {
    final png = _png(icon.path);
    if (const {4, 6}.contains(png.colorType)) {
      _fail('iOS AppIcon contains forbidden alpha: ${icon.path}');
    }
  }

  for (final path in const [
    'docs/release/BIL_EPIC15_PUBLIC_PAGES.md',
    'docs/release/BIL_EPIC15_STORE_CHECKLISTS.md',
    'docs/release/BIL_EPIC15_STORE_EVIDENCE.md',
  ]) {
    if (!File(path).existsSync() || File(path).lengthSync() < 500) {
      _fail('Incomplete release document: $path');
    }
  }

  final platformText = jsonEncode(platform);
  for (final token in const [
    'data_safety',
    'health_apps_declaration',
    'health_connect',
    'permissions_justification',
    'app_privacy',
    'healthkit_explanation',
    'ble_explanation',
    'ai_photo_explanation',
    'restore_purchases',
    'export_compliance',
    'localized_descriptions',
    'localized_feature_highlights',
    'localized_support_privacy_review',
  ]) {
    if (!platformText.contains(token)) {
      _fail('Platform metadata is missing $token');
    }
  }
  final plans =
      (platform['subscription_copy']
              as Map<String, Object?>)['localized_descriptions']
          as Map<String, Object?>;
  if (plans.keys.toSet().difference({
        'ar',
        'en',
        'es',
        'fr',
        'tr',
      }).isNotEmpty ||
      plans.length != 5) {
    _fail('Subscription descriptions must cover five locales');
  }
  final rules = ownerInputs['rules'] as Map<String, Object?>;
  if (rules['unknown_placeholder_allowed'] != false ||
      rules['fake_url_allowed'] != false ||
      rules['credentials_in_git_allowed'] != false) {
    _fail('Owner input safety rules are not fail-closed');
  }
  final sources = official['sources'] as List<Object?>;
  if (sources.length < 8 ||
      sources.cast<Map<String, Object?>>().any(
        (source) => !(source['url']! as String).startsWith('https://'),
      )) {
    _fail('Official requirements sources are incomplete');
  }

  stdout.writeln('EPIC15_STORE_ASSET_AUDIT=PASS');
  stdout.writeln('STORE_LOCALES=${locales.length}');
  stdout.writeln('APPLE_SCREENSHOTS=${apple.length}');
  stdout.writeln('GOOGLE_SCREENSHOTS=${google.length}');
  stdout.writeln('EVIDENCE_ROWS=${evidence.length}');
  stdout.writeln('PUBLIC_URLS=OWNER_INPUT_REQUIRED_NOT_INVENTED');
}
