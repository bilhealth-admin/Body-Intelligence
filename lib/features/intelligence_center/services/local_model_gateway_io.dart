import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/coach_context_snapshot.dart';
import 'coach_cloud_payload_sanitizer.dart';
import 'local_model_gateway.dart';

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

class LlamaCppLocalGateway implements LocalModelGateway {
  const LlamaCppLocalGateway({
    this.endpoint = const String.fromEnvironment(
      'BIL_LOCAL_AI_URL',
      defaultValue: '',
    ),
    this.apiKey = const String.fromEnvironment('BIL_LOCAL_AI_API_KEY'),
  });

  final String endpoint;
  final String apiKey;

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
    final loopback =
        base.host == 'localhost' ||
        base.host == '127.0.0.1' ||
        base.host == '::1';
    // A model bound to this device's loopback interface is already isolated
    // from the network and must remain usable in a genuinely local/offline
    // installation. Any non-loopback endpoint still fails closed unless it
    // has a strong bearer credential.
    if (!loopback && apiKey.length < 32) return cloudFallback();
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
        const Duration(seconds: 45),
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
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) {
        return const LocalModelResult(
          status: CoachServiceStatus.signedOut,
          diagnosticCode: 'authentication_required',
        );
      }
      final requestId =
          'coach-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      // The Edge Function is the authoritative consent gate. Avoiding a
      // duplicate client-side consent round trip improves every cloud turn
      // without weakening privacy or quota enforcement.
      final response = await client.functions
          .invoke(
            'ai-coach',
            body: <String, Object?>{
              'request_id': requestId,
              'locale': locale,
              if (languageDetected) 'language_hint': locale,
              'messages': _conversationMessages(
                question: question,
                conversation: conversation,
              ),
              // The durable cloud ledger remains encrypted. Only this bounded,
              // user-initiated snapshot is sent ephemerally for this answer.
              'context': _boundedContext(context),
            },
          )
          .timeout(const Duration(seconds: 45));
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

  Map<String, Object?> _boundedContext(CoachContextSnapshot context) {
    final full = context.toJson();
    final weight = Map<String, Object?>.from(full['weight']! as Map);
    weight['history'] = context.weights
        .take(60)
        .map((item) => item.toJson())
        .toList(growable: false);
    final days = context.nutritionDays
        .take(7)
        .map((day) {
          final value = day.toJson();
          final meals = (value['meals']! as List)
              .take(6)
              .map((rawMeal) {
                final meal = Map<String, Object?>.from(rawMeal as Map);
                final items = meal['items'];
                if (items is List) {
                  meal['items'] = items.take(12).toList(growable: false);
                }
                return meal;
              })
              .toList(growable: false);
          return <String, Object?>{...value, 'meals': meals};
        })
        .toList(growable: false);
    var bounded = sanitizeCoachCloudObject(<String, Object?>{
      'schema': full['schema'],
      'generatedAt': full['generatedAt'],
      'profile': full['profile'],
      'weight': weight,
      'nutritionHistory': days,
      'waterHistory': context.waterHistory.take(30).toList(growable: false),
      'computedHealth': full['computedHealth'],
      'canonicalIntelligence': context.canonicalIntelligence,
      'decisionMemory': context.decisionMemory.take(10).toList(growable: false),
      'explicitMemories': context.explicitMemories
          .take(20)
          .toList(growable: false),
      'activityHistory': context.activityHistory
          .take(14)
          .toList(growable: false),
      'personalExperiments': context.personalExperiments
          .take(6)
          .toList(growable: false),
    });
    if (jsonEncode(bounded).length <= 19_000) return bounded;
    // Preserve grounded targets and summaries if item-level history is large.
    bounded['nutritionHistory'] = days
        .map(
          (day) => <String, Object?>{
            'day': day['day'],
            'totals': day['totals'],
          },
        )
        .toList(growable: false);
    bounded['decisionMemory'] = context.decisionMemory
        .take(5)
        .toList(growable: false);
    bounded['explicitMemories'] = context.explicitMemories
        .take(10)
        .toList(growable: false);
    bounded['activityHistory'] = context.activityHistory
        .take(7)
        .toList(growable: false);
    bounded['personalExperiments'] = context.personalExperiments
        .take(3)
        .toList(growable: false);
    bounded = sanitizeCoachCloudObject(bounded);
    return bounded;
  }

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
the exact
validated value and expect BIL to request confirmation. Use save_memory with
text and kind=user_fact|preference|constraint|goal|routine only when the user
explicitly asks BIL to remember something. /no_think
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
