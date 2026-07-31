import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premium UI repository boundaries are present and authoritative', () {
    final foundation = File(
      'lib/app/theme/bil_premium_visual_foundation.dart',
    ).readAsStringSync();
    final responsive = File(
      'lib/app/theme/bil_premium_responsive_layout.dart',
    ).readAsStringSync();
    final surface = File(
      'lib/shared/widgets/premium_surface.dart',
    ).readAsStringSync();

    expect(foundation, contains('class BilPremiumVisualFoundation'));
    expect(foundation, contains('dashboardCardHighContrastBorderWidth'));
    expect(responsive, contains('class BilPremiumResponsiveLayout'));
    expect(surface, contains('enum PremiumSurfaceLevel'));
    expect(surface, contains('FocusableActionDetector'));
    expect(surface, contains('MediaQuery.highContrastOf(context)'));
    expect(surface, contains('AlignmentDirectional.topStart'));
  });

  test('all accepted premium UI decisions have durable documentation', () {
    const decisions = <String>[
      'docs/architecture/BIL_PREMIUM_UI_FOUNDATION.md',
      'docs/architecture/BIL_DASHBOARD_VISUAL_HIERARCHY.md',
      'docs/architecture/BIL_PREMIUM_RESPONSIVE_LAYOUT.md',
      'docs/architecture/BIL_PREMIUM_INTERACTION_STATES.md',
      'docs/architecture/BIL_PREMIUM_ACCESSIBILITY_LOCALIZATION.md',
      'docs/architecture/BIL_PREMIUM_UI_EPIC_CLOSURE.md',
    ];

    for (final path in decisions) {
      expect(File(path).existsSync(), isTrue, reason: 'Missing $path');
    }
  });

  test('closure preserves external release gates explicitly', () {
    final closure = File(
      'docs/architecture/BIL_PREMIUM_UI_EPIC_CLOSURE.md',
    ).readAsStringSync();

    expect(closure, contains('physical-device typography certification'));
    expect(closure, contains('screen-reader certification'));
    expect(closure, contains('store review'));
    expect(closure, contains('external release gates'));
    expect(closure, contains('hidden repository work'));
  });
}
