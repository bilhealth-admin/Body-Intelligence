import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_media_attempt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'one claim leaves authority checkable across asynchronous boundaries',
    () {
      final state = _AttemptState();
      final attempt = state.begin();

      expect(attempt.canAcceptResult, isTrue);
      expect(attempt.tryClaim(), isTrue);
      expect(attempt.isClaimed, isTrue);
      expect(attempt.isCurrent, isTrue);
      expect(attempt.canAcceptResult, isFalse);
      expect(attempt.tryClaim(), isFalse);

      state.requestGeneration++;
      expect(attempt.isCurrent, isFalse);
      expect(attempt.isClaimed, isTrue);
    },
  );

  test('negative captured conversation and request values are rejected', () {
    final state = _AttemptState();
    state.conversationEpoch = -1;
    expect(state.begin, throwsArgumentError);
    state.conversationEpoch = 0;
    state.requestGeneration = -1;
    expect(state.begin, throwsArgumentError);
  });

  test('a reentrant authorization reader cannot grant two claims', () {
    final owner = CoachFoodOwnerStamp(ownerKey: 'synthetic-a', epoch: 0);
    late CoachMediaAttempt attempt;
    var enteredReader = false;
    bool? nestedClaim;
    attempt = CoachMediaAttempt(
      ownerScope: CoachFoodOwnerScope(
        captured: owner,
        readCurrent: () => owner,
      ),
      conversationEpoch: 0,
      requestGeneration: 0,
      readConversationEpoch: () => 0,
      readRequestGeneration: () => 0,
      isAuthorized: () {
        if (!enteredReader) {
          enteredReader = true;
          nestedClaim = attempt.tryClaim();
        }
        return true;
      },
    );

    expect(attempt.tryClaim(), isFalse);
    expect(nestedClaim, isTrue);
    expect(attempt.isClaimed, isTrue);
    expect(attempt.tryClaim(), isFalse);
    expect(attempt.isCurrent, isTrue);
  });

  test('a different owner cannot return a result even with the same epoch', () {
    final state = _AttemptState();
    final attempt = state.begin();
    state.owner = CoachFoodOwnerStamp(ownerKey: 'synthetic-b', epoch: 0);

    expect(attempt.tryClaim(), isFalse);
    state.owner = CoachFoodOwnerStamp(ownerKey: 'synthetic-a', epoch: 0);
    expect(attempt.isCurrent, isFalse);
  });

  test('same owner after A to B to A still has a different owner epoch', () {
    final state = _AttemptState();
    final attempt = state.begin();
    state.owner = CoachFoodOwnerStamp(ownerKey: 'synthetic-b', epoch: 1);
    state.owner = CoachFoodOwnerStamp(ownerKey: 'synthetic-a', epoch: 2);

    expect(attempt.isCurrent, isFalse);
    expect(attempt.tryClaim(), isFalse);
  });

  test(
    'owner observer cancellation blocks an unobserved account round trip',
    () {
      final state = _AttemptState();
      final attempt = state.begin();
      state.owner = CoachFoodOwnerStamp(ownerKey: 'synthetic-b', epoch: 1);
      attempt.ownerScope.cancel();
      state.owner = CoachFoodOwnerStamp(ownerKey: 'synthetic-a', epoch: 0);

      expect(attempt.isCurrent, isFalse);
      expect(attempt.canAcceptResult, isFalse);
    },
  );

  test('conversation replacement permanently invalidates the old attempt', () {
    final state = _AttemptState();
    final attempt = state.begin();
    state.conversationEpoch++;

    expect(attempt.isCurrent, isFalse);
    state.conversationEpoch--;
    expect(attempt.isCurrent, isFalse);
    expect(attempt.tryClaim(), isFalse);
  });

  test('request replacement permanently invalidates the old attempt', () {
    final state = _AttemptState();
    final attempt = state.begin();
    state.requestGeneration++;

    expect(attempt.canAcceptResult, isFalse);
    state.requestGeneration--;
    expect(attempt.tryClaim(), isFalse);
  });

  test('permission restoration requires a new attempt after revocation', () {
    final state = _AttemptState();
    final attempt = state.begin();
    state.authorized = false;

    expect(attempt.isCurrent, isFalse);
    state.authorized = true;
    expect(attempt.tryClaim(), isFalse);
    expect(state.begin().tryClaim(), isTrue);
  });

  test(
    'explicit cancellation is terminal without reading disposed providers',
    () {
      final state = _AttemptState();
      final attempt = state.begin();
      attempt.cancel();
      state.throwAt = 'owner';

      expect(attempt.isCancelled, isTrue);
      expect(attempt.isDisposed, isFalse);
      expect(attempt.isCurrent, isFalse);
      expect(attempt.tryClaim(), isFalse);
      expect(state.readCount, 0);
    },
  );

  test('disposal is terminal even for a previously claimed result', () {
    final state = _AttemptState();
    final attempt = state.begin();
    expect(attempt.tryClaim(), isTrue);
    final readsBeforeDispose = state.readCount;
    attempt.dispose();
    attempt.dispose();
    state.throwAt = 'owner';

    expect(attempt.isDisposed, isTrue);
    expect(attempt.isCancelled, isTrue);
    expect(attempt.isCurrent, isFalse);
    expect(attempt.tryClaim(), isFalse);
    expect(state.readCount, readsBeforeDispose);
  });

  for (final reader in ['owner', 'conversation', 'request', 'permission']) {
    test('$reader reader exceptions fail closed and cannot revive', () {
      final state = _AttemptState();
      final attempt = state.begin();
      state.throwAt = reader;

      expect(attempt.isCurrent, isFalse);
      state.throwAt = null;
      expect(attempt.isCurrent, isFalse);
      expect(attempt.tryClaim(), isFalse);
    });
  }
}

final class _AttemptState {
  CoachFoodOwnerStamp owner = CoachFoodOwnerStamp(
    ownerKey: 'synthetic-a',
    epoch: 0,
  );
  int conversationEpoch = 0;
  int requestGeneration = 0;
  bool authorized = true;
  String? throwAt;
  int readCount = 0;

  T read<T>(String name, T value) {
    readCount++;
    if (throwAt == name) throw StateError('synthetic disposed $name reader');
    return value;
  }

  CoachMediaAttempt begin() => CoachMediaAttempt(
    ownerScope: CoachFoodOwnerScope(
      captured: owner,
      readCurrent: () => read('owner', owner),
    ),
    conversationEpoch: conversationEpoch,
    requestGeneration: requestGeneration,
    readConversationEpoch: () => read('conversation', conversationEpoch),
    readRequestGeneration: () => read('request', requestGeneration),
    isAuthorized: () => read('permission', authorized),
  );
}
