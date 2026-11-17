import 'package:body_intelligence_log/features/commerce/services/store_verification_request_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late StoreVerificationRequestPolicy policy;
  setUp(() {
    now = DateTime.utc(2026, 11, 16, 13);
    policy = StoreVerificationRequestPolicy(clock: () => now);
  });

  test('429 respects server Retry-After and isolates account owners', () {
    policy.observeFailure(
      ownerId: 'A',
      status: 429,
      body: {'error': 'rate_limited', 'retry_after_seconds': 120},
    );
    expect(policy.isBackedOff('A'), isTrue);
    expect(policy.isBackedOff('B'), isFalse);
    now = now.add(const Duration(seconds: 119));
    expect(policy.isBackedOff('A'), isTrue);
    now = now.add(const Duration(seconds: 1));
    expect(policy.isBackedOff('A'), isFalse);
  });

  test('legacy 503 rate_limited gets a bounded compatibility pause', () {
    policy.observeFailure(
      ownerId: 'A',
      status: 503,
      body: {'error': 'rate_limited'},
    );
    now = now.add(const Duration(seconds: 299));
    expect(policy.isBackedOff('A'), isTrue);
    now = now.add(const Duration(seconds: 1));
    expect(policy.isBackedOff('A'), isFalse);
  });

  test(
    'auth failures and unavailable quota infrastructure invent no denial',
    () {
      for (final failure in [
        (503, {'error': 'rate_limit_unavailable'}),
        (401, {'error': 'rate_limited', 'retry_after_seconds': 120}),
        (429, {'error': 'unknown'}),
      ]) {
        policy.observeFailure(
          ownerId: 'A',
          status: failure.$1,
          body: failure.$2,
        );
      }
      expect(policy.isBackedOff('A'), isFalse);
    },
  );

  test('malformed Retry-After is bounded and cannot shorten a known pause', () {
    policy.observeFailure(
      ownerId: 'A',
      status: 429,
      body: {'error': 'rate_limited', 'retry_after_seconds': 3600},
    );
    for (final invalid in [-1, 0, 3601, '3600', double.infinity]) {
      policy.observeFailure(
        ownerId: 'A',
        status: 429,
        body: {'error': 'rate_limited', 'retry_after_seconds': invalid},
      );
    }
    now = now.add(const Duration(seconds: 3599));
    expect(policy.isBackedOff('A'), isTrue);
    now = now.add(const Duration(seconds: 1));
    expect(policy.isBackedOff('A'), isFalse);
  });

  String key({
    String owner = 'A',
    String proof = 'signed-active',
    String status = 'purchased',
  }) => storeReceiptReplayKey(
    ownerId: owner,
    source: 'app_store',
    productId: 'fixture-subscription',
    purchaseId: 'same-transaction',
    status: status,
    verificationData: proof,
  );

  test('settled identical callbacks are bounded, without caching access', () {
    final original = key();
    expect(policy.isSettledReplay(original), isFalse);
    policy.rememberSettled(original);
    expect(policy.isSettledReplay(original), isTrue);
    expect(policy.isSettledReplay(key(owner: 'B')), isFalse);
    expect(policy.isSettledReplay(key(proof: 'signed-revoked')), isFalse);
    expect(policy.isSettledReplay(key(status: 'restored')), isFalse);
    now = now.add(const Duration(hours: 1));
    expect(policy.isSettledReplay(original), isFalse);
  });

  test('settled history cannot grow process memory without a bound', () {
    for (var index = 0; index < 513; index++) {
      policy.rememberSettled('fixture-$index');
    }
    expect(policy.isSettledReplay('fixture-0'), isFalse);
    expect(policy.isSettledReplay('fixture-512'), isTrue);
  });
}
