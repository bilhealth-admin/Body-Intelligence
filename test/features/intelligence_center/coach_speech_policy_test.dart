import 'package:body_intelligence_log/features/intelligence_center/services/coach_speech_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/bil_text_to_speech.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const policy = CoachSpeechPolicy();

  test('personal lookup acknowledges before writing while sleep is direct', () {
    expect(policy.planFor('كم وزني؟'), CoachSpeechPlan.dataLookup);
    expect(policy.isWeightLookup('كم وزني؟'), isTrue);
    expect(policy.planFor('How much do I weigh?'), CoachSpeechPlan.dataLookup);
    expect(policy.planFor('كم لازم أنام؟'), CoachSpeechPlan.directAnswer);
    expect(
      policy.planFor('How much should I sleep?'),
      CoachSpeechPlan.directAnswer,
    );
    expect(policy.isSleepQuestion('كم لازم أنام؟'), isTrue);
    expect(policy.isSleepQuestion('How much should I sleep?'), isTrue);
    expect(policy.isSleepQuestion('Wie lange soll ich schlafen?'), isTrue);
    expect(policy.isSleepQuestion('person weight'), isFalse);
  });

  test('goal analysis acknowledges before visible recommendations', () {
    expect(
      policy.planFor('احسب متى أصل لهدفي مع الرياضة والدايت'),
      CoachSpeechPlan.goalAnalysis,
    );
    expect(
      policy.planFor('Analyze when I can reach my goal with diet and exercise'),
      CoachSpeechPlan.goalAnalysis,
    );
    expect(
      policy.planFor('Why is my weight stable?'),
      CoachSpeechPlan.goalAnalysis,
    );
    expect(policy.isWeightLookup('Why is my weight stable?'), isFalse);
    expect(policy.isWeightLookup('How can I lose weight?'), isFalse);
    expect(policy.isWeightLookup('¿Cuánto peso?'), isTrue);
  });

  test('automatic full speech is bounded to about ten seconds', () {
    expect(
      policy.canSpeakWithinTenSeconds('Sleep seven to nine hours each night.'),
      isTrue,
    );
    expect(
      policy.canSpeakWithinTenSeconds(List.filled(30, 'word').join(' ')),
      isFalse,
    );
    expect(policy.canSpeakWithinTenSeconds('睡眠'.padRight(100, '眠')), isFalse);
  });

  test('saved profile sex selects the matching coach voice', () {
    expect(coachVoiceGenderForProfile('male'), BilCoachVoiceGender.male);
    expect(coachVoiceGenderForProfile(' FEMALE '), BilCoachVoiceGender.female);
    expect(coachVoiceGenderForProfile(null), BilCoachVoiceGender.system);
  });

  test('TTS bridge receives text locale and selected gender', () async {
    const channel = MethodChannel('bil/tts');
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await const BilTextToSpeech().speak(
      'مرحبًا، أنا بيل كوتش.',
      'ar',
      voiceGender: BilCoachVoiceGender.female,
    );

    expect(received?.method, 'speak');
    expect(received?.arguments, {
      'text': 'مرحبًا، أنا بيل كوتش.',
      'locale': 'ar',
      'voiceGender': 'female',
    });
  });

  test('TTS retries Arabic with a regional voice pack', () async {
    const channel = MethodChannel('bil/tts');
    final attempted = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final locale = (call.arguments as Map)['locale']!.toString();
          attempted.add(locale);
          if (locale == 'ar') {
            throw PlatformException(code: 'tts_locale_unavailable');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await const BilTextToSpeech().speak('مرحبًا', 'ar');

    expect(attempted, ['ar', 'ar-SA']);
  });
}
