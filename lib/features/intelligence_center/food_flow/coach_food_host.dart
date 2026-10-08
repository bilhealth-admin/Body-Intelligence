import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/meal_food_evidence.dart';
import '../../../data/repositories/food_repository.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../recipe_import/repositories/trusted_recipe_repository.dart';
import '../../recipe_import/services/trusted_recipe_diary_service.dart';
import '../domain/intelligence_action.dart';
import '../domain/food_v2/coach_food_v2.dart';
import '../services/local_coach_command_parser.dart';
import 'coach_food_catalog_adapter.dart';
import 'coach_food_personal_bil.dart';
import 'coach_food_personal_recipe.dart';
import 'coach_food_turn_parser.dart';
part 'coach_food_host_target.dart';

enum CoachFoodDraftKind { logFoods, replaceMealItem }

sealed class CoachFoodHostResult {
  const CoachFoodHostResult();
}

final class CoachFoodHostIgnored extends CoachFoodHostResult {
  const CoachFoodHostIgnored();
}

final class CoachFoodHostClarification extends CoachFoodHostResult {
  const CoachFoodHostClarification(this.code, this.message);
  final String code;
  final String message;
}

final class CoachFoodPersonalRuleSaved extends CoachFoodHostResult {
  const CoachFoodPersonalRuleSaved(this.rule);
  final CoachPersonalFoodRule rule;
}

final class CoachFoodPersonalRecipeRuleSaved extends CoachFoodHostResult {
  const CoachFoodPersonalRecipeRuleSaved(this.rule);
  final CoachPersonalRecipeRule rule;
}

/// A fully frozen app-owned write proposal. The shared Coach host only maps
/// this value to IntelligenceAction and presentation. It must not re-resolve
/// food identity or quantity after the review is shown.
final class CoachFoodActionDraft extends CoachFoodHostResult {
  const CoachFoodActionDraft({
    required this.kind,
    required this.operationId,
    required this.day,
    required this.mealType,
    required this.payload,
    required this.review,
  });

  final CoachFoodDraftKind kind;
  final String operationId;
  final DateTime day;
  final String mealType;
  final Map<String, Object?> payload;
  final CoachFoodReview review;
}

/// Native Food/Personal BIL turn owner. Parsing and resolution are side-effect
/// free except the explicit Personal BIL approval path. Diary writes remain in
/// MealRepository.commitCoachMeal and are executed only after UI confirmation.
final class CoachFoodHost {
  CoachFoodHost({
    required FoodRepository foods,
    required this.meals,
    required PreferencesRepository preferences,
  }) : catalog = CoachFoodCatalogAdapter(foods),
       personal = CoachPersonalFoodRuleStore(preferences),
       personalRecipes = CoachPersonalRecipeRuleStore(
         preferences: preferences,
         recipes: TrustedRecipeRepository(preferences),
         diary: TrustedRecipeDiaryService(foods, meals),
       );

  final MealRepository meals;
  final CoachFoodCatalogAdapter catalog;
  final CoachPersonalFoodRuleStore personal;
  final CoachPersonalRecipeRuleStore personalRecipes;
  static const _parser = CoachFoodTurnParser();

