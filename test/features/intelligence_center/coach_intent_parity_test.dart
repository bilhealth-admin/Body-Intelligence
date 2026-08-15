import 'package:body_intelligence_log/features/intelligence_center/services/coach_intent_normalizer.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const api = DeterministicLocalCoachApi();

  test('text and voice use identical normalization and tool route', () async {
    const phrase = 'دخللي وزني ٨٩ ونص';
    final text = await api.understand(
      const LocalCoachRequest(text: phrase, locale: 'ar'),
    );
    final voice = await api.understand(
      const LocalCoachRequest(
        text: phrase,
        locale: 'ar',
        channel: CoachInputChannel.voice,
      ),
    );
    expect(text.actions, hasLength(1));
    expect(voice.actions, hasLength(1));
    expect(text.actions.single.type, voice.actions.single.type);
    expect(text.actions.single.payload, voice.actions.single.payload);
    expect(text.actions.single.payload['weightKg'], 89.5);
  });

  test('Egyptian, Levantine and Gulf weight variants converge', () async {
    const phrases = [
      'سجل وزني 89.5 يوم الحد',
      'دخللي وزني 89.5 عالأحد',
      'حط وزني 89.5 حق يوم الأحد',
    ];
    for (final phrase in phrases) {
      final result = await api.understand(
        LocalCoachRequest(text: phrase, locale: 'ar'),
      );
      expect(result.actions, hasLength(1), reason: phrase);
      expect(result.actions.single.payload['weightKg'], 89.5, reason: phrase);
    }
  });

  test('destructive dialect variant still requires confirmation', () async {
    final result = await api.understand(
      const LocalCoachRequest(text: 'امسح حسابي', locale: 'ar'),
    );
    expect(result.actions.single.requiresConfirmation, isTrue);
    expect(result.actions.single.destructive, isTrue);
  });

  test('theme and supported language commands are low-risk actions', () async {
    final theme = await api.understand(
      const LocalCoachRequest(text: 'شغل الوضع الليلي', locale: 'ar'),
    );
    final language = await api.understand(
      const LocalCoachRequest(text: 'غير اللغة للعربي', locale: 'ar'),
    );
    expect(theme.actions.single.payload['mode'], 'dark');
    expect(theme.actions.single.requiresConfirmation, isFalse);
    expect(language.actions.single.payload['locale'], 'ar');
    expect(language.actions.single.requiresConfirmation, isFalse);
  });

  test('expanded Arabic dialect and code-switch corpus converges', () async {
    const phrases = <String>[
      'سجل وزني ٨٢ ونص', // Egyptian
      'دخللي وزني 82.5', // Levantine
      'حط وزني 82.5', // Gulf
      'اكتب وزني 82.5', // Iraqi
      'دير وزني 82.5', // Maghrebi
      'سجل weight 82.5 كيلو', // code switch
    ];
    for (final phrase in phrases) {
      final typed = await api.understand(
        LocalCoachRequest(text: phrase, locale: 'ar'),
      );
      final voice = await api.understand(
        LocalCoachRequest(
          text: phrase,
          locale: 'ar',
          channel: CoachInputChannel.voice,
        ),
      );
      expect(typed.actions, hasLength(1), reason: phrase);
      expect(voice.actions, hasLength(1), reason: phrase);
      expect(typed.actions.single.payload['weightKg'], 82.5, reason: phrase);
      expect(voice.actions.single.payload, typed.actions.single.payload);
    }
  });
}
