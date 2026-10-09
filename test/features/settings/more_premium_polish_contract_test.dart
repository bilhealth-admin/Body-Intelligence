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
    // Verify the approved flat treatment rather than the retired filled badge.
    final flatIcon = File(
      'lib/features/settings/settings_page_polish.dart',
    ).readAsStringSync().split('class _CloudSyncRow').first;
    expect(flatIcon, contains('return BilFlatIcon('));
    expect(flatIcon, contains('kind: kind,'));
    expect(flatIcon, contains('size: 44,'));
    expect(flatIcon, contains('iconSize: 24,'));
    expect(flatIcon, contains('color: foreground,'));
    for (final forbidden in const [
      'BoxDecoration(',
      'LinearGradient(',
      'ShaderMask(',
      'BoxShadow(',
      'AnimatedContainer(',
    ]) {
      expect(flatIcon, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(source, contains('BorderRadius.circular(24)'));
    expect(source, isNot(contains('fontWeight: FontWeight.w900')));
    // The native font family is already supplied by the platform theme:
    // only More's weights and sizes should be locally refined.
    expect(source, contains('fontSize: 19,'));
    expect(source, contains('fontSize: 14,'));
    expect(source, contains('fontSize: 15.5,'));
    expect(source, contains('fontWeight: FontWeight.w400'));
    expect(source, contains('fontWeight: FontWeight.w600'));
    expect(source, contains('CommunityUnreadBadge'));
  });

  test('More typography follows the restrained system hierarchy', () {
    final page = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    final helpers = File(
      'lib/features/settings/settings_page_polish.dart',
    ).readAsStringSync();
    final start = page.indexOf('class _MoreRow extends StatelessWidget');
    expect(start, greaterThanOrEqualTo(0));
    final rows = page.substring(start);
    expect(rows, contains('textTheme.bodyLarge?.copyWith('));
    expect(rows, contains('fontSize: 15.5'));
    expect(rows, contains('fontWeight: FontWeight.w400'));
    expect(rows, isNot(contains('FontWeight.w700')));
    expect(helpers, contains('fontSize: 15.5'));
    expect(helpers, contains('fontWeight: FontWeight.w400'));
    // Navigation, membership authority, and global themes are unchanged.
    expect(page, contains("onTap: () => context.push(route)"));
    expect(page, contains("onTap: () => context.push('/plans')"));
  });

  test('More Premium entry is subtle and preserves verified-state routing', () {
    final source = File(
      'lib/features/settings/settings_page.dart',
    ).readAsStringSync();
    final start = source.indexOf('class _PremiumMembershipLink');
    final end = source.indexOf('class _MoreSection');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final entry = source.substring(start, end);
    expect(source, contains("Key('more-premium-entry')"));
    expect(source, contains("copy('Explore Premium')"));
    expect(source, contains("onTap: () => context.push('/plans')"));
    expect(source, contains('EntitlementAuthority.verifiedServer'));
    expect(source, contains("copy('Retry subscription check')"));
    expect(entry, contains('BoxConstraints(minHeight: 52)'));
    expect(entry, contains('fontWeight: FontWeight.w600'));
    expect(entry, contains('Color(0xFF8B6429)'));
    expect(entry, contains('Color(0xFFE2C78E)'));
    expect(entry, contains('isChecking'));
    expect(entry, contains('isRetry'));
    for (final forbidden in const [
      'PremiumCrownEmblem(',
      'LinearGradient(',
      'BoxDecoration(',
      'BoxShadow(',
      'ShaderMask(',
      'BackdropFilter(',
    ]) {
      expect(entry, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('bottom dock is compact and Quick Add owns the premium gradient', () {
    final source = File(
      'lib/app/router/responsive_app_shell.dart',
    ).readAsStringSync();
    final dock = File(
      'lib/shared/widgets/bil_reference_bottom_bar.dart',
    ).readAsStringSync();
    // The owner's current Coach reference supersedes the old 68dp/18dp dock.
    // Native widget tests verify these ratios at three widths and 100%/200%.
    expect(source, contains('child: BilReferenceBottomBar('));
    expect(dock, contains('final rise = 6 * opticalScale'));
    expect(
      dock,
      contains('final surfaceHeight = 79 * opticalScale + labelGrowth'),
    );
    expect(dock, contains('final contentHeight = rise + surfaceHeight'));
    expect(dock, contains('height: contentHeight + safeBottom'));
    expect(dock, contains('MediaQuery.paddingOf(context).bottom'));
    expect(source, contains('moreAttentionCount:'));
    expect(source, contains('Color(0xFF08A6F7)'));
    expect(source, contains('Color(0xFF176CF5)'));
    expect(source, contains('Color(0xFF7048F6)'));
    expect(source, contains('Icons.auto_awesome_rounded'));
    expect(source, contains("Key('shell-dashboard-destination')"));
    expect(source, contains("Key('shell-more-destination')"));
    expect(source, contains("Key('shell-quick-add')"));
  });
}
