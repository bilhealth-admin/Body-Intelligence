import 'dart:convert';

import '../../../data/database/database_scope.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../domain/food_v2/coach_food_v2.dart';
import 'coach_food_catalog_adapter.dart';

/// One owner-scoped, revisioned and explicitly approved fixed-food rule.
final class CoachPersonalFoodRule {
  CoachPersonalFoodRule({
    required this.id,
    required this.ownerKey,
    required this.alias,
    required this.revision,
    required this.approvedAt,
    required this.approvalDigest,
    required this.snapshot,
    required this.inputUnit,
    required this.gramsPerUnit,
  });

  final String id;
  final String ownerKey;
  final String alias;
  final int revision;
  final DateTime approvedAt;
  final String approvalDigest;
  final CoachFoodSnapshot snapshot;
  final String inputUnit;
  final double gramsPerUnit;

  CoachFoodCandidate candidate(String concept) => CoachFoodCandidate(
    concept: concept,
    food: snapshot,
    identityConfidence: CoachFoodConfidence(
      score: 1,
      basis: 'Exact Personal BIL alias at revision $revision',
    ),
    unitRule: CoachFoodUnitRule(
      identity: snapshot.identity,
      preparedState: snapshot.preparedState,
      inputUnit: inputUnit,
      gramsPerUnit: gramsPerUnit,
      source: snapshot.source,
    ),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'ownerKey': ownerKey,
    'alias': alias,
    'revision': revision,
    'approvedAt': approvedAt.toUtc().toIso8601String(),
    'approvalDigest': approvalDigest,
    'snapshot': snapshot.toJson(),
    'inputUnit': inputUnit,
    'gramsPerUnit': gramsPerUnit,
  };

  static CoachPersonalFoodRule fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('personal_rule_not_map');
    final json = Map<String, Object?>.from(raw);
    final revision = json['revision'];
    final grams = json['gramsPerUnit'];
    final approvedAt = DateTime.tryParse(json['approvedAt']?.toString() ?? '');
    if (revision is! int ||
        revision < 1 ||
        grams is! num ||
        approvedAt == null) {
      throw const FormatException('personal_rule_invalid');
    }
    return CoachPersonalFoodRule(
      id: json['id']!.toString(),
      ownerKey: json['ownerKey']!.toString(),
      alias: json['alias']!.toString(),
      revision: revision,
      approvedAt: approvedAt,
      approvalDigest: json['approvalDigest']!.toString(),
      snapshot: CoachFoodSnapshot.fromJson(json['snapshot']),
      inputUnit: json['inputUnit']!.toString(),
      gramsPerUnit: grams.toDouble(),
    );
  }
}

/// Persistent Personal BIL food rules. Database owner + Food owner epoch are
/// both checked before and after every await, so A→B→A cannot revive a stale
/// approval scope.
final class CoachPersonalFoodRuleStore {
  const CoachPersonalFoodRuleStore(this._preferences);

  final PreferencesRepository _preferences;
  static const _key = 'aiCoach.personalBil.foodRules.v1';
  static const _schema = 'bil.personal.food-rules.v1';

