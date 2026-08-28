import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/auth/account_gateway_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'gateway story viewport and image crop stay square in RTL at 160% text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            validRecoverySnapshotProvider.overrideWith((_) async => false),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child ?? const SizedBox.shrink(),
            ),
            home: const AccountGatewayPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final viewport = find.byKey(const Key('gateway-story-viewport'));
      expect(viewport, findsOneWidget);
      expect(Directionality.of(tester.element(viewport)), TextDirection.rtl);
      final viewportSize = tester.getSize(viewport);

      Size cardSize(int index) =>
          tester.getSize(find.byKey(ValueKey('gateway-story-card-$index')));
      Size imageSize(int index) =>
          tester.getSize(find.byKey(ValueKey('gateway-story-image-$index')));

      final firstCardSize = cardSize(0);
      expect(firstCardSize.width, closeTo(firstCardSize.height, .01));
      expect(imageSize(0), firstCardSize);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      final controller = pageView.controller!;
      final pageExtent =
          controller.position.viewportDimension * controller.viewportFraction;

      // Stop between pages: both cards are painted, but neither the viewport
      // nor either card is allowed to grow or drop during the drag.
      controller.jumpTo(pageExtent * .48);
      await tester.pump();
      expect(tester.getSize(viewport), viewportSize);
      expect(cardSize(0), firstCardSize);
      expect(cardSize(1), firstCardSize);
      expect(imageSize(1), firstCardSize);

      for (var index = 1; index < 3; index++) {
        controller.jumpToPage(index);
        await tester.pump();
        expect(tester.getSize(viewport), viewportSize);
        expect(cardSize(index), firstCardSize);
        expect(imageSize(index), firstCardSize);
        expect(tester.takeException(), isNull);
      }

      // Copy is deliberately sized by the longest localized story, so page
      // changes cannot move the controls below it even with enlarged text.
      expect(find.byKey(const Key('gateway-story-copy-slot')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
