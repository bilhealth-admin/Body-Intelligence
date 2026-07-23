import 'package:body_intelligence_log/features/commerce/domain/referral_attribution.dart';
import 'package:body_intelligence_log/features/commerce/domain/referral_decision.dart';
import 'package:body_intelligence_log/features/commerce/domain/referral_program.dart';
import 'package:body_intelligence_log/features/commerce/repositories/local_referral_repository.dart';
import 'package:body_intelligence_log/features/commerce/services/referral_attribution_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 23);

  test('attributes a new user deterministically and blocks duplicates', () {
    final repository = LocalReferralRepository();
    repository.saveProgram(_program(now));
    final engine = ReferralAttributionEngine(repository);

    final first = engine.attribute(
      code: 'creator10',
      referredUserId: 'new-user',
      source: ReferralAttributionSource.celebrity,
      now: now,
    );
    final duplicate = engine.attribute(
      code: 'CREATOR10',
      referredUserId: 'new-user',
      source: ReferralAttributionSource.celebrity,
      now: now,
    );

    expect(first.code, ReferralDecisionCode.accepted);
    expect(first.attribution!.referrerUserId, 'creator');
    expect(duplicate.code, ReferralDecisionCode.duplicateAttribution);
  });

  test('blocks self attribution', () {
    final repository = LocalReferralRepository()..saveProgram(_program(now));
    final decision = ReferralAttributionEngine(repository).attribute(
      code: 'CREATOR10',
      referredUserId: 'creator',
      source: ReferralAttributionSource.celebrity,
      now: now,
    );
    expect(decision.code, ReferralDecisionCode.selfAttribution);
  });

  test('creates and revokes commission without financial transfer', () {
    final repository = LocalReferralRepository()..saveProgram(_program(now));
    final engine = ReferralAttributionEngine(repository);
    final attribution = engine
        .attribute(
          code: 'CREATOR10',
          referredUserId: 'new-user',
          source: ReferralAttributionSource.blogger,
          now: now,
        )
        .attribution!;

    final commission = engine.createCommission(
      attribution: attribution,
      ownerUserId: 'creator',
      basisPoints: 1500,
      eligibleAmountMinorUnits: 10000,
      now: now,
    );
    expect(commission.commissionMinorUnits, 1500);

    final revoked = engine.revokeCommission(
      commission,
      now: now.add(const Duration(days: 1)),
      reason: 'subscription refunded',
    );
    expect(revoked.status.name, 'revoked');
  });
}

ReferralProgram _program(DateTime now) => ReferralProgram(
  id: 'program-1',
  code: 'creator10',
  ownerUserId: 'creator',
  startsAt: now.subtract(const Duration(days: 1)),
  endsAt: now.add(const Duration(days: 30)),
  attributionWindow: const Duration(days: 14),
  referrerReward: const ReferralReward(freeDays: 7, creditMinorUnits: 0),
  newUserReward: const ReferralReward(freeDays: 7, creditMinorUnits: 0),
  commissionBasisPoints: 1500,
);
