import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../data/database/database_scope.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../recipe_import/domain/trusted_recipe.dart';
import '../../recipe_import/repositories/trusted_recipe_repository.dart';
import '../../recipe_import/services/trusted_recipe_diary_service.dart';
import '../../recipe_import/services/trusted_recipe_parser.dart';
import '../domain/food_v2/coach_food_v2.dart';
import 'coach_food_catalog_adapter.dart';

/// Frozen owner-scoped approval for one reviewed trusted recipe and its serving
/// mass. Updating the trusted recipe later cannot mutate this rule or old logs.
final class CoachPersonalRecipeRule {
  const CoachPersonalRecipeRule({
    required this.id,
    required this.ownerKey,
    required this.alias,
    required this.revision,
    required this.approvedAt,
    required this.approvalDigest,
    required this.savedRecipe,
    required this.servingGrams,
    required this.portion,
  });

  final String id;
  final String ownerKey;
  final String alias;
  final int revision;
  final DateTime approvedAt;
  final String approvalDigest;
  final SavedTrustedRecipe savedRecipe;
  final double servingGrams;
  final CoachFoodPortion portion;

  CoachFoodCandidate candidate(String concept) => CoachFoodCandidate(
    concept: concept,
    food: portion.food,
    identityConfidence: CoachFoodConfidence(
      score: 1,
      basis: 'Exact Personal BIL recipe alias at revision $revision',
    ),
    unitRule: CoachFoodUnitRule(
      identity: portion.food.identity,
      preparedState: portion.food.preparedState,
      inputUnit: 'item',
      gramsPerUnit: servingGrams,
      source: CoachFoodSourceEvidence(
        kind: CoachFoodSourceKind.userFixed,
        ref: 'personal-recipe:$id',
        revision: 'r$revision',
        ownerKey: ownerKey,
        confidence: CoachFoodConfidence(
          score: 1,
          basis: 'Explicit user-approved recipe serving mass',
        ),
      ),
    ),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'ownerKey': ownerKey,
    'alias': alias,
    'revision': revision,
    'approvedAt': approvedAt.toUtc().toIso8601String(),
    'approvalDigest': approvalDigest,
    'savedRecipe': savedRecipe.toJson(),
    'servingGrams': servingGrams,
    'portion': portion.toJson(),
  };

  static CoachPersonalRecipeRule fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('personal_recipe_rule_not_map');
    }
    final value = Map<String, Object?>.from(raw);
    final revision = value['revision'];
    final serving = value['servingGrams'];
    final approvedAt = DateTime.tryParse(value['approvedAt']?.toString() ?? '');
    final savedRaw = value['savedRecipe'];
    if (revision is! int ||
        revision < 1 ||
        serving is! num ||
        approvedAt == null ||
        savedRaw is! Map) {
      throw const FormatException('personal_recipe_rule_invalid');
    }
    final savedJson = Map<String, Object?>.from(savedRaw);
    final recipeRaw = savedJson['recipe'];
    final savedAt = DateTime.tryParse(savedJson['savedAt']?.toString() ?? '');
    final id = savedJson['id']?.toString();
    if (recipeRaw is! Map || savedAt == null || id == null || id.isEmpty) {
      throw const FormatException('personal_recipe_snapshot_invalid');
    }
    final recipe = TrustedRecipeParser.parse(jsonEncode(recipeRaw));
    return CoachPersonalRecipeRule(
      id: value['id']!.toString(),
      ownerKey: value['ownerKey']!.toString(),
      alias: value['alias']!.toString(),
      revision: revision,
      approvedAt: approvedAt,
      approvalDigest: value['approvalDigest']!.toString(),
      savedRecipe: SavedTrustedRecipe(id: id, savedAt: savedAt, recipe: recipe),
      servingGrams: serving.toDouble(),
      portion: CoachFoodPortion.fromJson(value['portion']),
    );
  }
}

final class CoachPersonalRecipeRuleStore {
  CoachPersonalRecipeRuleStore({
    required this._preferences,
    required this._recipes,
    required this._diary,
  });

  final PreferencesRepository _preferences;
  final TrustedRecipeRepository _recipes;
  final TrustedRecipeDiaryService _diary;

  static const _key = 'aiCoach.personalBil.recipeRules.v1';
  static const _schema = 'bil.personal.recipe-rules.v1';