  Future<CoachFoodHostResult> prepare({
    required String input,
    required DateTime referenceLocal,
    required String localeTag,
    required CoachFoodOwnerScope ownerScope,
    int? preferredTargetItemId,
  }) async {
    ownerScope.check();
    // Admitted native water, weight and calorie-only commands own their
    // reviewed write contracts. Food V2's generic "log"/"سجل" prefix must
    // not reinterpret a calorie total as a food identity or quantity.
    // Only a fully parsed, side-effect-free and validated native proposal
    // can reserve this route; food items and corrections still use Food V2.
    final nativeActions = const LocalCoachCommandParser().parse(
      input,
      locale: localeTag,
      referenceLocal: referenceLocal,
    );
    if (nativeActions.any(
      (action) =>
          action.type == IntelligenceActionType.addWater ||
          action.type == IntelligenceActionType.addWeight ||
          action.type == IntelligenceActionType.quickAddMacros,
    )) {
      return const CoachFoodHostIgnored();
    }
    final parsed = _parser.parse(input, referenceLocal: referenceLocal);
    if (parsed.kind == CoachFoodTurnKind.none) {
      return const CoachFoodHostIgnored();
    }
    if (parsed.invalidExplicitDate) {
      return _clarify(
        localeTag,
        'invalid_date',
        'I could not safely read that date. Please write it as YYYY-MM-DD.',
        'لم أستطع قراءة التاريخ بأمان. اكتبه بصيغة YYYY-MM-DD.',
      );
    }
    final ownerKey = ownerScope.captured.ownerKey;
    final local = referenceLocal;
    final today = DateTime(local.year, local.month, local.day);

    if (parsed.kind == CoachFoodTurnKind.approveRecipe) {
      final approval = parsed.recipeApproval!;
      try {
        final rule = await personalRecipes.approve(
          scope: ownerScope,
          alias: approval.alias,
          servingGrams: approval.servingGrams,
          explicitApprovalText: input,
          approvedAt: referenceLocal,
        );
        return CoachFoodPersonalRecipeRuleSaved(rule);
      } on CoachFoodContractError catch (error) {
        return _clarify(
          localeTag,
          error.code,
          'I could not freeze that recipe rule safely. Make sure the reviewed recipe exists, has reviewed nutrition, and include the serving grams.',
          'لم أستطع تثبيت قاعدة الوصفة بأمان. تأكد أن الوصفة المراجعة موجودة ولها تغذية مراجعة، واذكر وزن الحصة بالغرام.',
        );
      }
    }

    if (parsed.kind == CoachFoodTurnKind.approveFixed) {
      final approval = parsed.fixedApproval!;
      final previous = await personal.find(approval.alias, ownerScope);
      ownerScope.check();
      if (previous != null) {
        try {
          final rule = await personal.reapprove(
            scope: ownerScope,
            previous: previous,
            explicitApprovalText: input,
            inputUnit: approval.inputUnit,
            gramsPerUnit: approval.gramsPerUnit,
            approvedAt: referenceLocal,
          );
          return CoachFoodPersonalRuleSaved(rule);
        } on CoachFoodContractError catch (error) {
          return _clarify(
            localeTag,
            error.code,
            'I could not revise that fixed rule safely.',
            'لم أستطع تحديث القاعدة الثابتة بأمان.',
          );
        }
      }
      final matches = await catalog.exactMatches(
        approval.alias,
        ownerKey: ownerKey,
      );
      ownerScope.check();
      if (matches.isEmpty) {
        return _clarify(
          localeTag,
          'fixed_identity_missing',
          'Which saved food should this fixed rule use? I need an existing food identity first.',
          'أي طعام محفوظ تريد أن تستخدمه هذه القاعدة الثابتة؟ أحتاج هوية طعام موجودة أولًا.',
        );
      }
      if (matches.length > 1) {
        return _identityClarification(localeTag, approval.alias, matches);
      }
      try {
        final rule = await personal.approve(
          scope: ownerScope,
          alias: approval.alias,
          explicitApprovalText: input,
          source: matches.single,
          inputUnit: approval.inputUnit,
          gramsPerUnit: approval.gramsPerUnit,
          approvedAt: referenceLocal,
        );
        return CoachFoodPersonalRuleSaved(rule);
      } on CoachFoodContractError catch (error) {
        return _clarify(
          localeTag,
          error.code,
          'I could not freeze that rule safely. Include the exact item/volume and its gram equivalent.',
          'لم أستطع تثبيت القاعدة بأمان. اذكر العدد/الحجم الدقيق وما يعادله بالغرام.',
        );
      }
    }

    if (parsed.kind == CoachFoodTurnKind.likeYesterday) {
      // In "like yesterday", yesterday identifies the source. Only a real
      // explicit calendar date changes the destination day.
      final explicitDestination = const CoachFoodTurnParser().parse(
        input,
        referenceLocal: referenceLocal,
      );
      final hasExplicit = _hasExplicitDate(input);
      final destination = hasExplicit && explicitDestination.date != null
          ? _civilWithClock(explicitDestination.date!, local)
          : local;
      final destinationDay = DateTime(
        destination.year,
        destination.month,
        destination.day,
      );
      final mealType =
          parsed.mealType ?? CoachFoodTurnParser.inferMealType(local);
      final sourceDay = DateTime(
        destinationDay.year,
        destinationDay.month,
        destinationDay.day - 1,
      );
      final sourceMeals = await meals.watchMealsForDate(sourceDay).first;
      ownerScope.check();
      final matching = sourceMeals
          .where((meal) => meal.meal.type == mealType)
          .toList();
      if (matching.isEmpty) {
        return _clarify(
          localeTag,
          'yesterday_meal_missing',
          'I do not have a saved $mealType meal from the previous day to copy.',
          'لا توجد لدي وجبة $mealType محفوظة من اليوم السابق لنسخها.',
        );
      }
      final portions = <CoachFoodPortion>[];
      for (final item in matching.first.items) {
        final evidence = MealFoodEvidence.read(item, ownerKey: ownerKey);
        final portion = evidence.portion;
        if (!evidence.isValid || portion == null) {
          return _clarify(
            localeTag,
            'historical_snapshot_unavailable',
            'One item in that meal does not have a complete historical Food snapshot, so I will not rebuild it from today’s catalog.',
            'أحد عناصر تلك الوجبة لا يملك لقطة Food تاريخية كاملة، لذلك لن أعيد بناءه من كتالوج اليوم.',
          );
        }
        portions.add(portion);
      }
      if (portions.isEmpty) {
        return _clarify(
          localeTag,
          'yesterday_meal_empty',
          'That saved meal is empty.',
          'الوجبة المحفوظة فارغة.',
        );
      }
      return _logDraft(
        input: input,
        ownerKey: ownerKey,
        day: destinationDay,
        occurredAt: destination,
        mealType: mealType,
        portions: portions,
      );
    }

    if (parsed.kind == CoachFoodTurnKind.correction) {
      return _prepareCorrection(
        input: input,
        parsed: parsed,
        referenceLocal: local,
        localeTag: localeTag,
        ownerScope: ownerScope,
        preferredTargetItemId: preferredTargetItemId,
      );
    }

    final day = parsed.date == null
        ? today
        : DateTime(parsed.date!.year, parsed.date!.month, parsed.date!.day);
    final mealType =
        parsed.mealType ?? CoachFoodTurnParser.inferMealType(local);
    final portions = <CoachFoodPortion>[];
    for (final item in parsed.items) {
      final resolved = await _resolvePortion(
        item,
        localeTag: localeTag,
        ownerScope: ownerScope,
      );
      if (resolved case final CoachFoodHostClarification clarification) {
        return clarification;
      }
      portions.add((resolved as _ResolvedPortion).portion);
    }
    if (portions.isEmpty) return const CoachFoodHostIgnored();
    return _logDraft(
      input: input,
      ownerKey: ownerKey,
      day: day,
      occurredAt: _civilWithClock(day, local),
      mealType: mealType,
      portions: portions,
    );
  }

