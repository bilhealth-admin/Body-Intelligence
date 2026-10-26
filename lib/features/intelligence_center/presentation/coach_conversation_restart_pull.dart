import 'package:flutter/material.dart';

import '../../../shared/widgets/bil_pearl_feature_welcome.dart';

/// An explicit upward pull beyond the newest end of the reversed transcript.
/// Ordinary scrolling, ballistic motion and programmatic jumps cannot restart
/// a conversation. The parent saves and verifies the archive before clearing.
class CoachConversationRestartPull extends StatefulWidget {
  const CoachConversationRestartPull({
    required this.controller,
    required this.enabled,
    required this.conversationIdentity,
    required this.label,
    required this.onRestart,
    required this.child,
    super.key,
  });

  static const previewDistance = 12.0;
  static const restartDistance = 112.0;

  final ScrollController controller;
  final bool enabled;
  final Object? conversationIdentity;
  final String label;
  final Future<void> Function() onRestart;
  final Widget child;

  @override
  State<CoachConversationRestartPull> createState() =>
      _CoachConversationRestartPullState();
}

class _CoachConversationRestartPullState
    extends State<CoachConversationRestartPull> {
  int? _pointer;
  Offset? _last;
  bool _atNewest = false;
  bool _working = false;
  double _distance = 0;

  bool get _newestVisible =>
      widget.controller.hasClients &&
      widget.controller.position.hasContentDimensions &&
      widget.controller.position.pixels <=
          widget.controller.position.minScrollExtent + 2;

  @override
  void didUpdateWidget(CoachConversationRestartPull oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationIdentity != widget.conversationIdentity ||
        oldWidget.controller != widget.controller ||
        !widget.enabled) {
      // Do not carry a gesture across an account, conversation or busy state.
      _clear();
    }
  }

  void _clear() {
    _pointer = null;
    _last = null;
    _distance = 0;
    _atNewest = false;
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _working || _pointer != null) return;
    _pointer = event.pointer;
    _last = event.position;
    _atNewest = _newestVisible;
    _distance = 0;
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer || !widget.enabled || _working) return;
    final previous = _last!;
    _last = event.position;
    if (!_newestVisible) {
      if (_distance != 0) setState(() => _distance = 0);
      _atNewest = false;
      return;
    }
    if (!_atNewest) {
      // Arrival at the newest message is not itself an extra pull. Ignore
      // every pixel used to read the transcript before reaching this edge.
      _atNewest = true;
      return;
    }
    final movement = event.position - previous;
    if (movement.dx.abs() > movement.dy.abs()) return;
    setState(() {
      _distance = (_distance - movement.dy).clamp(0, 240);
    });
  }

  Future<void> _up(PointerUpEvent event) async {
    if (event.pointer != _pointer) return;
    final restart =
        widget.enabled &&
        !_working &&
        _atNewest &&
        _newestVisible &&
        _distance >= CoachConversationRestartPull.restartDistance;
    setState(_clear);
    if (!restart) return;
    setState(() => _working = true);
    try {
      await widget.onRestart();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _cancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) setState(_clear);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _cancel,
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_working ||
            _distance >= CoachConversationRestartPull.previewDistance)
          Positioned(
            left: 12,
            right: 12,
            bottom: 8,
            child: IgnorePointer(
              child: Center(
                child: Semantics(
                  liveRegion: true,
                  label: widget.label,
                  child: ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          key: const Key('coach-new-conversation-pull-status'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox.square(
                              dimension: 24,
                              child: BilFeatureWelcomeStatus(),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                widget.label,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
