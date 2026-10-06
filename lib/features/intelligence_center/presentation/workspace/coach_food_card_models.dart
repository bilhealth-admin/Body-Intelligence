import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../../data/repositories/meal_repository.dart';
import '../../domain/bil_action_receipt.dart';
import '../../domain/food_v2/coach_food_v2.dart';

enum CoachFoodReviewStatus { ready, running, failed, conflict, closed }

enum CoachFoodReceiptStatus { ready, running, conflict, unavailable }

/// The caller resolves an image from this exact saved identity. A missing image
/// is rendered as unavailable; names never select an unrelated stock image.
typedef CoachFoodThumbnailResolver =
    ImageProvider<Object>? Function(CoachFoodSnapshot food);

/// Stable controls shared by the conversation host and real widget tests.
abstract final class CoachFoodCardKeys {
  static ValueKey<String> review(String operationId) =>
      ValueKey('coach-food-review-$operationId');
  static ValueKey<String> confirm(String operationId) =>
      ValueKey('coach-food-review-confirm-$operationId');
  static ValueKey<String> adjust(String operationId) =>
      ValueKey('coach-food-review-adjust-$operationId');
  static ValueKey<String> reviewFood(String operationId, int index) =>
      ValueKey('coach-food-review-food-$operationId-$index');
  static ValueKey<String> receipt(String operationId) =>
      ValueKey('coach-food-receipt-$operationId');
  static ValueKey<String> receiptStatus(String operationId) =>
      ValueKey('coach-food-receipt-status-$operationId');
  static ValueKey<String> receiptFood(String uuid) =>
      ValueKey('coach-food-receipt-food-$uuid');
  static ValueKey<String> edit(String uuid) =>
      ValueKey('coach-food-receipt-edit-$uuid');
  static ValueKey<String> menu(String operationId) =>
      ValueKey('coach-food-receipt-menu-$operationId');
  static ValueKey<String> undo(String operationId) =>
      ValueKey('coach-food-receipt-undo-$operationId');
  static ValueKey<String> dailyLog(String operationId) =>
      ValueKey('coach-food-receipt-daily-log-$operationId');
}

/// A proposal or a success-shaped map cannot manufacture a receipt. The commit
/// has a repository-private constructor, and this binding also requires the
/// receipt's operation, entity, original commit time and exact readback.
abstract final class CoachFoodReceiptBinding {
  static bool matches(CoachMealCommit commit, BilActionReceipt receipt) {
    if (!receipt.verified ||
        commit.after.isEmpty ||
        receipt.operationId != commit.operationId ||
        receipt.toolId != commit.toolId ||
        !receipt.completedAt.isAtSameMomentAs(commit.committedAt) ||
        receipt.after['arguments_digest'] != commit.argumentsDigest ||
        receipt.after['state'] != commit.state.name) {
      return false;
    }
    final single = commit.after.length == 1;
    final expectedId = single
        ? commit.after.single.item.id.toString()
        : commit.after.first.meal.id.toString();
    if (receipt.entityType != (single ? 'meal_item' : 'meal') ||
        receipt.entityId != expectedId ||
        !_sameTime(receipt.undoneAt, commit.undoneAt)) {
      return false;
    }
    final items = commit.state == CoachMealResultState.undone
        ? commit.current.map((item) => item?.toReceiptPayload()).toList()
        : commit.after.map((item) => item.toReceiptPayload()).toList();
    if (!_sameJson(receipt.after['items'], items)) return false;
    final current = receipt.after['current_items'];
    return current == null ||
        _sameJson(
          current,
          commit.current.map((item) => item?.toReceiptPayload()).toList(),
        );
  }

  static bool _sameTime(DateTime? left, DateTime? right) => left == null
      ? right == null
      : right != null && left.isAtSameMomentAs(right);

  static bool _sameJson(Object? left, Object? right) {
    if (left is Map && right is Map) {
      return left.length == right.length &&
          left.keys.every(
            (key) => right.containsKey(key) && _sameJson(left[key], right[key]),
          );
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_sameJson(left[index], right[index])) return false;
      }
      return true;
    }
    return left == right;
  }
}
