import 'package:flutter/material.dart';

import '../../features/intelligence_center/presentation/coach_native_markdown.dart';
import '../../features/intelligence_center/presentation/coach_reply_arrival.dart';
import '../../features/intelligence_center/presentation/coach_sent_message_arrival.dart';

/// Presentation only. It never sends, acknowledges or persists a message.
class BilConversationPresentation extends ChangeNotifier {
  String _scope = '';
  bool _loaded = false;
  DateTime? _latest;
  final _known = <String>{};
  final _incoming = <String>{};
  final _origins = <String, Rect>{};
  final _painted = <String, bool>{};
  final _arrived = <String>{};
  _ConversationSendVisual? _send;

  String get scope => _scope;

  void reset(String scope) {
    _scope = scope;
    _loaded = false;
    _latest = null;
    _known.clear();
    _incoming.clear();
    _origins.clear();
    _painted.clear();
    _arrived.clear();
    _send = null;
  }

  void beginSend(String text, Rect? origin) {
    _send = origin == null
        ? null
        : _ConversationSendVisual(text, origin, Set.of(_known));
  }

  void confirmSend() => _send?.confirmed = true;
  void abandonSend() => _send = null;

  void observe(Iterable<BilConversationPresentationRow> values) {
    final rows = values.toList(growable: false);
    final fresh = rows.where((row) => !_known.contains(row.id)).toList();
    if (_loaded) {
      _incoming.addAll(
        fresh
            .where(
              (row) =>
                  !row.mine &&
                  (_latest == null || !row.createdAt.isBefore(_latest!)),
            )
            .map((row) => row.id),
      );
    }
    final send = _send;
    if (send != null) {
      // This matches presentation to a newly fetched own row only. Ambiguous
      // concurrent copies receive no flight; this is never delivery evidence.
      final matches = rows
          .where(
            (row) =>
                row.mine &&
                row.text == send.text &&
                !send.known.contains(row.id),
          )
          .toList(growable: false);
      if (matches.length == 1) {
        _origins[matches.single.id] = send.origin;
        _send = null;
      } else if (send.confirmed) {
        _send = null;
      }
    }
    for (final row in rows) {
      _known.add(row.id);
      _painted.putIfAbsent(row.id, () => false);
      if (!_incoming.contains(row.id)) _arrived.add(row.id);
      if (_latest == null || row.createdAt.isAfter(_latest!)) {
        _latest = row.createdAt;
      }
    }
    _loaded = true;
  }

  bool animateIncoming(String id) => _incoming.contains(id);
  Rect? originFor(String id) => _origins[id];
  void finishOutgoing(String id) => _origins.remove(id);
  bool isPainted(String id) => _painted[id] == true && _arrived.contains(id);
  void presentationBecameVisible(String id) {
    if (_known.contains(id) && _arrived.add(id)) notifyListeners();
  }

  void markPainted(String id, bool ready) {
    if (!_known.contains(id) || _painted[id] == ready) return;
    _painted[id] = ready;
    notifyListeners();
  }

  @override
  void dispose() {
    reset('');
    super.dispose();
  }
}

class BilConversationPresentationRow {
  const BilConversationPresentationRow({
    required this.id,
    required this.text,
    required this.mine,
    required this.createdAt,
  });
  final String id;
  final String text;
  final bool mine;
  final DateTime createdAt;
}

class _ConversationSendVisual {
  _ConversationSendVisual(this.text, this.origin, this.known);
  final String text;
  final Rect origin;
  final Set<String> known;
  bool confirmed = false;
}

/// The exact native renderer used by Coach; human messages do not stream.
class BilConversationText extends StatelessWidget {
  const BilConversationText({
    super.key,
    required this.text,
    required this.mine,
    required this.direction,
    required this.style,
    required this.visitIsCurrent,
    required this.onPainted,
    required this.fallback,
  });
  final String text;
  final bool mine;
  final TextDirection direction;
  final TextStyle style;
  final bool Function() visitIsCurrent;
  final ValueChanged<bool> onPainted;
  final Widget fallback;

  static bool get usesNativeText => coachUsesNativeMarkdown;

  @override
  Widget build(BuildContext context) {
    if (!visitIsCurrent()) return const SizedBox.shrink();
    if (mine || !usesNativeText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && visitIsCurrent()) onPainted(true);
      });
      return fallback;
    }
    return CoachNativeMarkdown(
      text: text,
      direction: direction,
      style: style,
      visitIsCurrent: visitIsCurrent,
      onVisibleContentReady: onPainted,
      fallback: fallback,
    );
  }
}

/// Shares Coach motion without sharing its model, prompts or health data.
class BilConversationArrival extends StatelessWidget {
  const BilConversationArrival({
    super.key,
    required this.id,
    required this.presentation,
    required this.mine,
    required this.text,
    required this.direction,
    required this.style,
    required this.visitIsCurrent,
    required this.child,
    this.outgoingGradient,
  });
  final String id;
  final BilConversationPresentation presentation;
  final bool mine;
  final String text;
  final TextDirection direction;
  final TextStyle style;
  final bool Function() visitIsCurrent;
  final Widget child;
  final Gradient? outgoingGradient;

  @override
  Widget build(BuildContext context) {
    if (!visitIsCurrent()) return const SizedBox.shrink();
    if (!mine) {
      return CoachReplyArrival(
        messageId: 'community:${presentation.scope}:$id',
        animate: presentation.animateIncoming(id),
        onPresentationReady: () {
          if (visitIsCurrent()) presentation.presentationBecameVisible(id);
        },
        child: child,
      );
    }
    return CoachSentMessageArrival(
      origin: presentation.originFor(id),
      text: text,
      direction: direction,
      style: style,
      backgroundGradient: outgoingGradient,
      visitIsCurrent: visitIsCurrent,
      onFinished: () => presentation.finishOutgoing(id),
      child: child,
    );
  }
}
