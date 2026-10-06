import 'package:flutter/material.dart';

import '../../../../data/repositories/meal_repository.dart';
import '../../domain/food_v2/coach_food_v2.dart';
import 'coach_food_card_components.dart';
import 'coach_food_card_copy.dart';
import 'coach_food_card_models.dart';

export 'coach_food_card_models.dart';

/// A reviewed proposal only. Mounting, expanding evidence and Adjust never
/// invoke Confirm. The host owns admission, persistence and the commit receipt.
class CoachFoodReviewCard extends StatefulWidget {
  const CoachFoodReviewCard({
    required this.review,
    required this.operationId,
    required this.mealType,
    required this.day,
    required this.ownerIsCurrent,
    required this.onConfirm,
    required this.onAdjust,
    this.status = CoachFoodReviewStatus.ready,
    this.thumbnailFor,
    super.key,
  });

  final CoachFoodReview review;
  final String operationId;
  final String mealType;
  final DateTime day;

  /// A captured, permanently cancelling owner/conversation witness, not a fresh
  /// provider lookup which could revive an A → B → A session.
  final bool Function() ownerIsCurrent;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onAdjust;
  final CoachFoodReviewStatus status;
  final CoachFoodThumbnailResolver? thumbnailFor;

  @override
  State<CoachFoodReviewCard> createState() => _CoachFoodReviewCardState();
}

class _CoachFoodReviewCardState extends State<CoachFoodReviewCard> {
  int _generation = 0;
  int? _expanded;
  bool _running = false;
  bool _failed = false;
  bool _conflict = false;
  bool _cancelled = false;

  bool get _ownerCurrent {
    if (!_cancelled && !widget.ownerIsCurrent()) _cancelled = true;
    return !_cancelled;
  }

  bool get _busy => _running || widget.status == CoachFoodReviewStatus.running;
  bool get _canAct =>
      _ownerCurrent &&
      !_busy &&
      !_conflict &&
      const {
        CoachFoodReviewStatus.ready,
        CoachFoodReviewStatus.failed,
      }.contains(widget.status);

