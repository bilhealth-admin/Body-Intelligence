import 'package:body_intelligence_log/features/intelligence_center/domain/coach_action_admission.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_intent_normalizer.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const api = DeterministicLocalCoachApi();
  const admission = CoachActionAdmission();
  for (final phrase in [
    'دخللي وزني 82.5',
    'دخل لي وزني ٨٢ ونص',
    'حط وزني 82.5 حق يوم الأحد',
    'اكتب وزني 82.5',
    'دير وزني 82.5',
  ]) {
    test(
      'bounded dialect verb retains a real body-weight action: $phrase',
      () async {
        for (final channel in CoachInputChannel.values) {
          final response = await api.understand(
            LocalCoachRequest(text: phrase, locale: 'ar', channel: channel),
          );
          expect(response.actions, hasLength(1));
          final action = response.actions.single;
          expect(action.type, IntelligenceActionType.addWeight);
          expect(action.payload['weightKg'], 82.5);
          expect(action.requiresConfirmation, true);
        }
      },
    );
  }
  for (final phrase in [
    'دخللي وزني 82.5 سمك',
    'حط وزني 70 أو 80',
    'اكتب وزني 80 stones',
    'دير وزني 82.5 كيلو ووجبة رز',
    'دخللي وزن الطعام 82.5 كيلو',
    'حط وزني 82.5 وامسح السابق',
    'اكتب وزني 82.5 حق شخص آخر',
  ]) {
    test(
      'dialect verb never discards food, ambiguity, correction or owner words: $phrase',
      () async {
        for (final channel in CoachInputChannel.values) {
          final response = await api.understand(
            LocalCoachRequest(text: phrase, locale: 'ar', channel: channel),
          );
          expect(
            response.actions.where(
              (action) => admission.bind(action)?.writesData == true,
            ),
            isEmpty,
          );
        }
      },
    );
  }
}