  Future<List<CoachPersonalRecipeRule>> read(CoachFoodOwnerScope scope) async {
    scope.check();
    _checkDatabaseOwner(scope);
    final raw = await _preferences.get(_key);
    scope.check();
    _checkDatabaseOwner(scope);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['schema'] != _schema ||
        decoded['ownerKey'] != scope.captured.ownerKey ||
        decoded['rules'] is! List) {
      throw const CoachFoodContractError('owner_changed');
    }
    return List.unmodifiable([
      for (final row in decoded['rules'] as List)
        CoachPersonalRecipeRule.fromJson(row),
    ]);
  }

  Future<CoachPersonalRecipeRule?> find(
    String concept,
    CoachFoodOwnerScope scope,
  ) async {
    final alias = normalizeFoodConcept(concept);
    final matches = (await read(
      scope,
    )).where((rule) => rule.alias == alias).toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  Future<CoachPersonalRecipeRule> approve({
    required CoachFoodOwnerScope scope,
    required String alias,
    required double servingGrams,
    required String explicitApprovalText,
    required DateTime approvedAt,
  }) async {
    scope.check();
    _checkDatabaseOwner(scope);
    final normalizedAlias = normalizeFoodConcept(alias);
    if (normalizedAlias.isEmpty ||
        !servingGrams.isFinite ||
        servingGrams <= 0 ||
        servingGrams > 100000) {
      throw const CoachFoodContractError('invalid_recipe_rule');
    }
    final normalizedApproval = normalizeFoodConcept(explicitApprovalText);
    if (!const [
      'اعتمد وصفه',
      'ثبت وصفه',
      'ثبّت وصفه',
      'approve recipe',
      'save recipe as fixed',
    ].any(
      (token) => normalizedApproval.contains(normalizeFoodConcept(token)),
    )) {
      throw const CoachFoodContractError('explicit_approval_required');
    }
    final saved = await _recipes.load();
    scope.check();
    _checkDatabaseOwner(scope);
    final matching = saved
        .where(
          (item) => normalizeFoodConcept(item.recipe.name) == normalizedAlias,
        )
        .toList(growable: false);
    if (matching.length != 1) {
      throw CoachFoodContractError(
        matching.isEmpty
            ? 'recipe_identity_missing'
            : 'recipe_identity_ambiguous',
      );
    }
    if (matching.single.recipe.nutrition == null) {
      throw const CoachFoodContractError('recipe_nutrition_missing');
    }

    CoachPersonalRecipeRule? result;
    await _preferences.update(_key, (current) {
      scope.check();
      _checkDatabaseOwner(scope);
      final existing = _decode(current, scope.captured.ownerKey);
      final prior = existing
          .where((rule) => rule.alias == normalizedAlias)
          .toList();
      final revision = prior.isEmpty ? 1 : prior.single.revision + 1;
      final ruleId = prior.isEmpty
          ? 'recipe:${scope.captured.ownerKey}:${Uri.encodeComponent(normalizedAlias)}'
          : prior.single.id;
      final portion = _diary.freezeServingPortion(
        saved: matching.single,
        servingGrams: servingGrams,
        ruleId: ruleId,
        ruleRevision: revision,
        scope: scope,
      );
      final approvalDigest = sha256
          .convert(
            utf8.encode(
              jsonEncode({
                'recipeFingerprint': matching.single.recipe.fingerprint,
                'servingGrams': servingGrams,
                'portion': portion.toJson(),
              }),
            ),
          )
          .toString();
      result = CoachPersonalRecipeRule(
        id: ruleId,
        ownerKey: scope.captured.ownerKey,
        alias: normalizedAlias,
        revision: revision,
        approvedAt: approvedAt,
        approvalDigest: approvalDigest,
        savedRecipe: matching.single,
        servingGrams: servingGrams,
        portion: portion,
      );
      final retained = [
        for (final rule in existing)
          if (rule.alias != normalizedAlias) rule,
        result!,
      ]..sort((a, b) => a.alias.compareTo(b.alias));
      return jsonEncode({
        'schema': _schema,
        'ownerKey': scope.captured.ownerKey,
        'rules': retained.map((rule) => rule.toJson()).toList(growable: false),
      });
    });
    scope.check();
    _checkDatabaseOwner(scope);
    return result!;
  }

  List<CoachPersonalRecipeRule> _decode(String? raw, String ownerKey) {
    if (raw == null) return <CoachPersonalRecipeRule>[];
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['schema'] != _schema ||
        decoded['ownerKey'] != ownerKey ||
        decoded['rules'] is! List) {
      throw const CoachFoodContractError('owner_changed');
    }
    return [
      for (final row in decoded['rules'] as List)
        CoachPersonalRecipeRule.fromJson(row),
    ];
  }

  void _checkDatabaseOwner(CoachFoodOwnerScope scope) {
    if (LocalDatabaseScope.keyForOwner(_preferences.localOwnerId) !=
        scope.captured.ownerKey) {
      scope.cancel();
      throw const CoachFoodContractError('owner_changed');
    }
  }
}
