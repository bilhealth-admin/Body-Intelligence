import 'dart:io';

import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/ai_boost_coach_artwork.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production AI Boost artwork matches the approved source exactly', () {
    final approved = File(
      'artifacts/store_assets/google_play/bil_ai_boost_coach_icon_512.png',
    );
    final production = File(bilAiBoostCoachArtworkAsset);

    expect(approved.existsSync(), isTrue);
    expect(production.existsSync(), isTrue);
    expect(
      production.readAsBytesSync(),
      orderedEquals(approved.readAsBytesSync()),
    );
  });

  testWidgets('AI Boost store card renders the approved coach artwork', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const boost = BilStoreOfferMetadata(
      productId: StoreCatalogConfiguration.aiBoost,
      kind: BilStoreProductKind.aiBoostConsumable,
      localizedTitle: 'AI Boost',
      localizedPrice: 'Store price',
      currencyCode: 'TST',
      priceMicros: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: BilDynamicStoreOffers(
            locale: 'ar',
            offers: const [boost],
            initialFocus: 'boost',
            onPurchaseRequested: (_) {},
            onRestore: () {},
            onManage: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final artwork = find.byKey(const ValueKey('store-ai-boost-coach-artwork'));
    expect(artwork, findsOneWidget);
    expect(tester.getSize(artwork).width, inInclusiveRange(54, 82));
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('ai-boost-coach-artwork-image')),
    );
    expect(image.image, isA<ResizeImage>());
    final asset = (image.image as ResizeImage).imageProvider;
    expect(asset, isA<AssetImage>());
    expect((asset as AssetImage).assetName, bilAiBoostCoachArtworkAsset);
    expect(tester.takeException(), isNull);
  });

  test('AI Coach settings purchase card reuses the approved artwork', () {
    final source = File(
      'lib/features/intelligence_center/presentation/'
      'ai_coach_settings_components.dart',
    ).readAsStringSync();

    expect(source, contains('BilAiBoostCoachArtwork('));
    expect(source, contains("'settings-ai-boost-coach-artwork'"));
  });
}
