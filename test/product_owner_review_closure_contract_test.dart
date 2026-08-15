import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product owner review closure keeps barcode journey integrated', () {
    final dailyLog = [
      'lib/features/daily_log/daily_log_page.dart',
      'lib/features/daily_log/daily_log_page_actions.dart',
      'lib/features/daily_log/daily_log_meal_entry.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final foodPage = File(
      'lib/features/nutrition/food_page.dart',
    ).readAsStringSync();
    final scanner = File(
      'lib/features/nutrition/presentation/food_barcode_scanner_page.dart',
    ).readAsStringSync();

    expect(dailyLog, contains('Scan with camera'));
    expect(dailyLog, contains('Enter barcode manually'));
    expect(dailyLog, contains('lookupBarcodeJourney'));
    expect(dailyLog, contains("context.strings.text('Source')"));
    expect(foodPage, contains('_cameraBarcodeLookup'));
    expect(scanner, contains('MobileScanner('));
    expect(scanner, contains('toggleTorch'));
    expect(scanner, contains('Nothing is uploaded'));
  });

  test('platform camera declarations are present', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(manifest, contains('android.permission.CAMERA'));
    expect(plist, contains('NSCameraUsageDescription'));
    expect(pubspec, contains('mobile_scanner:'));
  });

  test('dashboard and shell include overflow hardening', () {
    final summary = [
      'lib/features/dashboard/widgets/dashboard_daily_summary.dart',
      'lib/features/dashboard/widgets/dashboard_metric_grid.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    final shell = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();

    expect(summary, contains('baseHeight +'));
    expect(summary, contains('maxLines: 2'));
    expect(summary, contains('TextOverflow.fade'));
    expect(summary, contains('softWrap: true'));
    expect(summary, contains('FittedBox('));
    expect(summary, contains('BoxFit.scaleDown'));
    expect(summary, contains('FittedBox('));
    expect(summary, contains('BoxFit.scaleDown'));
    expect(
      shell,
      isNot(contains('EdgeInsets.only(bottom: 82)')),
      reason: 'The old black content spacer must not return.',
    );
    expect(
      shell,
      contains('FloatingActionButtonLocation.centerDocked'),
      reason: 'The plus button must remain docked at the bar edge.',
    );
    expect(
      shell,
      contains('extendBody: true'),
      reason:
          'Page content must continue behind the glass bar so no black shelf is reserved above it.',
    );
    expect(
      shell,
      contains('height: 76'),
      reason: 'The navigation bar keeps its compact visual height.',
    );
    expect(shell, contains('Color(0xB807111D)'));
    expect(shell, contains('Color(0xB8F4F8FC)'));
  });

  test('Arabic localization includes review findings', () {
    final localization = File(
      'lib/app/localization/app_localizations.dart',
    ).readAsStringSync();

    expect(
      localization,
      contains("'Analytics overview': 'نظرة عامة على التحليلات'"),
    );
    expect(localization, contains("'Scan with camera': 'المسح بالكاميرا'"));
    expect(localization, contains('kg since the previous check-in'));
  });
}
