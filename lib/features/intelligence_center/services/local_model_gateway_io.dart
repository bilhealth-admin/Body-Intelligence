import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/security/bil_mobile_integrity_service.dart';
import '../domain/coach_context_snapshot.dart';
import 'coach_cloud_privacy_boundary.dart';
import 'local_model_gateway.dart';

export 'coach_cloud_privacy_boundary.dart';

LocalModelGateway createLocalModelGateway() => const LlamaCppLocalGateway();

/// Extracts the Edge Function's stable machine-readable error code without
/// normalizing it. Only an exact string can drive a purchase route; coercing
/// numbers or trimming whitespace would let an alias masquerade as the
/// release-approved `ai_usage_exhausted` code.
String? functionErrorCodeFromDetails(Object? details) {
  String? exactCode(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  if (details is Map) return exactCode(details['error']);
  if (details is! String) return null;
  try {
    final decoded = jsonDecode(details);
    return decoded is Map ? exactCode(decoded['error']) : null;
  } on FormatException {
    return null;
  }
}

/// A JSON response boundary small enough to fake without initializing
/// Supabase or making a network request.
class CoachCloudFunctionResponse {
  const CoachCloudFunctionResponse({required this.status, this.data});

  final int status;
  final Object? data;
}

/// Privacy-sensitive cloud operations used by the Coach gateway.
///
/// Keeping this boundary injectable makes it possible to prove that a denied,
/// failed, or signed-out consent preflight never invokes the Edge Function.
abstract interface class CoachCloudAccess {
  bool get hasAuthenticatedSession;

  Future<Object?> readRemoteAiConsent();

  Future<CoachCloudFunctionResponse> invokeCoach(Map<String, Object?> body);
}

class _SupabaseCoachCloudAccess implements CoachCloudAccess {
  const _SupabaseCoachCloudAccess(this.client);

  final SupabaseClient client;

  @override
  bool get hasAuthenticatedSession => client.auth.currentSession != null;

  @override
  Future<Object?> readRemoteAiConsent() =>
      client.rpc('bil_get_remote_ai_consent');

  @override
  Future<CoachCloudFunctionResponse> invokeCoach(
    Map<String, Object?> body,
  ) async {
    final protectedBody = await BilMobileIntegrityService.instance.protect(
      action: 'ai_coach.request',
      payload: body,
    );
    final response = await client.functions.invoke(
      'ai-coach',
      body: protectedBody,
    );
    return CoachCloudFunctionResponse(
      status: response.status,
      data: response.data,
    );
  }
}

class LlamaCppLocalGateway implements LocalModelGateway {
  const LlamaCppLocalGateway({
    this.endpoint = const String.fromEnvironment(
      'BIL_LOCAL_AI_URL',
      defaultValue: '',
    ),
    this.apiKey = const String.fromEnvironment('BIL_LOCAL_AI_API_KEY'),
    this.cloudAccess,
    this.cloudContextProjector =
        const QuestionScopedCoachCloudContextProjector(),
  });

  final String endpoint;
  final String apiKey;
  final CoachCloudAccess? cloudAccess;
  final CoachCloudContextProjector cloudContextProjector;

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    Future<LocalModelResult> cloudFallback() => _answerFromBilServer(
      question: question,
      locale: locale,
      context: context,
      languageDetected: languageDetected,
      conversation: conversation,
    );

    // Deterministic BIL data answers and commands are resolved by the engine
    // before this gateway. A private model is tried only when the build
    // explicitly configures one. Otherwise unresolved questions go straight
    // to Gemini instead of waiting for a nonexistent emulator loopback server.
    final base = Uri.tryParse(endpoint);
    if (base == null || !{'http', 'https'}.contains(base.scheme)) {
      return cloudFallback();
    }
    // "Local" means this device only. A bearer key cannot turn an Internet or
    // LAN endpoint into an on-device model; every non-loopback URL must use the
    // consent-gated BIL cloud path below.
    if (!isLoopbackLocalModelEndpoint(endpoint)) return cloudFallback();
    final uri = base.replace(path: '/v1/chat/completions');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      if (apiKey.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }
      request.write(
        jsonEncode({
          'model': 'Qwen3-4B-Q4_K_M.gguf',
          'temperature': .25,
          'max_tokens': 700,
          'response_format': {'type': 'json_object'},
          'messages': [
            {'role': 'system', 'content': _systemPrompt(locale)},
            ..._conversationMessages(
              question: question,
              conversation: conversation,
              includeLatestQuestion: false,
            ),
            {
              'role': 'user',
              'content': jsonEncode({
                'question': question,
                'userContext': context.toJson(),
              }),
            },
          ],
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 18),
      );
      if (response.statusCode != HttpStatus.ok) return cloudFallback();
      final payload = jsonDecode(await utf8.decoder.bind(response).join());
      final choices = payload is Map ? payload['choices'] : null;
      if (choices is! List || choices.isEmpty) return cloudFallback();
      final firstChoice = choices.first;
      final message = firstChoice is Map ? firstChoice['message'] : null;
      final content = message is Map ? message['content'] : null;
      if (content is! String || content.trim().isEmpty) {
        return cloudFallback();
      }
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final answer = decoded['answer']?.toString().trim() ?? '';
      final action = decoded['action'];
      return LocalModelResult.answer(
        LocalModelAnswer(
          text: answer,
          action: action is Map ? Map<String, Object?>.from(action) : null,
          spokenText: decoded['spoken_reply']?.toString().trim(),
        ),
      );
    } on Object {
      return cloudFallback();
    } finally {
      client.close(force: true);
    }
  }

  Future<LocalModelResult> _answerFromBilServer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    required bool languageDetected,
    required List<CoachConversationTurn> conversation,
  }) async {
    late final CoachCloudAccess access;
    try {
      access =
          cloudAccess ?? _SupabaseCoachCloudAccess(Supabase.instance.client);
      if (!access.hasAuthenticatedSession) {
        return const LocalModelResult(
          status: CoachServiceStatus.signedOut,
          diagnosticCode: 'authentication_required',
        );
      }
    } on Object {
      return const LocalModelResult(
        status: CoachServiceStatus.temporarilyUnavailable,
        diagnosticCode: 'cloud_access_unavailable',
      );
    }

    Object? consent;
    try {
      consent = await access.readRemoteAiConsent().timeout(
        const Duration(seconds: 8),
      );
    } on Object {
      return const LocalModelResult(
        status: CoachServiceStatus.temporarilyUnavailable,
        diagnosticCode: 'remote_ai_consent_preflight_failed',
      );
    }
    if (!isCurrentRemoteAiConsentGranted(consent)) {
      return const LocalModelResult(
        status: CoachServiceStatus.consentRequired,
        diagnosticCode: 'ai_consent_required',
      );
    }

    try {
      final requestId =
          'coach-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      // Client preflight above prevents context projection and any Edge call
      // before explicit consent. The server repeats its own authoritative gate
      // as defense in depth against modified or obsolete clients.
      final projection = cloudContextProjector.project(
        question: question,
        context: context,
        conversation: conversation,
      );
      final scopedConversation = questionScopedCoachCloudConversation(
        question: question,
        conversation: conversation,
      );
      final cloudMessages = _conversationMessages(
        question: question,
        conversation: scopedConversation,
      );
      final disclosure = <String, Object?>{
        ...projection.disclosure,
        'included_prior_turn_count': cloudMessages.length - 1,
        'sent_message_count': cloudMessages.length,
      };
      final response = await access
          .invokeCoach(<String, Object?>{
            'request_id': requestId,
            'locale': locale,
            if (languageDetected) 'language_hint': locale,
            'messages': cloudMessages,
            // Ephemeral fields and the disclosure are generated from the same
            // question-scoped projection, so the UI/server evidence can match.
            'context': projection.context,
            'context_disclosure': disclosure,
          })
          .timeout(const Duration(seconds: 28));
      final data = response.data;
      if (response.status != 200 || data is! Map) {
        return const LocalModelResult(
          status: CoachServiceStatus.temporarilyUnavailable,
          diagnosticCode: 'invalid_cloud_response',
        );
      }
      final reply = data['reply']?.toString().trim() ?? '';
      if (reply.isEmpty) {
        return const LocalModelResult(
          status: CoachServiceStatus.temporarilyUnavailable,
          diagnosticCode: 'empty_cloud_response',
        );
      }
      Map<String, Object?>? action;
      final proposals = data['proposed_actions'];
      if (proposals is List && proposals.isNotEmpty && proposals.first is Map) {
        final proposal = Map<String, Object?>.from(proposals.first as Map);
        final type = proposal['type']?.toString() ?? '';
        if (type.isNotEmpty) {
          action = <String, Object?>{
            'name': type,
            'arguments': proposal['arguments'] is Map
                ? Map<String, Object?>.from(proposal['arguments']! as Map)
                : const <String, Object?>{},
          };
        }
      }
      return LocalModelResult.answer(
        LocalModelAnswer(
          text: reply,
          action: action,
          spokenText: data['spoken_reply']?.toString().trim(),
          processedOnDevice: false,
          reason: data['reason']?.toString().trim(),
          confidence: (data['confidence'] as num?)?.toDouble(),
          evidence: _stringList(data['evidence']),
          missingData: _stringList(data['missing_data']),
          responseId: data['response_id']?.toString().trim() ?? requestId,
          transcript: data['transcript']?.toString().trim(),
        ),
      );
    } on FunctionException catch (error) {
      final code = functionErrorCodeFromDetails(error.details);
      return LocalModelResult(
        status: coachServiceStatusForFunctionError(error.status, code),
        diagnosticCode: code ?? 'edge_function_${error.status}',
      );
    } on Object {
      return const LocalModelResult(
        status: CoachServiceStatus.temporarilyUnavailable,
        diagnosticCode: 'cloud_request_failed',
      );
    }
  }

  List<Map<String, String>> _conversationMessages({
    required String question,
    required List<CoachConversationTurn> conversation,
    bool includeLatestQuestion = true,
  }) {
    final values = conversation
        .where(
          (turn) =>
              {'user', 'assistant'}.contains(turn.role) &&
              turn.content.trim().isNotEmpty,
        )
        .map(
          (turn) => <String, String>{
            'role': turn.role,
            'content': turn.content.trim(),
          },
        )
        .toList(growable: true);
    if (values.isNotEmpty &&
        values.last['role'] == 'user' &&
        values.last['content'] == question.trim()) {
      values.removeLast();
    }
    final retained = values.length > 11
        ? values.sublist(values.length - 11)
        : values;
    if (includeLatestQuestion) {
      retained.add({'role': 'user', 'content': question.trim()});
    }
    const totalCharacterBudget = 12000;
    var used = 0;
    final bounded = <Map<String, String>>[];
    for (final value in retained.reversed) {
      final content = value['content']!;
      final clipped = content.length <= 4000
          ? content
          : content.substring(content.length - 4000);
      if (bounded.isNotEmpty && used + clipped.length > totalCharacterBudget) {
        break;
      }
      bounded.add({'role': value['role']!, 'content': clipped});
      used += clipped.length;
    }
    return bounded.reversed.toList(growable: false);
  }

  List<String> _stringList(Object? raw) => raw is List
      ? raw
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .take(6)
            .toList(growable: false)
      : const [];

  String _systemPrompt(String locale) =>
      '''
You are BIL AI Coach, a professional nutrition and fitness coach. Reply in
${_languageName(locale)}. Use only the supplied user
context for personal claims. General education is allowed, but never diagnose,
prescribe medication, invent measurements, or alter user data yourself.
Treat computedHealth as authoritative tool output: quote its values accurately,
do not redo or reinterpret its arithmetic, and never call currentWeightKg a
recommended weight. goalDirection=lose with kilogramsToGoal=7 means the user
needs to lose 7 kg to reach the saved target.
Treat profile.dietaryPreferences as hard food-selection constraints for every
meal, recipe, shopping, or ingredient suggestion. Never propose an excluded
allergen/ingredient or incompatible dietary requirement. These preferences do
not by themselves change calorie or macro requirements.
Return one JSON object only:
{"answer":"concise helpful answer","action":null}
or
{"answer":"answer","action":{"name":"allowed_action","arguments":{}}}
Allowed actions: open_weight_log, open_meals, open_meals_yesterday,
open_workouts, open_plan, open_report, log_water, log_weight,
set_theme_mode, set_language, update_goal, save_measurements,
quick_add_macros, update_meal_item, move_meal_item, delete_meal_item,
read_nutrition_remaining, read_profile_identity, navigate,
manage_subscription, request_account_deletion, save_memory. For writes include
the exact validated value and expect BIL to request confirmation. Use these
argument names exactly:
navigate {"target":"dashboard|daily_log|nutrition|weight_history|measurements|goals|analytics|profile|settings|notifications|ai_coach"};
log_water {"amountMl":number};
log_weight {"weightKg":number,"date"?:"YYYY-MM-DD"};
set_theme_mode {"mode":"dark|light|system"};
set_language {"locale":"BCP-47"};
update_goal {"targetWeightKg":number,"targetDate"?:"YYYY-MM-DD"};
save_measurements {"date"?:"YYYY-MM-DD", one or more of "neckCm", "waistCm",
"hipsCm", "chestCm", "armCm", "thighCm":number};
quick_add_macros {"mealType":"breakfast|lunch|dinner|snack",
"calories":number,"protein":number,"carbohydrates":number,"fat":number,
"date"?:"YYYY-MM-DD"};
update_meal_item {"itemId":integer,"quantityGrams":number};
move_meal_item {"itemId":integer,"mealType":"breakfast|lunch|dinner|snack"};
delete_meal_item {"itemId":integer};
read_nutrition_remaining, read_profile_identity, open_weight_log, open_meals,
open_meals_yesterday, open_workouts, open_plan, open_report,
manage_subscription, request_account_deletion use {}.
When the exact write value is clear, return the action now. Do not ask the user
to type confirmation in chat because BIL presents the confirmation UI. Use
save_memory with {"text":string,"kind":"user_fact|preference|constraint|goal|routine"}
only when the user explicitly asks BIL to remember something. /no_think
''';

  String _languageName(String locale) {
    final normalized = locale.replaceAll('_', '-');
    final lower = normalized.toLowerCase();
    final exact = switch (lower) {
      'ar' => 'Arabic',
      'de' => 'German',
      'it' => 'Italian',
      'pt-br' => 'Brazilian Portuguese',
      'pt-pt' => 'European Portuguese',
      'ur' => 'Urdu',
      'fa' => 'Persian',
      'hi' => 'Hindi',
      'id' => 'Indonesian',
      'ms' => 'Malay',
      'ja' => 'Japanese',
      'ko' => 'Korean',
      'zh-hans' => 'Simplified Chinese',
      'zh-hant' => 'Traditional Chinese',
      'ru' => 'Russian',
      'bn' => 'Bengali',
      'vi' => 'Vietnamese',
      'th' => 'Thai',
      'pl' => 'Polish',
      'nl' => 'Dutch',
      'uk' => 'Ukrainian',
      'fr' => 'French',
      'es' => 'Spanish',
      'tr' => 'Turkish',
      _ => null,
    };
    if (exact != null) return exact;
    return switch (lower.split('-').first) {
      'ar' => 'Arabic',
      'en' => 'English',
      'pt' => 'Portuguese',
      'zh' => 'Chinese',
      _ => 'the language identified by BCP-47 tag $normalized',
    };
  }
}