  Future<CoachFoodHostResult> _prepareCorrection({
    required String input,
    required CoachFoodParsedTurn parsed,
    required DateTime referenceLocal,
    required String localeTag,
    required CoachFoodOwnerScope ownerScope,
    required int? preferredTargetItemId,
  }) async {
    final ownerKey = ownerScope.captured.ownerKey;
    final target = await _target(
      parsed,
      preferredTargetItemId: preferredTargetItemId,
      ownerKey: ownerKey,
    );
    ownerScope.check();
    if (target == null) {
      return _clarify(
        localeTag,
        'correction_target_missing',
        'Which saved food do you want me to correct?',
        'أي طعام محفوظ تريدني أن أصححه؟',
      );
    }
    final evidence = MealFoodEvidence.read(target.item, ownerKey: ownerKey);
    final original = evidence.portion;
    if (!evidence.isValid || original == null) {
      return _clarify(
        localeTag,
        'correction_snapshot_unavailable',
        'That older item does not have enough frozen evidence for a safe AI correction.',
        'هذا العنصر القديم لا يملك أدلة مجمّدة كافية لتصحيح آمن بالذكاء الاصطناعي.',
      );
    }

    CoachFoodPortion replacement;
    switch (parsed.correctionKind!) {
      case CoachFoodCorrectionKind.half:
      case CoachFoodCorrectionKind.doubleAmount:
        final factor = parsed.correctionKind == CoachFoodCorrectionKind.half
            ? .5
            : 2.0;
        replacement = CoachFoodPortion(
          food: original.food,
          quantity: CoachFoodQuantities.declaredGrams(
            original.quantity.grams * factor,
            description: parsed.correctionKind == CoachFoodCorrectionKind.half
                ? 'User explicitly corrected this item to half its saved amount.'
                : 'User explicitly corrected this item to double its saved amount.',
          ),
          identityConfidence: original.identityConfidence,
        );
      case CoachFoodCorrectionKind.absolute:
        if (parsed.items.length != 1 || parsed.items.single.amount == null) {
          return _clarify(
            localeTag,
            'correction_quantity_missing',
            'What is the corrected amount?',
            'ما الكمية الصحيحة؟',
          );
        }
        final quantity = await _quantityForExisting(
          parsed.items.single,
          original,
          ownerScope: ownerScope,
          localeTag: localeTag,
        );
        if (quantity case final CoachFoodHostClarification clarification) {
          return clarification;
        }
        replacement = CoachFoodPortion(
          food: original.food,
          quantity: (quantity as _ResolvedQuantity).quantity,
          identityConfidence: original.identityConfidence,
        );
      case CoachFoodCorrectionKind.replace:
        if (parsed.items.length != 1) {
          return _clarify(
            localeTag,
            'replacement_missing',
            'Tell me the replacement food and its amount.',
            'اذكر الطعام البديل وكميته.',
          );
        }
        final resolved = await _resolvePortion(
          parsed.items.single,
          localeTag: localeTag,
          ownerScope: ownerScope,
        );
        if (resolved case final CoachFoodHostClarification clarification) {
          return clarification;
        }
        replacement = (resolved as _ResolvedPortion).portion;
    }
    final operationId = _operationId(
      'replace',
      ownerKey,
      input,
      referenceLocal,
    );
    final expected = {
      'id': target.item.id,
      'uuid': target.item.uuid,
      'revision': target.item.revision,
    };
    return CoachFoodActionDraft(
      kind: CoachFoodDraftKind.replaceMealItem,
      operationId: operationId,
      day: DateTime(
        target.meal.date.year,
        target.meal.date.month,
        target.meal.date.day,
      ),
      mealType: target.meal.type,
      review: CoachFoodReview([replacement]),
      payload: Map.unmodifiable({
        'itemId': target.item.id,
        'expected': expected,
        'replacement': replacement.toJson(),
      }),
    );
  }

