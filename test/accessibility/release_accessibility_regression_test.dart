import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  String librarySource(String path) {
    final library = File(path);
    final entrypoint = library.readAsStringSync();
    final parts = RegExp(r"part '([^']+)';")
        .allMatches(entrypoint)
        .map((match) => File('${library.parent.path}/${match.group(1)!}'));
    return <String>[
      entrypoint,
      for (final part in parts) part.readAsStringSync(),
    ].join('\n');
  }

  test('common icon actions expose stable accessible names', () {
    expect(
      source('lib/features/auth/login_page.dart'),
      contains("'Show password'"),
    );
    expect(
      source('lib/features/dashboard/widgets/dashboard_top_bar.dart'),
      contains('tooltip: tooltip'),
    );
    expect(
      source('lib/features/community/presentation/community_chat_page.dart'),
      contains("'Send message'"),
    );
    expect(
      source('lib/features/history/history_page.dart'),
      contains("tooltip: context.strings.text('Delete')"),
    );
    final workout = source(
      'lib/features/wellness/presentation/bil_workout_routine_media.dart',
    );
    expect(workout, contains("'Play video'"));
    expect(workout, contains("'Pause video'"));
  });

  test('continuous decorative motion honors the system setting', () {
    for (final path in <String>[
      'lib/features/intelligence_center/presentation/intelligence_center_voice_widgets.dart',
      'lib/features/nutrition/presentation/food_barcode_scanner_page.dart',
      'lib/features/onboarding/widgets/modern_onboarding_scaffold.dart',
    ]) {
      expect(source(path), contains('disableAnimations'));
    }
  });

  test('connected-health preview no longer suppresses larger text', () {
    final connectedHealth = source(
      'lib/features/connected_health/widgets/connected_health_card.dart',
    );
    expect(connectedHealth, isNot(contains('.clamp(1.0, 1.15)')));
    expect(connectedHealth, isNot(contains('copyWith(textScaler:')));
    expect(connectedHealth, contains('previewSide'));
  });

  test('store contrast and core dark surfaces use the active theme', () {
    final offer = librarySource(
      'lib/features/commerce/presentation/bil_dynamic_store_offers.dart',
    );
    expect(offer, isNot(contains('Color(0xFF777B82)')));
    expect(
      RegExp(r'\b(?:colorScheme|scheme)\.onSurfaceVariant\b').hasMatch(offer),
      isTrue,
      reason: 'Store secondary copy must use the active theme contrast color.',
    );

    final store = source(
      'lib/features/commerce/presentation/bil_store_plans_page.dart',
    );
    expect(store, contains('scheme.brightness == Brightness.dark'));
    expect(store, isNot(contains('backgroundColor: Colors.white')));

    final verify = source('lib/features/auth/verify_email_page.dart');
    expect(verify, contains('surfaceContainerHighest'));
    final gateway = source(
      'lib/features/auth/premium_account_gateway_page.dart',
    );
    expect(gateway, contains('pageBackground'));
  });
}
