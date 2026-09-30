import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('More premium polish preserves every registered destination', () {
    final source = [
      'lib/features/settings/settings_page.dart',
      'lib/features/settings/settings_page_polish.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    for (final route in const [
      '/profile-summary',
      '/settings/language',
      '/location-settings',
      '/goals',
      '/history',
      '/weekly-report',
      '/challenges',
      '/analytics/nutrition',
      '/nutrition?from=settings',
      '/intelligence-center',
      '/settings/ai-coach',
      '/wellness/fasting',
      '/wellness/sleep',
      '/wellness/recipes',
      '/wellness/workouts/routines',
      '/connected-health',
      '/connected-health/steps',
      '/community',
      '/community/connections',
      '/community/messages',
      '/settings/preferences',
      '/notification-settings',
      '/settings/sharing-privacy',
      '/advertising-privacy',
      '/health-information-sources',
      '/help',
      '/admin/ai-coach',
    ]) {
      expect(source, contains(route), reason: route);
    }
    expect(source, contains('class _MorePremiumIcon'));
    expect(source, contains('const Color(0xFF0869E8)'));
    expect(source, contains('const Color(0xFFEAF3FF)'));
    expect(source, contains('BorderRadius.circular(24)'));
    expect(source, contains('fontWeight: FontWeight.w900'));
    expect(source, contains('CommunityUnreadBadge'));
  });

  test('bottom dock is compact and Quick Add owns the premium gradient', () {
    final source = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();
    expect(source, contains('final dockHeight = 68.0'));
    expect(source, contains('const quickAddRise = 18.0'));
    expect(
      source,
      contains('final reservedHeight = dockHeight + quickAddRise'),
    );
    expect(source, contains('height: reservedHeight'));
    expect(source, contains('Color(0xFF08A6F7)'));
    expect(source, contains('Color(0xFF176CF5)'));
    expect(source, contains('Color(0xFF7048F6)'));
    expect(source, contains('Icons.auto_awesome_rounded'));
    expect(source, contains("Key('shell-dashboard-destination')"));
    expect(source, contains("Key('shell-more-destination')"));
    expect(source, contains("Key('shell-quick-add')"));
  });
}
