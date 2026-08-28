import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/features/auth/premium_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OAuth buttons preserve Google Apple Facebook order and flag', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    final google = find.byKey(const Key('oauth-google'));
    final apple = find.byKey(const Key('oauth-apple'));
    final facebook = find.byKey(const Key('oauth-facebook'));

    expect(google, findsOneWidget);
    expect(apple, findsOneWidget);
    expect(find.byIcon(Icons.apple), findsOneWidget);
    expect(tester.getTopLeft(google).dy, lessThan(tester.getTopLeft(apple).dy));

    if (AppEnvironment.facebookLoginEnabled) {
      expect(facebook, findsOneWidget);
      expect(
        tester.getTopLeft(apple).dy,
        lessThan(tester.getTopLeft(facebook).dy),
      );
      if (AppEnvironment.facebookLoginReady) {
        expect(
          find.byKey(const Key('oauth-facebook-soon-glass')),
          findsNothing,
        );
      } else {
        expect(
          find.byKey(const Key('oauth-facebook-soon-glass')),
          findsOneWidget,
        );
        expect(find.text('SOON'), findsOneWidget);
        final material = tester.widget<Material>(facebook);
        final inkWell = tester.widget<InkWell>(
          find.descendant(of: facebook, matching: find.byType(InkWell)),
        );
        expect(material.color, Colors.white);
        expect(inkWell.onTap, isNull);
      }
    } else {
      expect(facebook, findsNothing);

      // The disabled provider is removed from the widget tree, including its
      // inter-button spacing. The next action follows the Apple button with
      // only the page's normal section spacing.
      final reviewer = find.byKey(const Key('store-reviewer-access'));
      final appleBottom = tester.getBottomLeft(apple).dy;
      final reviewerTop = tester.getTopLeft(reviewer).dy;
      expect(reviewerTop - appleBottom, lessThan(45));
    }
  });
}