  Future<List<CoachPersonalFoodRule>> read(CoachFoodOwnerScope scope) async {
    scope.check();
    _checkDatabaseOwner(scope);
    final raw = await _preferences.get(_key);
    scope.check();
    _checkDatabaseOwner(scope);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['schema'] != _schema) {
      throw const FormatException('personal_rules_schema');
    }
    if (decoded['ownerKey'] != scope.captured.ownerKey) {
      throw const CoachFoodContractError('owner_changed');
    }
    final rules = decoded['rules'];
    if (rules is! List) throw const FormatException('personal_rules_rows');
    return List.unmodifiable([
      for (final rawRule in rules) CoachPersonalFoodRule.fromJson(rawRule),
    ]);
  }

  Future<CoachPersonalFoodRule?> find(
    String concept,
    CoachFoodOwnerScope scope,
  ) async {
    final alias = normalizeFoodConcept(concept);
    final matches = (await read(
      scope,
    )).where((rule) => rule.alias == alias).toList();
    return matches.length == 1 ? matches.single : null;
  }

  Future<CoachPersonalFoodRule> reapprove({
    required CoachFoodOwnerScope scope,
    required CoachPersonalFoodRule previous,
    required String explicitApprovalText,
    required String inputUnit,
    required double gramsPerUnit,
    DateTime? approvedAt,
  }) async {
    scope.check();
    _checkDatabaseOwner(scope);
    if (previous.ownerKey != scope.captured.ownerKey) {
      scope.cancel();
      throw const CoachFoodContractError('owner_changed');
    }
    final normalizedUnit = normalizeFoodUnit(inputUnit);
    if (!const {'item', 'ml'}.contains(normalizedUnit) ||
        !gramsPerUnit.isFinite ||
        gramsPerUnit <= 0 ||
        gramsPerUnit > 100000) {
      throw const CoachFoodContractError('invalid_fixed_rule');
    }
    _requireExplicitApproval(explicitApprovalText);
    final timestamp = approvedAt ?? DateTime.now();
    CoachPersonalFoodRule? result;
    await _preferences.update(_key, (current) {
      scope.check();
      _checkDatabaseOwner(scope);
      final existing = _decode(current, scope.captured.ownerKey);
      final matches = existing.where((rule) => rule.id == previous.id).toList();
      if (matches.length != 1 || matches.single.revision != previous.revision) {
        throw const CoachFoodContractError('stale_fixed_rule');
      }
      final revision = previous.revision + 1;
      final prior = previous.snapshot;
      final snapshot = CoachFoodSnapshot(
        identity: prior.identity,
        name: prior.name,
        preparedState: prior.preparedState,
        basisGrams: prior.basisGrams,
        nutrients: prior.nutrients,
        source: CoachFoodSourceEvidence(
          kind: CoachFoodSourceKind.userFixed,
          ref: 'personal-bil:${previous.id}',
          revision: 'r$revision',
          ownerKey: scope.captured.ownerKey,
          confidence: CoachFoodConfidence(
            score: 1,
            basis: 'Explicit user approval frozen at rule revision $revision',
          ),
        ),
      );
      result = CoachPersonalFoodRule(
        id: previous.id,
        ownerKey: previous.ownerKey,
        alias: previous.alias,
        revision: revision,
        approvedAt: timestamp,
        approvalDigest: 'snapshot:${snapshot.digest}',
        snapshot: snapshot,
        inputUnit: normalizedUnit,
        gramsPerUnit: gramsPerUnit,
      );
      final retained = [
        for (final rule in existing)
          if (rule.id != previous.id) rule,
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

  Future<CoachPersonalFoodRule> approve({
    required CoachFoodOwnerScope scope,
    required String alias,
    required String explicitApprovalText,
    required CoachFoodCatalogEntry source,
    required String inputUnit,
    required double gramsPerUnit,
    DateTime? approvedAt,
  }) async {
    scope.check();
    _checkDatabaseOwner(scope);
    final normalizedAlias = normalizeFoodConcept(alias);
    final normalizedUnit = normalizeFoodUnit(inputUnit);
    if (normalizedAlias.isEmpty ||
        !const {'item', 'ml'}.contains(normalizedUnit)) {
      throw const CoachFoodContractError('invalid_fixed_rule');
    }
    if (!gramsPerUnit.isFinite || gramsPerUnit <= 0 || gramsPerUnit > 100000) {
      throw const CoachFoodContractError('invalid_fixed_rule');
    }
    _requireExplicitApproval(explicitApprovalText);
    final timestamp = approvedAt ?? DateTime.now();
    CoachPersonalFoodRule? result;
    await _preferences.update(_key, (current) {
      scope.check();
      _checkDatabaseOwner(scope);
      final existing = _decode(current, scope.captured.ownerKey);
      final previous = existing
          .where((rule) => rule.alias == normalizedAlias)
          .toList();
      final revision = previous.isEmpty ? 1 : previous.single.revision + 1;
      final id = previous.isEmpty
          ? 'fixed:${scope.captured.ownerKey}:${Uri.encodeComponent(normalizedAlias)}'
          : previous.single.id;
      final snapshot = source.freezePersonal(
        ownerKey: scope.captured.ownerKey,
        ruleId: id,
        revision: revision,
        inputUnit: normalizedUnit,
        gramsPerUnit: gramsPerUnit,
      );
      final digest = snapshot.digest;
      result = CoachPersonalFoodRule(
        id: id,
        ownerKey: scope.captured.ownerKey,
        alias: normalizedAlias,
        revision: revision,
        approvedAt: timestamp,
        approvalDigest: 'snapshot:$digest',
        snapshot: snapshot,
        inputUnit: normalizedUnit,
        gramsPerUnit: gramsPerUnit,
      );
      final retained = [
        for (final rule in existing)
          if (rule.alias != normalizedAlias) rule,
      ];
      retained.add(result!);
      retained.sort((a, b) => a.alias.compareTo(b.alias));
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

  List<CoachPersonalFoodRule> _decode(String? raw, String ownerKey) {
    if (raw == null) return <CoachPersonalFoodRule>[];
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['schema'] != _schema ||
        decoded['ownerKey'] != ownerKey) {
      throw const CoachFoodContractError('owner_changed');
    }
    final rows = decoded['rules'];
    if (rows is! List) throw const FormatException('personal_rules_rows');
    return [for (final row in rows) CoachPersonalFoodRule.fromJson(row)];
  }

  void _checkDatabaseOwner(CoachFoodOwnerScope scope) {
    if (LocalDatabaseScope.keyForOwner(_preferences.localOwnerId) !=
        scope.captured.ownerKey) {
      scope.cancel();
      throw const CoachFoodContractError('owner_changed');
    }
  }

  static void _requireExplicitApproval(String text) {
    final normalizedApproval = normalizeFoodConcept(text.trim());
    final explicitlyApproved = const [
      'اعتمد',
      'ثبت',
      'ثبّت',
      'خليها ثابته',
      'خليها ثابتة',
      'remember as fixed',
      'save as fixed',
      'use as fixed',
      'approve',
    ].any((token) => normalizedApproval.contains(normalizeFoodConcept(token)));
    if (!explicitlyApproved) {
      throw const CoachFoodContractError('explicit_approval_required');
    }
  }
}
