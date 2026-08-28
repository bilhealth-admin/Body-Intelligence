import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown barcode requires photo evidence before existing Vision path', () {
    final backend = File(
      'supabase/functions/barcode-lookup/index.ts',
    ).readAsStringSync();
    final foodPage = File(
      'lib/features/nutrition/food_page.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final coach =
        [
              'intelligence_center_page.dart',
              'intelligence_conversation_voice.dart',
            ]
            .map(
              (name) => File(
                'lib/features/intelligence_center/presentation/$name',
              ).readAsStringSync(),
            )
            .join('\n');
    final vision = File(
      'lib/features/nutrition/services/meal_image_analysis_service.dart',
    ).readAsStringSync();
    final usage = File(
      'lib/features/nutrition/repositories/meal_vision_usage_repository.dart',
    ).readAsStringSync();

    // Digits alone never invoke or invent a Gemini result. A genuine validated
    // cache/USDA miss explicitly asks for product-label evidence.
    expect(backend, contains('bil_get_cached_barcode'));
    expect(backend, contains('api.nal.usda.gov'));
    expect(backend, contains("next_step:'capture_product_label'"));
    expect(backend, isNot(contains('image_base64')));

    // The miss UI hands off only after the user accepts the label-photo guide.
    expect(foodPage, contains('_UnverifiedBarcodeAction.scanProductLabel'));
    expect(foodPage, contains('const MealImageGuidePage()'));
    expect(foodPage, contains('if (accepted == true && mounted)'));
    expect(foodPage, contains("'/intelligence-center?vision=capture&barcode="));
    expect(
      router,
      contains("state.uri.queryParameters['vision'] == 'capture'"),
    );
    expect(router, contains("state.uri.queryParameters['barcode']"));

    // Existing Vision performs the provider call, preserves server quota/
    // idempotency telemetry, and requires review without auto logging.
    expect(coach, contains('startWithVisionCapture'));
    expect(coach, contains('initialBarcode'));
    expect(coach, contains('await _analyzeFoodImageInChat()'));
    expect(coach, contains('showMealImageReviewDialog'));
    expect(coach, contains('Nothing was logged'));
    expect(coach, contains('Review and confirm a verified BIL food match'));
    expect(vision, contains("'x-idempotency-key': idempotencyKey"));
    expect(usage, contains("rpc('bil_get_ai_usage_status')"));
    expect(usage, isNot(contains("rpc('bil_get_vision_usage')")));
  });
}
