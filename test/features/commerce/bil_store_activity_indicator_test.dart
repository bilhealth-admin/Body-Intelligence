import 'dart:io';
import 'dart:ui' as ui;

import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _offer = BilStoreOfferMetadata(
  productId: 'qa.premium.monthly',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'Premium',
  localizedPrice: r'$2.49',
  currencyCode: 'USD',
  priceMicros: 2490000,
  billingPeriodIso8601: 'P1M',
);

void main() {
  for (final dark in [false, true]) {
    for (final rtl in [false, true]) {
      for (final reduced in [false, true]) {
        for (final restoring in [false, true]) {
          testWidgets(
            'one Splash indicator above checkout dark=$dark rtl=$rtl reduced=$reduced restore=$restoring',
            (tester) async {
              tester.view.physicalSize = const Size(390, 844);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              var launches = 0;
              var restores = 0;
              final status = BilStoreCopy.text(
                rtl ? 'ar' : 'en',
                restoring ? 'restore_checking' : 'purchase_in_progress',
              );
              await tester.pumpWidget(
                MaterialApp(
                  theme: dark ? ThemeData.dark() : ThemeData.light(),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: const Size(390, 844),
                      disableAnimations: reduced,
                      textScaler: TextScaler.linear(reduced ? 2 : 1),
                    ),
                    child: Directionality(
                      textDirection: rtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: RepaintBoundary(
                        key: const Key('qa-store-loading-frame'),
                        child: Scaffold(
                          body: BilDynamicStoreOffers(
                            locale: rtl ? 'ar' : 'en',
                            offers: const [_offer],
                            purchaseInProgress: !restoring,
                            restoreInProgress: restoring,
                            purchaseStatusMessage: status,
                            onPurchaseRequested: (_) => launches++,
                            onRestore: () => restores++,
                            onManage: () {},
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 160));
              final cta = find.byKey(const ValueKey('store-purchase-cta'));
              final spinner = find.byType(BilFeatureWelcomeStatus);
              expect(spinner, findsOneWidget);
              expect(find.byType(CircularProgressIndicator), findsNothing);
              expect(find.descendant(of: cta, matching: spinner), findsNothing);
              expect(
                tester.getRect(spinner).bottom,
                lessThanOrEqualTo(tester.getRect(cta).top),
              );
              expect(find.text(status), findsWidgets);
              expect(
                find.descendant(
                  of: cta,
                  matching: find.textContaining(r'$2.49'),
                ),
                findsOneWidget,
              );
              expect(tester.widget<InkWell>(cta).onTap, isNull);
              final nativeIndicator = tester.widget<CupertinoActivityIndicator>(
                find.byType(CupertinoActivityIndicator),
              );
              expect(nativeIndicator.radius, 12);
              expect(nativeIndicator.animating, !reduced);
              expect(
                nativeIndicator.color,
                dark ? const Color(0xFFBBC4CD) : const Color(0xFF697178),
              );
              await tester.tap(cta, warnIfMissed: false);
              await tester.pump(const Duration(milliseconds: 200));
              expect(launches, 0);
              expect(restores, 0);
              expect(tester.takeException(), isNull);
              if (reduced && restoring) {
                final boundary = tester.renderObject<RenderRepaintBoundary>(
                  find.byKey(const Key('qa-store-loading-frame')),
                );
                final bytes = await tester.runAsync(() async {
                  final image = await boundary.toImage(pixelRatio: 1);
                  try {
                    return await image.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                  } finally {
                    image.dispose();
                  }
                });
                final file = File(
                  'build/bil39_loading_review/store-${rtl ? 'ar' : 'en'}-${dark ? 'dark' : 'light'}-2x.png',
                );
                file.parent.createSync(recursive: true);
                file.writeAsBytesSync(bytes!.buffer.asUint8List());
              }
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }
  }
}
