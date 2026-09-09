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
    super.key,
  });
  final ScrollController controller;
  final Widget child;
  final String? latestMessageId;

  @override
  State<ChatHistoryViewport> createState() => _ChatHistoryViewportState();
}

class _ChatHistoryViewportState extends State<ChatHistoryViewport>
    with WidgetsBindingObserver {
  static const _threshold = 72.0;
  bool _followingLatest = true;
  bool _pinQueued = false;
  bool _disposed = false;
  int _interactionGeneration = 0;

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
    return position.pixels - position.minScrollExtent <= _threshold;
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
      _interactionGeneration++;
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
      if ((position.pixels - position.minScrollExtent).abs() > 0.5) {
        widget.controller.jumpTo(position.minScrollExtent);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _interactionGeneration++;
    }
    if (notification is UserScrollNotification ||
        notification is ScrollEndNotification ||
        (notification is ScrollUpdateNotification &&
            notification.dragDetails != null)) {
      _followingLatest = _nearLatest;
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.depth == 0 && _followingLatest) _queuePin();
            return false;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              PositionedDirectional(
                bottom: 10,
                end: 12,
                child: AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) {
                    if (_nearLatest) return const SizedBox.shrink();
                    return IconButton.filledTonal(
                      key: const ValueKey('chat-jump-to-latest'),
                      tooltip: _latestMessageLabel(
                        Localizations.localeOf(context),
                      ),
                      onPressed: () {
                        _interactionGeneration++;
                        _followingLatest = true;
                        if (widget.controller.hasClients &&
                            widget.controller.position.hasContentDimensions) {
                          widget.controller.jumpTo(
                            widget.controller.position.minScrollExtent,
                          );
                        }
                        _queuePin(force: true);
                      },
                      icon: const Icon(Icons.arrow_downward_rounded),
                    );
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
