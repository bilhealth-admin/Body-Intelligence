import 'dart:async';

import 'bil_navigation_feedback.dart';
import 'package:flutter/material.dart';

/// For a reversed history list (newest item at offset zero).
/// The input bar stays outside this widget in its parent Scaffold.
/// Resizes follow the latest message only while the user is at the latest end;
/// scrolling back through history must not be treated as a command to jump.
class ChatHistoryViewport extends StatefulWidget {
  const ChatHistoryViewport({
    required this.controller,
    required this.child,
    required this.latestMessageId,
    this.centerJumpButton = false,
    this.latestTargetOffset,
    this.onLatestRequested,
    super.key,
  });
  final ScrollController controller;
  final Widget child;
  final String? latestMessageId;
  final bool centerJumpButton;

  /// Optional measured reading start for a newest item taller than the viewport.
  /// Other chats retain their existing newest-end behavior by default.
  final double Function(ScrollPosition position)? latestTargetOffset;

  /// A page may reuse its own measured, reduced-motion-aware scroll behavior.
  /// Other chats use the same bounded soft scroll to their latest end.
  final VoidCallback? onLatestRequested;

  @override
  State<ChatHistoryViewport> createState() => _ChatHistoryViewportState();
}

class _ChatHistoryViewportState extends State<ChatHistoryViewport>
    with WidgetsBindingObserver {
  static const _threshold = 72.0;
  bool _followingLatest = true;
  bool _userScrollActive = false;
  bool _pinQueued = false;
  bool _disposed = false;
  int _interactionGeneration = 0;
  Size? _lastViewportSize;

  bool get _nearLatest {
    if (!widget.controller.hasClients) return true;
    final position = widget.controller.position;
    // A ScrollController can have a client during the first build before the
    // viewport has laid out its content. Reading minScrollExtent in that
    // window throws (the metrics are still null) and makes both Community and
    // AI Coach chats fail before their first frame. Treat the unmeasured
    // viewport as following latest; the metrics notification will re-pin once
    // dimensions exist.
    if (!position.hasContentDimensions) return true;
    return widget.latestTargetOffset == null
        ? position.pixels - position.minScrollExtent <= _threshold
        : (position.pixels - _latestTarget(position)).abs() <= _threshold;
  }

  double _latestTarget(ScrollPosition position) {
    final measured = widget.latestTargetOffset?.call(position);
    return measured != null && measured.isFinite
        ? measured
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble()
        : position.minScrollExtent;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _queuePin();
  }

  @override
  void didUpdateWidget(covariant ChatHistoryViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _followingLatest = true;
      _userScrollActive = false;
      _interactionGeneration++;
      _lastViewportSize = null;
    }
    if (_followingLatest &&
        oldWidget.latestMessageId != widget.latestMessageId) {
      _queuePin();
    }
  }

  @override
  void didChangeMetrics() {
    // Called before the resized keyboard/safe-area layout is painted.
    if (_followingLatest) _queuePin();
  }

  void _queuePin({bool force = false}) {
    if (_disposed) return;
    if (force) _followingLatest = true;
    if (!_followingLatest || _pinQueued) return;
    _pinQueued = true;
    final generation = _interactionGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinQueued = false;
      if (!mounted ||
          _disposed ||
          !_followingLatest ||
          generation != _interactionGeneration ||
          !widget.controller.hasClients) {
        return;
      }
      final position = widget.controller.position;
      if (!position.hasContentDimensions) return;
      final target = _latestTarget(position);
      if ((position.pixels - target).abs() > 0.5) {
        widget.controller.jumpTo(target);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _interactionGeneration++;
      _userScrollActive = true;
      _followingLatest = false;
    }
    // A slow drag is still within the latest-end threshold for its first few
    // frames. Re-enabling following there lets a metrics notification queue a
    // jumpTo, which cancels the active drag and leaves the transcript stuck.
    // Hand scrolling back to auto-follow only after the gesture and momentum
    // have ended, never during a user's scroll update.
    if (notification is ScrollEndNotification) {
      _userScrollActive = false;
      _followingLatest = _nearLatest;
    } else if (!_userScrollActive && notification is UserScrollNotification) {
      _followingLatest = _nearLatest;
    }
    return false;
  }

  Widget _layoutHistory(BuildContext context, BoxConstraints constraints) {
    final previous = _lastViewportSize;
    final size = constraints.biggest;
    _lastViewportSize = size.isFinite ? size : null;
    final positions = widget.controller.positions;
    if (previous == null ||
        !size.isFinite ||
        size.height <= 0 ||
        (previous.width - size.width).abs() > .5 ||
        (previous.height - size.height).abs() <= .01 ||
        !_followingLatest ||
        _userScrollActive ||
        widget.latestTargetOffset == null ||
        positions.length != 1) {
      return widget.child;
    }
    final position = positions.single;
    if (position.axisDirection != AxisDirection.up ||
        !position.hasPixels ||
        !position.hasContentDimensions ||
        !position.hasViewportDimension ||
        (position.viewportDimension - previous.height).abs() > .5 ||
        position.isScrollingNotifier.value) {
      return widget.child;
    }
    final target = _latestTarget(position);
    // Only a measured long-reply reading start moves with the viewport's top.
    // A short reply's ordinary newest end must keep the normal physics path.
    if (target - position.minScrollExtent > .5 &&
        (position.pixels - target).abs() <= .5) {
      final corrected = (position.pixels + previous.height - size.height)
          .clamp(position.minScrollExtent, double.infinity)
          .toDouble();
      // correctBy is Flutter's layout-only correction: it does not notify or
      // cancel an activity. Apply it before the history child lays out/paints,
      // rather than exposing one frame before the post-frame pin catches up.
      // Grow-to-fit stops at min; shrink may legitimately exceed the old max.
      position.correctBy(corrected - position.pixels);
    }
    return widget.child;
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => NotificationListener<ScrollNotification>(
    onNotification: _onScroll,
    child: NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 && _followingLatest) _queuePin();
        return false;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Keep the jump-button sibling outside this layout build scope: its
          // visibility must not read a new offset against the old child layout.
          LayoutBuilder(builder: _layoutHistory),
          Positioned(
            bottom: 10,
            left: widget.centerJumpButton ? 0 : null,
            right: widget.centerJumpButton ? 0 : 12,
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                if (_nearLatest) return const SizedBox.shrink();
                final scheme = Theme.of(context).colorScheme;
                final button = Material(
                  elevation: 5,
                  shadowColor: scheme.shadow.withValues(alpha: .18),
                  color: scheme.surface,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: .55),
                      width: .8,
                    ),
                  ),
                  child: IconButton(
                    key: const ValueKey('chat-jump-to-latest'),
                    tooltip: _latestMessageLabel(
                      Localizations.localeOf(context),
                    ),
                    onPressed: () {
                      _interactionGeneration++;
                      final onLatestRequested = widget.onLatestRequested;
                      if (onLatestRequested != null) {
                        // Let the page's animated scroll settle before
                        // metric notifications may pin its position. A
                        // user's drag still cancels following immediately.
                        _followingLatest = false;
                        onLatestRequested();
                        return;
                      }
                      if (widget.controller.hasClients &&
                          widget.controller.position.hasContentDimensions) {
                        final controller = widget.controller;
                        final target = _latestTarget(controller.position);
                        final reduceMotion =
                            MediaQuery.disableAnimationsOf(context) ||
                            View.of(context)
                                .platformDispatcher
                                .accessibilityFeatures
                                .reduceMotion;
                        if (!reduceMotion) {
                          _followingLatest = false;
                          final generation = _interactionGeneration;
                          unawaited(
                            controller
                                .animateTo(
                                  target,
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                )
                                .whenComplete(() {
                                  if (!mounted ||
                                      _disposed ||
                                      generation != _interactionGeneration ||
                                      controller != widget.controller) {
                                    return;
                                  }
                                  _followingLatest = _nearLatest;
                                  if (_followingLatest) _queuePin();
                                }),
                          );
                          return;
                        }
                        _followingLatest = true;
                        controller.jumpTo(target);
                      }
                      _queuePin(force: true);
                    },
                    style: IconButton.styleFrom(
                      foregroundColor: scheme.onSurface,
                      minimumSize: const Size.square(42),
                      maximumSize: const Size.square(42),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const BilNavigationFeedback(
                      child: Icon(Icons.arrow_downward_rounded, size: 23),
                    ),
                  ),
                );
                return widget.centerJumpButton ? Center(child: button) : button;
              },
            ),
          ),
        ],
      ),
    ),
  );
}

String _latestMessageLabel(Locale locale) =>
    const <String, String>{
      'ar': 'أحدث الرسائل',
      'en': 'Latest messages',
      'fr': 'Derniers messages',
      'es': 'Mensajes más recientes',
      'tr': 'En son mesajlar',
      'de': 'Neueste Nachrichten',
      'it': 'Messaggi più recenti',
      'pt': 'Mensagens mais recentes',
      'ur': 'تازہ ترین پیغامات',
      'fa': 'تازه‌ترین پیام‌ها',
      'hi': 'नवीनतम संदेश',
      'id': 'Pesan terbaru',
      'ms': 'Mesej terkini',
      'ja': '最新のメッセージ',
      'ko': '최신 메시지',
      'zh': '最新消息',
      'ru': 'Последние сообщения',
      'bn': 'সাম্প্রতিক বার্তা',
      'vi': 'Tin nhắn mới nhất',
      'th': 'ข้อความล่าสุด',
      'pl': 'Najnowsze wiadomości',
      'nl': 'Nieuwste berichten',
      'uk': 'Останні повідомлення',
    }[locale.languageCode.toLowerCase()] ??
    'Latest messages';
