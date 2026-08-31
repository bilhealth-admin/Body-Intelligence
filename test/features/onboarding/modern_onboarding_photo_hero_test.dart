import 'package:body_intelligence_log/features/onboarding/widgets/modern_onboarding_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScaffold(WidgetTester tester, {double textScale = 1}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: ModernOnboardingScaffold(
          step: 0,
          totalSteps: 2,
          title: 'Profile',
          artwork: const ModernOnboardingPhotoHero(
            key: Key('photo'),
            image: AssetImage(
              'assets/images/onboarding_2026/'
              'bil_onboarding_welcome_photo_v1.webp',
            ),
            height: 120,
          ),
          body: const TextField(key: Key('input')),
          onBack: null,
          onNext: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the complete photo without a card or tint frame', (
    tester,
  ) async {
    await pumpScaffold(tester);

    final photo = find.byKey(const Key('photo'));
    final imageFinder = find.descendant(
      of: photo,
      matching: find.byType(Image),
    );
    final image = tester.widget<Image>(imageFinder);

    expect(image.fit, BoxFit.contain);
    expect(tester.getSize(photo).height, 120);
    expect(
      find.descendant(of: photo, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    expect(
      find.descendant(of: photo, matching: find.byType(ClipRRect)),
      findsNothing,
    );
  });

  testWidgets('keeps the step input below the photo', (tester) async {
    await pumpScaffold(tester);

    final photoRect = tester.getRect(find.byKey(const Key('photo')));
    final inputContentRect = tester.getRect(
      find.byKey(const Key('onboarding-step-input-content')),
    );
    final inputRect = tester.getRect(find.byKey(const Key('input')));

    expect(inputContentRect.top, greaterThan(photoRect.bottom));
    expect(inputRect.top, greaterThan(photoRect.bottom));
  });

  testWidgets('remains compact at accessibility text scale', (tester) async {
    await pumpScaffold(tester, textScale: 2);

    expect(tester.getSize(find.byKey(const Key('photo'))).height, 80);
    expect(tester.takeException(), isNull);
  });
}