  @override
  void didUpdateWidget(covariant CoachFoodReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.operationId != widget.operationId ||
        oldWidget.mealType != widget.mealType ||
        oldWidget.day != widget.day ||
        oldWidget.review.items.map((row) => row.digest).join(':') !=
            widget.review.items.map((row) => row.digest).join(':');
    if (changed) {
      _generation++;
      _expanded = null;
      _running = false;
      _failed = false;
      _conflict = false;
      // A cancelled visit does not become current merely by replacing content.
    }
    // A status-only rebuild cannot release an in-flight callback.
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_ownerCurrent) {
      setState(() {});
      return;
    }
    if (!_canAct) return;
    final generation = _generation;
    setState(() {
      _running = true;
      _failed = false;
    });
    try {
      await action();
    } on CoachMealConflict catch (error) {
      if (mounted && generation == _generation && _ownerCurrent) {
        setState(() {
          _cancelled = error.reason == CoachMealConflictReason.ownerChanged;
          _conflict = const {
            CoachMealConflictReason.staleItem,
            CoachMealConflictReason.missingItem,
            CoachMealConflictReason.missingMeal,
          }.contains(error.reason);
          // An unavailable readback does not prove the meal changed or that
          // its write was rolled back. Preserve this exact operation for retry.
          _failed = !_cancelled && !_conflict;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation && _ownerCurrent) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = CoachFoodCardCopy(context);
    if (!_ownerCurrent) {
      return CoachFoodCardSurface(
        key: CoachFoodCardKeys.review(widget.operationId),
        maxWidth: 290,
        child: CoachFoodStatusLine(text: copy.ownerChanged),
      );
    }
    final hasConflict =
        _conflict || widget.status == CoachFoodReviewStatus.conflict;
    return CoachFoodCardSurface(
      key: CoachFoodCardKeys.review(widget.operationId),
      maxWidth: 290,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.intro(widget.mealType)),
          const SizedBox(height: 9),
          for (var index = 0; index < widget.review.items.length; index++)
            _foodRow(copy, widget.review.items[index], index),
          const SizedBox(height: 9),
          Text(copy.question(widget.mealType)),
          const SizedBox(height: 2),
          Text(
            copy.day(widget.day),
            style: const TextStyle(
              fontSize: 11,
              color: CoachFoodCardPalette.muted,
            ),
          ),
          if (_busy ||
              _failed ||
              widget.status == CoachFoodReviewStatus.failed ||
              widget.status == CoachFoodReviewStatus.closed ||
              hasConflict)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: CoachFoodStatusLine(
                running: _busy,
                text: _busy
                    ? copy.working
                    : widget.status == CoachFoodReviewStatus.closed
                    ? copy.closed
                    : hasConflict
                    ? copy.conflict
                    : copy.failed,
              ),
            ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = MediaQuery.textScalerOf(context).scale(13) > 19;
              final confirm = _confirmButton(copy);
              final adjust = _adjustButton(copy);
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [confirm, const SizedBox(height: 4), adjust],
                    )
                  : Row(
                      children: [
                        Expanded(child: confirm),
                        const SizedBox(width: 9),
                        Expanded(child: adjust),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _foodRow(CoachFoodCardCopy copy, CoachFoodPortion portion, int index) {
    final estimated =
        portion.quantity.evidence.kind == CoachFoodQuantityKind.estimated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: CoachFoodCardKeys.reviewFood(widget.operationId, index),
          borderRadius: BorderRadius.circular(7),
          onTap: _busy
              ? null
              : () {
                  if (!_ownerCurrent) {
                    setState(() {});
                    return;
                  }
                  setState(() => _expanded = _expanded == index ? null : index);
                },
          child: Semantics(
            label: copy.details,
            button: true,
            expanded: _expanded == index,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 11,
                    color: CoachFoodCardPalette.green,
                  ),
                  const SizedBox(width: 8),
                  CoachFoodThumbnail(
                    food: portion.food,
                    resolver: widget.thumbnailFor,
                    compact: true,
                    width: 22,
                    height: 27,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 3,
                      children: [
                        Text(
                          copy.reviewLabel(portion),
                          style: const TextStyle(fontSize: 11.5, height: 1.5),
                        ),
                        if (estimated)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF253240),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: CoachFoodCardPalette.border,
                              ),
                            ),
                            child: Text(
                              copy.estimated,
                              style: const TextStyle(
                                fontSize: 9,
                                color: CoachFoodCardPalette.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded == index) CoachFoodEvidenceDetails(portion: portion),
      ],
    );
  }

  Widget _confirmButton(CoachFoodCardCopy copy) => FilledButton.icon(
    key: CoachFoodCardKeys.confirm(widget.operationId),
    onPressed: _canAct ? () => _run(widget.onConfirm) : null,
    icon: const Icon(Icons.check_rounded, size: 18),
    label: Text(copy.yes),
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF2684FF),
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFF24394D),
      disabledForegroundColor: CoachFoodCardPalette.muted,
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      textStyle: Theme.of(
        copy.context,
      ).textTheme.labelLarge?.copyWith(fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
  );

  Widget _adjustButton(CoachFoodCardCopy copy) => OutlinedButton(
    key: CoachFoodCardKeys.adjust(widget.operationId),
    onPressed: _canAct ? () => _run(widget.onAdjust) : null,
    style: OutlinedButton.styleFrom(
      foregroundColor: CoachFoodCardPalette.white,
      disabledForegroundColor: CoachFoodCardPalette.muted,
      backgroundColor: const Color(0xFF213245),
      side: const BorderSide(color: Color(0xFF3C5267)),
      minimumSize: const Size(0, 42),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      textStyle: Theme.of(
        copy.context,
      ).textTheme.labelLarge?.copyWith(fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
    child: Text(copy.adjust),
  );
}
