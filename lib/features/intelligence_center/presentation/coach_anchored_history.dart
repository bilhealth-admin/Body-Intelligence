import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Chronological rows, displayed with the newest end at the bottom.
///
/// A fixed center separates the initially loaded history from new rows. Unlike
/// prepending to a reversed ListView, appending a reply cannot move the older
/// message the user is reading. The parent controls following the newest end
/// via minScrollExtent (which can be negative), independently of this anchor.
class CoachAnchoredHistory extends StatefulWidget {
  const CoachAnchoredHistory({
    required this.controller,
    required this.rowIds,
    required this.itemBuilder,
    super.key,
  });

  final ScrollController controller;
  final List<String> rowIds;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<CoachAnchoredHistory> createState() => _CoachAnchoredHistoryState();
}

class _CoachAnchoredHistoryState extends State<CoachAnchoredHistory> {
  static const _centerKey = ValueKey('coach-history-center');
  String? _anchorId;
  int? _keyboardDismissPointer;
  Offset? _keyboardDismissOrigin;

  void _trackPointerDown(PointerDownEvent event) {
    if (FocusManager.instance.primaryFocus?.hasFocus != true) return;
    _keyboardDismissPointer = event.pointer;
    _keyboardDismissOrigin = event.position;
  }

  void _dismissOnVerticalDrag(PointerMoveEvent event) {
    final origin = _keyboardDismissOrigin;
    if (event.pointer != _keyboardDismissPointer || origin == null) return;
    final movement = event.position - origin;
    if (movement.dy.abs() <= kTouchSlop ||
        movement.dy.abs() <= movement.dx.abs()) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _clearKeyboardDismissPointer();
  }

  void _trackPointerEnd(PointerEvent event) {
    if (event.pointer == _keyboardDismissPointer) {
      _clearKeyboardDismissPointer();
    }
  }

  void _clearKeyboardDismissPointer() {
    _keyboardDismissPointer = null;
    _keyboardDismissOrigin = null;
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.rowIds;
    var anchor = _anchorId == null ? -1 : ids.indexOf(_anchorId!);
    if (anchor < 0 && ids.isNotEmpty) {
      anchor = ids.length - 1;
      _anchorId = ids[anchor];
    }
    final anchorIndex = anchor;
    final newerCount = ids.length - anchorIndex - 1;

    SliverList rows({required bool newer}) => SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final row = newer ? anchorIndex + 1 + index : anchorIndex - index;
          return KeyedSubtree(
            key: ValueKey(ids[row]),
            child: IndexedSemantics(
              index: row,
              child: widget.itemBuilder(context, row),
            ),
          );
        },
        childCount: newer ? newerCount : anchorIndex + 1,
        addSemanticIndexes: false,
        findChildIndexCallback: (key) {
          final row = key is ValueKey<String> ? ids.indexOf(key.value) : -1;
          if (row < 0) return null;
          if (newer) return row > anchorIndex ? row - anchorIndex - 1 : null;
          return row <= anchorIndex ? anchorIndex - row : null;
        },
      ),
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _trackPointerDown,
      onPointerMove: _dismissOnVerticalDrag,
      onPointerUp: _trackPointerEnd,
      onPointerCancel: _trackPointerEnd,
      child: CustomScrollView(
        controller: widget.controller,
        reverse: true,
        center: _centerKey,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        semanticChildCount: ids.length,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, newerCount > 0 ? 12 : 0),
            sliver: rows(newer: true),
          ),
          SliverPadding(
            key: _centerKey,
            padding: EdgeInsets.fromLTRB(10, 18, 10, newerCount == 0 ? 12 : 0),
            sliver: rows(newer: false),
          ),
        ],
      ),
    );
  }
}
