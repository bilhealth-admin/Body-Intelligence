import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../safety_moderation/domain/ai_coach_safety_report.dart';
import 'local_model_gateway.dart';

final aiCoachSafetyReportServiceProvider = Provider<AiCoachSafetyReportService>(
  (_) => const AiCoachSafetyReportService(),
);

class AiCoachSafetyReportService {
  const AiCoachSafetyReportService({this.clientOverride});

  final SupabaseClient? clientOverride;

  Future<AiCoachSafetyReportReceipt> submit({
    required String responseId,
    required String answerText,
    required String reason,
    required bool explicitConsentAccepted,
    required String locale,
    required CoachAnswerRuntime runtime,
    String? userNote,
  }) async {
    final client = clientOverride ?? Supabase.instance.client;
    final ownerId = client.auth.currentUser?.id;
    if (client.auth.currentSession == null || ownerId == null) {
      throw StateError('authentication_required');
    }
    final normalizedId = responseId.trim();
    final normalizedLocale = locale.trim().toLowerCase();
    final trimmedNote = userNote?.trim();
    final normalizedNote = trimmedNote == null || trimmedNote.isEmpty
        ? null
        : trimmedNote;
    if (normalizedId.length < 8 ||
        normalizedId.length > 128 ||
        answerText.trim().isEmpty ||
        answerText.length > 12000 ||
        !explicitConsentAccepted ||
        !const {
          'unsafe',
          'offensive',
          'medical_accuracy',
          'other',
        }.contains(reason) ||
        (normalizedNote != null &&
            (reason != 'other' ||
                normalizedNote.isEmpty ||
                normalizedNote.runes.length > 1000 ||
                utf8.encode(normalizedNote).length > 4000)) ||
        !RegExp(r'^[a-zA-Z0-9-]{2,16}$').hasMatch(normalizedLocale)) {
      throw const FormatException('invalid_ai_coach_safety_report');
    }
    final result = await client.rpc(
      'bil_submit_ai_coach_safety_report_v1',
      params: <String, Object?>{
        'p_response_id': normalizedId,
        'p_answer_text': answerText,
        'p_reason': reason,
        'p_user_note': normalizedNote,
        'p_consent_confirmed': explicitConsentAccepted,
        'p_locale': normalizedLocale,
        'p_runtime': switch (runtime) {
          CoachAnswerRuntime.cloudPersonalized => 'cloud_personalized',
          CoachAnswerRuntime.onDevice => 'on_device',
          CoachAnswerRuntime.localFallback => 'local_fallback',
        },
      },
    );
    if (client.auth.currentUser?.id != ownerId) {
      throw StateError('account_changed_during_ai_coach_report');
    }
    return AiCoachSafetyReportReceipt.fromJson(result);
  }
}
