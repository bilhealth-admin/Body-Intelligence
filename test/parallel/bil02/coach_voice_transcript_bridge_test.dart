import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_media_attempt.dart';
import 'package:body_intelligence_log/features/intelligence_center/media_bridge/coach_voice_transcript_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('partials remain editable drafts and never submit automatically', () {
    final state = _VoiceState();
    final bridge = CoachVoiceTranscriptBridge();
    final attempt = state.begin();

    expect(bridge.begin(attempt), isTrue);
    expect(bridge.acceptPartial(attempt, '  أكلت  '), isTrue);
    expect(bridge.acceptPartial(attempt, 'أكلت بيضتين'), isTrue);
    expect(bridge.draftText, 'أكلت بيضتين');
    expect(bridge.hasFinal, isFalse);
    expect(bridge.isReadyForReview, isFalse);
    expect(bridge.takeForSubmission(attempt), isNull);
    expect(attempt.isClaimed, isFalse);
  });

  test(
    'final is reviewable and late partials or duplicate finals cannot edit it',
    () {
      final state = _VoiceState();
      final bridge = CoachVoiceTranscriptBridge();
      final attempt = state.begin();
      bridge.begin(attempt);
      bridge.acceptPartial(attempt, 'ate one egg', languageTag: ' en-US ');

      expect(
        bridge.acceptFinal(attempt, '  ate two eggs ', languageTag: ' en-GB '),
        isTrue,
      );
      expect(bridge.hasFinal, isTrue);
      expect(bridge.isReadyForReview, isTrue);
      expect(attempt.isClaimed, isFalse);
      expect(
        bridge.acceptPartial(attempt, 'old partial', languageTag: 'fr-FR'),
        isFalse,
      );
      expect(
        bridge.acceptFinal(attempt, 'duplicate final', languageTag: 'de-DE'),
        isFalse,
      );
      expect(bridge.draftText, 'ate two eggs');
      expect(bridge.languageTag, 'en-GB');
    },
  );

  test('user correction after final is the exact text submitted once', () {
    final state = _VoiceState();
    final bridge = CoachVoiceTranscriptBridge();
    final attempt = state.begin();
    bridge.begin(attempt);
    bridge.acceptFinal(attempt, 'أكلت بيضة', languageTag: 'ar-EG');

    expect(bridge.updateDraft(attempt, '  أكلت بيضتين  '), isTrue);
    expect(bridge.draftText, '  أكلت بيضتين  ');
    final submission = bridge.takeForSubmission(attempt);
    expect(submission, isNotNull);
    expect(submission!.text, 'أكلت بيضتين');
    expect(submission.languageTag, 'ar-EG');
    expect(submission.attempt, same(attempt));
    expect(submission.attempt.isCurrent, isTrue);
    expect(bridge.takeForSubmission(attempt), isNull);
    expect(bridge.updateDraft(attempt, 'late correction'), isFalse);
    expect(bridge.acceptFinal(attempt, 'late duplicate'), isFalse);
    expect(bridge.draftText, isEmpty);
  });

  test('user correction before final wins over both late callback types', () {
    final state = _VoiceState();
    final bridge = CoachVoiceTranscriptBridge();
    final attempt = state.begin();
    bridge.begin(attempt);
    bridge.acceptPartial(attempt, 'ate too');

    expect(bridge.updateDraft(attempt, 'ate two eggs'), isTrue);
    expect(bridge.acceptPartial(attempt, 'ate too much'), isFalse);
    expect(bridge.acceptFinal(attempt, 'ate too much food'), isFalse);
    expect(bridge.hasFinal, isFalse);
    expect(bridge.isReadyForReview, isTrue);
    expect(bridge.takeForSubmission(attempt)!.text, 'ate two eggs');
  });

  test(
    'finish freezes a partial for explicit review without fabricating final',
    () {
      final state = _VoiceState();
      final bridge = CoachVoiceTranscriptBridge();
      final attempt = state.begin();
      bridge.begin(attempt);
      bridge.acceptPartial(attempt, 'ate an apple');

      expect(bridge.finish(attempt), isTrue);
      expect(bridge.hasFinal, isFalse);
      expect(bridge.isReadyForReview, isTrue);
      expect(attempt.isClaimed, isFalse);
      expect(bridge.finish(attempt), isFalse);
      expect(bridge.acceptPartial(attempt, 'late partial'), isFalse);
      expect(bridge.acceptFinal(attempt, 'late final'), isFalse);
      expect(bridge.takeForSubmission(attempt)!.text, 'ate an apple');
    },
  );

  test('empty callbacks and empty corrected drafts never claim a request', () {
    final state = _VoiceState();
    final bridge = CoachVoiceTranscriptBridge();
    final attempt = state.begin();
    bridge.begin(attempt);

    expect(bridge.acceptPartial(attempt, ' \n '), isFalse);
    expect(bridge.acceptFinal(attempt, ' \t '), isFalse);
    expect(bridge.hasFinal, isFalse);
    bridge.acceptFinal(attempt, 'ate an egg');
    expect(bridge.updateDraft(attempt, '   '), isTrue);
    expect(bridge.isReadyForReview, isFalse);
    expect(bridge.takeForSubmission(attempt), isNull);
    expect(attempt.isClaimed, isFalse);
    expect(bridge.updateDraft(attempt, 'corrected food'), isTrue);
    expect(bridge.takeForSubmission(attempt)!.text, 'corrected food');
  });

  test(
    'finish without recognized words needs a user draft before submission',
    () {
      final state = _VoiceState();
      final bridge = CoachVoiceTranscriptBridge();
      final attempt = state.begin();
      bridge.begin(attempt);

      expect(bridge.finish(attempt), isTrue);
      expect(bridge.isReadyForReview, isFalse);
      expect(bridge.takeForSubmission(attempt), isNull);
      expect(bridge.acceptFinal(attempt, 'late words'), isFalse);
      expect(bridge.updateDraft(attempt, 'user typed correction'), isTrue);
      expect(bridge.takeForSubmission(attempt)!.text, 'user typed correction');
    },
  );

  test('a missing or blank language hint preserves the last accepted hint', () {
    final state = _VoiceState();
    final bridge = CoachVoiceTranscriptBridge();
    final attempt = state.begin();
    bridge.begin(attempt);
    bridge.acceptPartial(attempt, 'أكلت', languageTag: ' ar-EG ');
    bridge.acceptPartial(attempt, 'أكلت بيضتين', languageTag: '  ');
    bridge.acceptFinal(attempt, 'أكلت بيضتين');

    expect(bridge.takeForSubmission(attempt)!.languageTag, 'ar-EG');
  });

  test('stale identity cannot finish, edit, or submit a newer recording', () {
    final state = _VoiceState();
    final bridge = CoachVoiceTranscriptBridge();
    final oldAttempt = state.begin();
    bridge.begin(oldAttempt);
    bridge.acceptPartial(oldAttempt, 'old draft', languageTag: 'en-US');
    final currentAttempt = state.begin();
    expect(bridge.begin(currentAttempt), isTrue);
    bridge.acceptPartial(currentAttempt, 'current draft', languageTag: 'ar-EG');

    expect(oldAttempt.isCurrent, isFalse);
    expect(bridge.acceptPartial(oldAttempt, 'stale partial'), isFalse);
    expect(bridge.acceptFinal(oldAttempt, 'stale final'), isFalse);
    expect(bridge.updateDraft(oldAttempt, 'stale edit'), isFalse);
    expect(bridge.finish(oldAttempt), isFalse);
    expect(bridge.takeForSubmission(oldAttempt), isNull);
    expect(bridge.draftText, 'current draft');
    expect(bridge.languageTag, 'ar-EG');
    expect(bridge.hasFinal, isFalse);
    expect(bridge.finish(currentAttempt), isTrue);
    expect(bridge.takeForSubmission(currentAttempt)!.text, 'current draft');
  });

  test('the same words in two deliberate attempts are two valid turns', () {
    final state = _VoiceState();
    final bridge = CoachVoiceTranscriptBridge();
    final first = state.begin();
    bridge.begin(first);
    bridge.acceptFinal(first, 'same synthetic text');
    final firstSubmission = bridge.takeForSubmission(first);
    state.requestGeneration++;
    final second = state.begin();
    bridge.begin(second);
    bridge.acceptFinal(second, 'same synthetic text');
    final secondSubmission = bridge.takeForSubmission(second);

    expect(firstSubmission!.text, secondSubmission!.text);
    expect(secondSubmission.attempt, isNot(same(firstSubmission.attempt)));
    expect(bridge.takeForSubmission(first), isNull);
    expect(bridge.takeForSubmission(second), isNull);
  });

  test('beginning the same attempt cannot reopen final or consumed state', () {
    final state = _VoiceState();
    final bridge = CoachVoiceTranscriptBridge();
    final attempt = state.begin();
    bridge.begin(attempt);
    bridge.acceptFinal(attempt, 'frozen final');

    expect(bridge.begin(attempt), isFalse);
    expect(bridge.acceptPartial(attempt, 'late partial'), isFalse);
    expect(bridge.takeForSubmission(attempt)!.text, 'frozen final');
    expect(bridge.begin(attempt), isFalse);
    expect(bridge.takeForSubmission(attempt), isNull);
  });

  test('two bridges sharing an attempt still permit only one submission', () {
    final state = _VoiceState();
    final attempt = state.begin();
    final first = CoachVoiceTranscriptBridge()..begin(attempt);
    final second = CoachVoiceTranscriptBridge()..begin(attempt);
    first.acceptFinal(attempt, 'first bridge');
    second.acceptFinal(attempt, 'second bridge');

    expect(first.takeForSubmission(attempt)!.text, 'first bridge');
    expect(second.takeForSubmission(attempt), isNull);
    expect(second.draftText, isEmpty);
  });

  test(
    'cancel keeps late results out and a fresh attempt remains possible',
    () {
      final state = _VoiceState();
      final bridge = CoachVoiceTranscriptBridge();
      final oldAttempt = state.begin();
      bridge.begin(oldAttempt);
      bridge.acceptPartial(oldAttempt, 'cancelled draft');
      bridge.cancel();

      expect(bridge.draftText, isEmpty);
      expect(bridge.acceptFinal(oldAttempt, 'late final'), isFalse);
      expect(bridge.finish(oldAttempt), isFalse);
      expect(bridge.takeForSubmission(oldAttempt), isNull);
      expect(bridge.begin(oldAttempt), isFalse);
      expect(bridge.begin(state.begin()), isTrue);
    },
  );

  test(
    'dispose invalidates a taken submission and rejects future attempts',
    () {
      final state = _VoiceState();
      final bridge = CoachVoiceTranscriptBridge();
      final attempt = state.begin();
      bridge.begin(attempt);
      bridge.acceptFinal(attempt, 'ready for existing query path');
      final submission = bridge.takeForSubmission(attempt)!;
      bridge.dispose();
      bridge.dispose();

      expect(submission.attempt.isCurrent, isFalse);
      expect(submission.attempt.isDisposed, isTrue);
      expect(bridge.begin(state.begin()), isFalse);
      expect(bridge.acceptPartial(attempt, 'late partial'), isFalse);
      expect(bridge.acceptFinal(attempt, 'late final'), isFalse);
      expect(bridge.finish(attempt), isFalse);
      expect(bridge.updateDraft(attempt, 'late edit'), isFalse);
      expect(bridge.takeForSubmission(attempt), isNull);
      expect(bridge.draftText, isEmpty);
    },
  );

  for (final change in ['owner', 'conversation', 'request', 'permission']) {
    test('$change change hides draft and rejects all stale callbacks', () {
      final state = _VoiceState();
      final bridge = CoachVoiceTranscriptBridge();
      final attempt = state.begin();
      bridge.begin(attempt);
      bridge.acceptFinal(
        attempt,
        'synthetic private draft',
        languageTag: 'ar-EG',
      );
      switch (change) {
        case 'owner':
          state.owner = CoachFoodOwnerStamp(ownerKey: 'synthetic-b', epoch: 1);
        case 'conversation':
          state.conversationEpoch++;
        case 'request':
          state.requestGeneration++;
        case 'permission':
          state.authorized = false;
      }

      expect(bridge.draftText, isEmpty);
      expect(bridge.languageTag, isNull);
      expect(bridge.hasFinal, isFalse);
      expect(bridge.isReadyForReview, isFalse);
      expect(bridge.acceptPartial(attempt, 'stale partial'), isFalse);
      expect(bridge.acceptFinal(attempt, 'stale final'), isFalse);
      expect(bridge.updateDraft(attempt, 'stale edit'), isFalse);
      expect(bridge.finish(attempt), isFalse);
      expect(bridge.takeForSubmission(attempt), isNull);
      expect(attempt.isClaimed, isFalse);

      state.owner = CoachFoodOwnerStamp(ownerKey: 'synthetic-a', epoch: 0);
      state.conversationEpoch = 0;
      state.requestGeneration = 0;
      state.authorized = true;
      expect(bridge.takeForSubmission(attempt), isNull);
      expect(bridge.acceptFinal(attempt, 'cannot revive'), isFalse);
    });
  }

  test(
    'account observer cancellation rejects A to B to A before any callback',
    () {
      final state = _VoiceState();
      final bridge = CoachVoiceTranscriptBridge();
      final attempt = state.begin();
      bridge.begin(attempt);
      bridge.acceptPartial(attempt, 'before account switch');
      state.owner = CoachFoodOwnerStamp(ownerKey: 'synthetic-b', epoch: 1);
      attempt.ownerScope.cancel();
      state.owner = CoachFoodOwnerStamp(ownerKey: 'synthetic-a', epoch: 0);

      expect(bridge.acceptFinal(attempt, 'late final'), isFalse);
      expect(bridge.finish(attempt), isFalse);
      expect(bridge.draftText, isEmpty);
      expect(bridge.takeForSubmission(attempt), isNull);
    },
  );

  test(
    'failed provider reads clear the draft without throwing or claiming',
    () {
      final state = _VoiceState();
      final bridge = CoachVoiceTranscriptBridge();
      final attempt = state.begin();
      bridge.begin(attempt);
      bridge.acceptFinal(attempt, 'synthetic draft');
      state.readerDisposed = true;

      expect(bridge.draftText, isEmpty);
      expect(bridge.takeForSubmission(attempt), isNull);
      expect(attempt.isClaimed, isFalse);
      state.readerDisposed = false;
      expect(bridge.updateDraft(attempt, 'cannot revive'), isFalse);
    },
  );

  test('authority is rechecked when taking a reviewed draft', () {
    final state = _VoiceState();
    final bridge = CoachVoiceTranscriptBridge();
    final attempt = state.begin();
    bridge.begin(attempt);
    bridge.acceptFinal(attempt, 'reviewed text');
    expect(bridge.isReadyForReview, isTrue);
    state.authorized = false;

    expect(bridge.takeForSubmission(attempt), isNull);
    expect(attempt.isClaimed, isFalse);
  });
}

final class _VoiceState {
  CoachFoodOwnerStamp owner = CoachFoodOwnerStamp(
    ownerKey: 'synthetic-a',
    epoch: 0,
  );
  int conversationEpoch = 0;
  int requestGeneration = 0;
  bool authorized = true;
  bool readerDisposed = false;

  CoachMediaAttempt begin() => CoachMediaAttempt(
    ownerScope: CoachFoodOwnerScope(
      captured: owner,
      readCurrent: () {
        if (readerDisposed) throw StateError('synthetic disposed owner reader');
        return owner;
      },
    ),
    conversationEpoch: conversationEpoch,
    requestGeneration: requestGeneration,
    readConversationEpoch: () => conversationEpoch,
    readRequestGeneration: () => requestGeneration,
    isAuthorized: () => authorized,
  );
}
