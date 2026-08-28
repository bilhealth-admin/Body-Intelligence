import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test(
    'identity submissions preserve provenance without invented nutrition',
    () {
      final repository = source(
        'lib/features/community/data/community_repository.dart',
      );
      final method = repository.substring(
        repository.indexOf('Future<void> submitProductReview'),
        repository.indexOf(
          'Future<List<Map<String, dynamic>>> loadMyFoodSubmissions',
        ),
      );

      expect(method, contains("'observed_source'"));
      expect(method, contains("'observed_confidence'"));
      expect(method, contains("'submission_confidence': 'low'"));
      expect(method, isNot(contains("'calories_kcal'")));
      expect(method, isNot(contains("'protein_g'")));
      expect(method, isNot(contains("'carbohydrate_g'")));
      expect(method, isNot(contains("'fat_g'")));
    },
  );

  test('barcode journeys expose the moderated review path', () {
    final foodPage = source('lib/features/nutrition/food_page.dart');
    final dailyCaptureActions = source(
      'lib/features/daily_log/daily_log_capture_actions.dart',
    );
    final submission = source(
      'lib/features/community/presentation/product_review_submission_dialog.dart',
    );

    expect(foodPage, contains('showProductReviewSubmissionDialog'));
    expect(dailyCaptureActions, contains('showProductReviewSubmissionDialog'));
    expect(submission, contains('submitProductReview'));
    expect(submission, contains('will not become verified or searchable'));
    expect(submission, isNot(contains('calories_kcal')));
  });

  test('moderation is server-authorized and identity-only safe', () {
    final migration = source(
      'supabase/migrations/202608030001_bil_product_review_trust.sql',
    );
    final reviewPage = source(
      'lib/features/community/presentation/community_food_review_page.dart',
    );

    expect(migration, contains('bil_list_reviewable_products'));
    expect(migration, contains('bil_community_moderators'));
    expect(migration, contains('security definer'));
    expect(migration, contains('revoke all'));
    expect(reviewPage, contains('finalizeFoodSubmission'));
    expect(reviewPage, contains('Identity-only review'));
    expect(reviewPage, contains("item['calories_kcal'] != null"));
  });
}
