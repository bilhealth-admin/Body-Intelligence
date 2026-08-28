import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_model_gateway.dart';

class AiCoachFeedbackService {
  const AiCoachFeedbackService();

  Future<void> record({
    required String responseId,
    required bool helpful,
    required String locale,
    required CoachAnswerRuntime runtime,
    String? reason,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw StateError('authentication_required');
    await Supabase.instance.client.rpc(
      'bil_record_ai_coach_feedback',
      params: <String, Object?>{
        'p_response_id': responseId,
        'p_helpful': helpful,
        'p_reason': reason,
        'p_locale': locale,
        'p_runtime': switch (runtime) {
          CoachAnswerRuntime.cloudPersonalized => 'cloud_personalized',
          CoachAnswerRuntime.onDevice => 'on_device',
          CoachAnswerRuntime.localFallback => 'local_fallback',
        },
      },
    );
  }
}
