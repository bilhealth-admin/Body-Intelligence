import 'package:flutter/material.dart';

import '../../../../data/repositories/meal_repository.dart';
import '../../domain/bil_action_receipt.dart';
import 'coach_food_card_components.dart';
import 'coach_food_card_copy.dart';
import 'coach_food_card_models.dart';
import 'coach_food_receipt_content.dart';

export 'coach_food_card_models.dart';

enum _ReceiptMenuAction { undo, nutrition }

/// Renders only repository readback bound to this exact operation. A caller's
/// display status can restrict a receipt; it can never promote an unverified,
/// modified, undone or cancelled result into successful publication.
class CoachFoodReceiptCard extends StatefulWidget {
  const CoachFoodReceiptCard({
    required this.commit,
    required this.receipt,
    required this.ownerIsCurrent,
    required this.onEdit,
    required this.onUndo,
    required this.onViewDailyLog,
    this.status = CoachFoodReceiptStatus.ready,
    this.thumbnailFor,
    super.key,
  });

  final CoachMealCommit commit;
  final BilActionReceipt receipt;
  final bool Function() ownerIsCurrent;
  final Future<void> Function(CoachMealSnapshot item) onEdit;
  final Future<void> Function() onUndo;
  final Future<void> Function() onViewDailyLog;
  final CoachFoodReceiptStatus status;
  final CoachFoodThumbnailResolver? thumbnailFor;

  @override
  State<CoachFoodReceiptCard> createState() => _CoachFoodReceiptCardState();
}

class _CoachFoodReceiptCardState extends State<CoachFoodReceiptCard> {
  int _generation = 0;
  bool _running = false;
  bool _cancelled = false;
  bool _failed = false;
  bool _conflict = false;
  bool _showNutrition = false;
  String? _selectedUuid;
  ({int generation, CoachMealCommit commit, Future<void> Function() undo})?
  _menuWitness;

  bool get _ownerCurrent {
    if (!_cancelled && !widget.ownerIsCurrent()) _cancelled = true;
    return !_cancelled;
  }

  bool get _bound =>
      CoachFoodReceiptBinding.matches(widget.commit, widget.receipt);
  bool get _busy => _running || widget.status == CoachFoodReceiptStatus.running;
  bool get _unavailable =>
      _failed || !_bound || widget.status == CoachFoodReceiptStatus.unavailable;
  bool get _hasConflict =>
      _conflict ||
      widget.status == CoachFoodReceiptStatus.conflict ||
      widget.commit.state == CoachMealResultState.modified;
  bool get _canMutate =>
      _ownerCurrent &&
      !_busy &&
      !_unavailable &&
      !_hasConflict &&
      widget.status == CoachFoodReceiptStatus.ready &&
      widget.commit.state == CoachMealResultState.committed;
  bool get _canUndo =>
      _canMutate && widget.commit.canUndo && widget.receipt.undoable;