  Future<Object> _resolvePortion(
    CoachFoodParsedItem item, {
    required String localeTag,
    required CoachFoodOwnerScope ownerScope,
  }) async {
    if (item.amount == null) {
      return _clarify(
        localeTag,
        'quantity_missing',
        'How much ${item.concept} did you have?',
        'كم كانت كمية ${item.concept}؟',
      );
    }
    final fixed = await personal.find(item.concept, ownerScope);
    ownerScope.check();
    final fixedRecipe = fixed == null
        ? await personalRecipes.find(item.concept, ownerScope)
        : null;
    ownerScope.check();
    CoachFoodCandidate? candidate;
    if (fixed != null) {
      candidate = fixed.candidate(item.concept);
    } else if (fixedRecipe != null) {
      candidate = fixedRecipe.candidate(item.concept);
    } else {
      final matches = await catalog.exactMatches(
        item.concept,
        ownerKey: ownerScope.captured.ownerKey,
      );
      ownerScope.check();
      if (matches.isEmpty) {
        return _clarify(
          localeTag,
          'food_identity_missing',
          'I could not find a saved, attributable food for “${item.concept}”. Which saved food do you mean?',
          'لم أجد طعامًا محفوظًا ذا مصدر موثّق لـ «${item.concept}». أي طعام محفوظ تقصد؟',
        );
      }
      if (matches.length > 1) {
        return _identityClarification(localeTag, item.concept, matches);
      }
      final snapshot = matches.single.snapshot;
      if (snapshot == null) {
        return _clarify(
          localeTag,
          'food_basis_missing',
          'That food does not have a trustworthy gram basis. Give me a documented gram amount or approve a fixed conversion first.',
          'هذا الطعام لا يملك أساس غرام موثوقًا. أعطني كمية موثقة بالغرام أو اعتمد تحويلًا ثابتًا أولًا.',
        );
      }
      candidate = CoachFoodCandidate(
        concept: item.concept,
        food: snapshot,
        identityConfidence: CoachFoodConfidence(
          score: 1,
          basis: 'Exact saved-food identity match',
        ),
      );
    }
    ownerScope.checkEvidence(candidate.food.source);
    final unit = item.unit;
    final CoachFoodQuantity quantity;
    if (unit == 'g') {
      quantity = CoachFoodQuantities.declaredGrams(
        item.amount!,
        description: 'User explicitly declared grams in this Coach turn.',
      );
    } else {
      final rule = candidate.unitRule;
      if (unit == null && rule == null) {
        return _clarify(
          localeTag,
          'quantity_unit_missing',
          'Is ${item.amount} for ${item.concept} grams, ml, or a count?',
          'هل ${item.amount} من ${item.concept} غرام أم مل أم عدد؟',
        );
      }
      final requestedUnit = unit ?? rule?.inputUnit;
      if (requestedUnit == null ||
          !const {'ml', 'item'}.contains(requestedUnit) ||
          rule == null ||
          rule.inputUnit != requestedUnit) {
        return _clarify(
          localeTag,
          'conversion_rule_missing',
          'I do not have an approved ${requestedUnit ?? 'unit'}→gram rule for ${item.concept}.',
          'لا توجد لدي قاعدة معتمدة لتحويل ${requestedUnit ?? 'هذه الوحدة'} إلى غرام لـ ${item.concept}.',
        );
      }
      quantity = CoachFoodQuantities.fromUnit(
        food: candidate.food,
        amount: item.amount!,
        inputUnit: requestedUnit,
        rule: rule,
        scope: ownerScope,
        description: 'Personal BIL fixed unit conversion approved by the user.',
      );
    }
    return _ResolvedPortion(
      CoachFoodPortion(
        food: candidate.food,
        quantity: quantity,
        identityConfidence: candidate.identityConfidence,
      ),
    );
  }

