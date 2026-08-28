import 'dart:io';

import 'package:body_intelligence_log/app/services/store_review_prompt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _ReviewGateway implements StoreReviewGateway {
  bool available = true;
  int availabilityChecks = 0;
  int requests = 0;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return available;
  }

  @override
  Future<void> requestReview() async {
    requests++;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('waits for five successful days and seven days of experience', () async {
    final gateway = _ReviewGateway();
    var now = DateTime.utc(2026, 8, 1, 12);
    final service = StoreReviewPromptService(
      gateway: gateway,
      now: () => now,
      isSupportedPlatform: () => true,
      presentationDelay: Duration.zero,
    );

    for (var day = 0; day < 5; day++) {
      now = DateTime.utc(2026, 8, 1 + day, 12);
      expect(
        await service.recordPositiveMoment(StoreReviewMoment.dailyCheckIn),
        StoreReviewOutcome.notYetEligible,
      );
    }
    expect(gateway.requests, 0);

    now = DateTime.utc(2026, 8, 8, 12);
    expect(
      await service.recordPositiveMoment(StoreReviewMoment.diaryCompleted),
      StoreReviewOutcome.requested,
    );
    expect(gateway.requests, 1);
  });

  test(
    'counts a calendar day once and enforces the 180-day cooldown',
    () async {
      final gateway = _ReviewGateway();
      var now = DateTime.utc(2026, 8, 1, 12);
      final service = StoreReviewPromptService(
        gateway: gateway,
        now: () => now,
        isSupportedPlatform: () => true,
        presentationDelay: Duration.zero,
      );

      await service.recordPositiveMoment(StoreReviewMoment.dailyCheckIn);
      await service.recordPositiveMoment(StoreReviewMoment.diaryCompleted);
      for (final day in [2, 3, 4, 5]) {
        now = DateTime.utc(2026, 8, day, 12);
        await service.recordPositiveMoment(StoreReviewMoment.dailyCheckIn);
      }
      now = DateTime.utc(2026, 8, 8, 12);
      expect(
        await service.recordPositiveMoment(StoreReviewMoment.planSaved),
        StoreReviewOutcome.requested,
      );
      expect(
        await service.recordPositiveMoment(StoreReviewMoment.diaryCompleted),
        StoreReviewOutcome.coolingDown,
      );
      expect(gateway.requests, 1);
    },
  );

  test('never calls the store on unsupported platforms', () async {
    final gateway = _ReviewGateway();
    final service = StoreReviewPromptService(
      gateway: gateway,
      isSupportedPlatform: () => false,
      presentationDelay: Duration.zero,
    );

    expect(
      await service.recordPositiveMoment(StoreReviewMoment.planSaved),
      StoreReviewOutcome.unsupported,
    );
    expect(gateway.availabilityChecks, 0);
    expect(gateway.requests, 0);
  });

  test('store unavailability does not burn the local cooldown', () async {
    final gateway = _ReviewGateway()..available = false;
    var now = DateTime.utc(2026, 8, 1, 12);
    final service = StoreReviewPromptService(
      gateway: gateway,
      now: () => now,
      isSupportedPlatform: () => true,
      presentationDelay: Duration.zero,
    );

    for (final day in <int>[1, 2, 3, 4, 5]) {
      now = DateTime.utc(2026, 8, day, 12);
      await service.recordPositiveMoment(StoreReviewMoment.dailyCheckIn);
    }
    now = DateTime.utc(2026, 8, 8, 12);
    expect(
      await service.recordPositiveMoment(StoreReviewMoment.diaryCompleted),
      StoreReviewOutcome.unavailable,
    );
    expect(gateway.requests, 0);

    gateway.available = true;
    expect(
      await service.recordPositiveMoment(StoreReviewMoment.planSaved),
      StoreReviewOutcome.requested,
    );
    expect(gateway.requests, 1);
  });

  test('Google Play review boundary has no custom prompt or sentiment gate', () {
    final serviceSource = File(
      'lib/app/services/store_review_prompt_service.dart',
    ).readAsStringSync();
    final appSource = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(serviceSource, contains('_review.requestReview()'));
    expect(serviceSource, isNot(contains('openStoreListing')));
    expect(serviceSource, isNot(contains('showDialog')));
    expect(serviceSource, isNot(contains('showModalBottomSheet')));
    expect(appSource, isNot(contains('Do you like BIL')));
    expect(appSource, isNot(contains('Would you rate BIL 5 stars')));
    expect(
      RegExp(
        r'\.recordPositiveMoment\(StoreReviewMoment\.',
      ).allMatches(appSource).length,
      3,
      reason:
          'Only the three audited post-success moments may request Play review.',
    );
  });
}