  @override
  void didUpdateWidget(covariant CoachFoodReceiptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a new repository readback can retire a local conflict. Recreating a
    // receipt wrapper during an ordinary parent rebuild does not verify data.
    if (oldWidget.commit != widget.commit) {
      _generation++;
      _menuWitness = null;
      _running = false;
      _failed = false;
      _conflict = false;
      _selectedUuid = null;
      _showNutrition = false;
    }
    // External status changes may restrict the UI, but must not release an
    // operation whose callback is still running.
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool mutation = true,
  }) async {
    if (!_ownerCurrent) {
      setState(() {});
      return;
    }
    if (_busy || (mutation && !_canMutate)) return;
    final generation = _generation;
    setState(() => _running = true);
    try {
      await action();
    } on CoachMealConflict catch (error) {
      if (mounted && generation == _generation && _ownerCurrent) {
        setState(() {
          _cancelled = error.reason == CoachMealConflictReason.ownerChanged;
          _failed =
              error.reason == CoachMealConflictReason.readbackUnavailable ||
              error.reason == CoachMealConflictReason.invalidJournal;
          _conflict = !_cancelled && !_failed;
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

  void _select(String uuid) {
    if (!_ownerCurrent) {
      setState(() {});
      return;
    }
    if (!_canMutate) return;
    setState(() => _selectedUuid = _selectedUuid == uuid ? null : uuid);
  }

  @override
  Widget build(BuildContext context) {
    final copy = CoachFoodCardCopy(context);
    if (!_ownerCurrent) {
      return CoachFoodCardSurface(
        key: CoachFoodCardKeys.receipt(widget.commit.operationId),
        child: CoachFoodStatusLine(text: copy.ownerChanged),
      );
    }
    final values = CoachFoodReceiptValues(widget.commit);
    final undone = widget.commit.state == CoachMealResultState.undone;
    final restricted = _unavailable || _hasConflict || undone;
    final success = !restricted && !_busy;
    final statusText = _unavailable
        ? copy.unavailable
        : _hasConflict
        ? copy.conflict
        : undone
        ? copy.undone
        : _busy
        ? copy.working
        : _title(copy, values);
    return CoachFoodCardSurface(
      key: CoachFoodCardKeys.receipt(widget.commit.operationId),
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (success)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 24,
                  color: CoachFoodCardPalette.green,
                ),
              if (success) const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    statusText,
                    key: CoachFoodCardKeys.receiptStatus(
                      widget.commit.operationId,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: success ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              if (!restricted) ...[
                const SizedBox(width: 5),
                Text(
                  MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(widget.commit.committedAt.toLocal()),
                    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                      context,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: CoachFoodCardPalette.muted,
                  ),
                ),
                _menu(copy),
              ],
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: CoachFoodCardPalette.blue,
              ),
            ),
          if (!restricted &&
              widget.commit.kind != CoachMealCommandKind.remove) ...[
            const SizedBox(height: 7),
            CoachFoodReceiptContent(
              values: values,
              selectedUuid: _selectedUuid,
              onSelect: _canMutate ? _select : null,
              onEdit: _canMutate
                  ? (item) => _run(() => widget.onEdit(item))
                  : null,
              showNutrition: _showNutrition,
              thumbnailFor: widget.thumbnailFor,
            ),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: CoachFoodCardKeys.dailyLog(widget.commit.operationId),
              onPressed: _busy
                  ? null
                  : () => _run(widget.onViewDailyLog, mutation: false),
              style: TextButton.styleFrom(
                foregroundColor: CoachFoodCardPalette.blue,
                disabledForegroundColor: CoachFoodCardPalette.muted,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 42),
                textStyle: Theme.of(copy.context).textTheme.labelLarge
                    ?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(copy.dailyLog),
                  const Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu(CoachFoodCardCopy copy) => PopupMenuButton<_ReceiptMenuAction>(
    key: CoachFoodCardKeys.menu(widget.commit.operationId),
    tooltip: copy.receiptActions,
    enabled: !_busy,
    color: const Color(0xFF203043),
    icon: const Icon(
      Icons.more_vert,
      size: 20,
      color: CoachFoodCardPalette.white,
    ),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 180),
    // PopupMenuButton may deliver its selection through a newer widget after
    // the parent rebuilds. Keep the intent bound to the readback at opening.
    onOpened: () => _menuWitness = (
      generation: _generation,
      commit: widget.commit,
      undo: widget.onUndo,
    ),
    onCanceled: () => _menuWitness = null,
    onSelected: (action) {
      final witness = _menuWitness;
      _menuWitness = null;
      if (!_ownerCurrent) {
        setState(() {});
        return;
      }
      if (witness == null ||
          witness.generation != _generation ||
          !identical(witness.commit, widget.commit)) {
        return;
      }
      if (_busy || _unavailable || _hasConflict) return;
      switch (action) {
        case _ReceiptMenuAction.undo:
          if (_canUndo) _run(witness.undo);
        case _ReceiptMenuAction.nutrition:
          setState(() => _showNutrition = !_showNutrition);
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(
        key: CoachFoodCardKeys.undo(widget.commit.operationId),
        value: _ReceiptMenuAction.undo,
        enabled: _canUndo,
        child: Text(
          copy.undo,
          style: const TextStyle(color: CoachFoodCardPalette.white),
        ),
      ),
      PopupMenuItem(
        value: _ReceiptMenuAction.nutrition,
        child: Text(
          copy.nutritionDetails,
          style: const TextStyle(color: CoachFoodCardPalette.white),
        ),
      ),
    ],
  );

  String _title(CoachFoodCardCopy copy, CoachFoodReceiptValues values) =>
      switch (widget.commit.kind) {
        CoachMealCommandKind.quickMacros =>
          values.calorieOnly ? copy.calorieEntry : copy.nutritionEntry,
        CoachMealCommandKind.foods => copy.logged(
          widget.commit.after.first.meal.type,
        ),
        CoachMealCommandKind.quantity ||
        CoachMealCommandKind.replacement => copy.updated,
        CoachMealCommandKind.remove => copy.removed,
        CoachMealCommandKind.move => copy.moved,
      };
}