  Future<Object> _quantityForExisting(
    CoachFoodParsedItem item,
    CoachFoodPortion original, {
    required CoachFoodOwnerScope ownerScope,
    required String localeTag,
  }) async {
    final unit = item.unit;
    if (unit == 'g') {
      return _ResolvedQuantity(
        CoachFoodQuantities.declaredGrams(
          item.amount!,
          description: 'User explicitly corrected the saved amount in grams.',
        ),
      );
    }
    if (unit == null) {
      return _clarify(
        localeTag,
        'quantity_unit_missing',
        'Is that corrected amount in grams, ml, or count?',
        'هل الكمية المصححة بالغرام أم مل أم عدد؟',
      );
    }
    final previous = original.quantity.evidence.conversion;
    if (previous == null || previous.inputUnit != unit) {
      return _clarify(
        localeTag,
        'conversion_rule_missing',
        'That saved item has no frozen conversion for this unit.',
        'العنصر المحفوظ لا يملك تحويلًا مجمّدًا لهذه الوحدة.',
      );
    }
    ownerScope.checkEvidence(previous.source);
    final conversion = CoachFoodQuantityConversion(
      inputAmount: item.amount!,
      inputUnit: unit,
      gramsPerUnit: previous.gramsPerUnit,
      source: previous.source,
    );
    return _ResolvedQuantity(
      CoachFoodQuantity(
        grams: conversion.grams,
        evidence: CoachFoodQuantityEvidence(
          kind: previous.source.kind == CoachFoodSourceKind.estimated
              ? CoachFoodQuantityKind.estimated
              : CoachFoodQuantityKind.userDeclared,
          description:
              'Correction reused the frozen conversion from the saved item.',
          conversion: conversion,
        ),
      ),
    );
  }

