import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/coach_context_snapshot.dart';
import 'local_model_gateway.dart';

LocalModelGateway createLocalModelGateway() => const LlamaCppLocalGateway();

class LlamaCppLocalGateway implements LocalModelGateway {
  const LlamaCppLocalGateway({
    this.endpoint = const String.fromEnvironment(
      'BIL_LOCAL_AI_URL',
      defaultValue: 'http://127.0.0.1:18080',
    ),
    this.apiKey = const String.fromEnvironment('BIL_LOCAL_AI_API_KEY'),
  });

  final String endpoint;
  final String apiKey;

  @override
  Future<LocalModelAnswer?> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
  }) async {
    final cloud = await _answerFromBilServer(
      question: question,
      locale: locale,
      context: context,
    );
    if (cloud != null) return cloud;
    final base = Uri.tryParse(endpoint);
    if (base == null || !{'http', 'https'}.contains(base.scheme)) return null;
    final loopback =
        base.host == 'localhost' ||
        base.host == '127.0.0.1' ||
        base.host == '::1';
    // A model bound to this device's loopback interface is already isolated
    // from the network and must remain usable in a genuinely local/offline
    // installation. Any non-loopback endpoint still fails closed unless it
    // has a strong bearer credential.
    if (!loopback && apiKey.length < 32) return null;
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
      if (response.statusCode != HttpStatus.ok) return null;
      final payload = jsonDecode(await utf8.decoder.bind(response).join());
      final choices = payload is Map ? payload['choices'] : null;
      if (choices is! List || choices.isEmpty) return null;
      final firstChoice = choices.first;
      final message = firstChoice is Map ? firstChoice['message'] : null;
      final content = message is Map ? message['content'] : null;
      if (content is! String || content.trim().isEmpty) return null;
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final answer = decoded['answer']?.toString().trim() ?? '';
      final action = decoded['action'];
      return LocalModelAnswer(
        text: answer,
        action: action is Map ? Map<String, Object?>.from(action) : null,
        spokenText: decoded['spoken_reply']?.toString().trim(),
      );
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<LocalModelAnswer?> _answerFromBilServer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
  }) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return null;
      final requestId =
          'coach-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      final response = await client.functions.invoke(
        'ai-coach',
        body: <String, Object?>{
          'request_id': requestId,
          'locale': locale,
          'messages': <Map<String, String>>[
            <String, String>{'role': 'user', 'content': question},
          ],
          // The durable cloud ledger remains encrypted. Only this bounded,
          // user-initiated snapshot is sent ephemerally for this answer.
          'context': _boundedContext(context),
        },
      );
      final data = response.data;
      if (response.status != 200 || data is! Map) return null;
      final reply = data['reply']?.toString().trim() ?? '';
      if (reply.isEmpty) return null;
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
      return LocalModelAnswer(
        text: reply,
        action: action,
        spokenText: data['spoken_reply']?.toString().trim(),
        processedOnDevice: false,
      );
    } on Object {
      return null;
    }
  }

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
    final bounded = <String, Object?>{
      'schema': full['schema'],
      'generatedAt': full['generatedAt'],
      'profile': full['profile'],
      'weight': weight,
      'nutritionHistory': days,
      'waterHistory': context.waterHistory.take(30).toList(growable: false),
      'computedHealth': full['computedHealth'],
    };
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
Return one JSON object only:
{"answer":"concise helpful answer","action":null}
or
{"answer":"answer","action":{"name":"allowed_action","arguments":{}}}
Allowed actions: open_weight_log, open_meals, open_meals_yesterday,
open_workouts, open_plan, open_report, log_water, log_weight,
set_theme_mode, set_language, update_goal, save_measurements,
quick_add_macros, update_meal_item, move_meal_item, delete_meal_item,
read_nutrition_remaining, read_profile_identity, navigate,
manage_subscription, request_account_deletion. For writes include the exact
validated value and expect BIL to request confirmation. /no_think
''';

  String _languageName(String locale) =>
      switch (locale.replaceAll('_', '-').toLowerCase()) {
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
        _ => 'English',
      };
}
