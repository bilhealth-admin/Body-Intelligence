import 'package:flutter/material.dart';
import '../../../data/repositories/meal_repository.dart';
import '../services/meal_image_gateway_contract.dart';
import '../services/meal_vision_estimate_visit.dart';
import 'gemini_vision_estimate_review.dart';
import 'gemini_vision_copy.dart';
import 'meal_vision_premium_review.dart';

export '../domain/gemini_vision_estimate.dart';
export '../services/meal_vision_estimate_visit.dart';
export 'gemini_vision_estimate_review.dart';
export 'gemini_vision_copy.dart';
export 'meal_vision_estimate_consent.dart';

/// Used by the two diary contexts. The visible Save action is the only entry
/// to this owner-bound transaction; schema2 never queries a food catalog.
Future<bool> reviewGeminiVisionForDiary(
  BuildContext context, {
  required MealImageAnalysis analysis,
  required MealVisionEstimateVisit visit,
  required DateTime day,
  required String mealType,
  String? imagePath,
  Future<bool> Function()? beforeSave,
}) async {
  if (!visit.current || !context.mounted) return false;
  var saved = false;
  await showGeminiVisionEstimateReview(
    context,
    analysis: analysis,
    isCurrent: () => visit.current,
    lifetime: visit.lifetime,
    imagePath: imagePath,
    savesToDiary: true,
    destinationLabel:
        '${geminiVisionText(context, switch (mealType) {
          'breakfast' => 'Breakfast',
          'lunch' => 'Lunch',
          'dinner' => 'Dinner',
          _ => 'Snack',
        })} · ${MaterialLocalizations.of(context).formatMediumDate(day)}',
    onConfirm: (items) async {
      if (!visit.current) return const MealVisionReviewDecision.retired();
      if (beforeSave != null && !await beforeSave()) {
        return const MealVisionReviewDecision.cancelled();
      }
      if (!visit.current) return const MealVisionReviewDecision.retired();
      await MealRepository(visit.database).addGeminiVisionMealAtomically(
        date: day,
        mealType: mealType,
        ownerId: visit.ownerId,
        requestId: analysis.requestId,
        items: items,
        isCurrentOwner: () => visit.current,
      );
      if (!visit.current) return const MealVisionReviewDecision.retired();
      saved = true;
      return const MealVisionReviewDecision.accepted();
    },
  );
  return saved && visit.current;
}