  CoachFoodActionDraft _logDraft({
    required String input,
    required String ownerKey,
    required DateTime day,
    required DateTime occurredAt,
    required String mealType,
    required List<CoachFoodPortion> portions,
  }) {
    final review = CoachFoodReview(portions);
    final operationId = _operationId('foods', ownerKey, input, occurredAt);
    return CoachFoodActionDraft(
      kind: CoachFoodDraftKind.logFoods,
      operationId: operationId,
      day: day,
      mealType: mealType,
      review: review,
      payload: Map.unmodifiable({
        'date': _day(day),
        'mealType': mealType,
        'occurredAt': occurredAt.toIso8601String(),
        'portions': portions
            .map((portion) => portion.toJson())
            .toList(growable: false),
      }),
    );
  }

  static CoachFoodHostClarification _identityClarification(
    String localeTag,
    String concept,
    List<CoachFoodCatalogEntry> matches,
  ) {
    final labels = matches.take(3).map((entry) => entry.row.name).join(' / ');
    return _clarify(
      localeTag,
      'ambiguous_identity',
      'Which “$concept” do you mean: $labels?',
      'أي «$concept» تقصد: $labels؟',
    );
  }

  static CoachFoodHostClarification _clarify(
    String localeTag,
    String code,
    String en,
    String ar,
  ) => CoachFoodHostClarification(
    code,
    localeTag.toLowerCase().startsWith('ar') ? ar : en,
  );

  static String _operationId(
    String kind,
    String owner,
    String input,
    DateTime now,
  ) {
    final digest = sha256.convert(
      utf8.encode('$owner\n$kind\n${now.toUtc().toIso8601String()}\n$input'),
    );
    return 'food:$kind:${digest.toString().substring(0, 32)}';
  }

  static DateTime _civilWithClock(DateTime day, DateTime clock) => DateTime(
    day.year,
    day.month,
    day.day,
    clock.hour,
    clock.minute,
    clock.second,
    clock.millisecond,
    clock.microsecond,
  );

  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static bool _hasExplicitDate(String input) =>
      RegExp(r'\d{4}[-/]\d{1,2}[-/]\d{1,2}').hasMatch(input) ||
      RegExp(
        r'\d{1,2}\s+(?:jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december|يناير|فبراير|مارس|ابريل|مايو|يونيو|يوليو|اغسطس|سبتمبر|اكتوبر|نوفمبر|ديسمبر)\s+\d{4}',
        caseSensitive: false,
        unicode: true,
      ).hasMatch(input);
}

final class _ResolvedPortion {
  const _ResolvedPortion(this.portion);
  final CoachFoodPortion portion;
}

final class _ResolvedQuantity {
  const _ResolvedQuantity(this.quantity);
  final CoachFoodQuantity quantity;
}
