import 'dart:async';

import 'package:flutter/material.dart';

/// A fetch is not a read. Only continuously visible, foreground activity rows
/// become eligible. This widget never changes a row or a badge optimistically.
class CommunityVisibleActivityScope extends StatefulWidget {
  const CommunityVisibleActivityScope({
    required this.ownerId,
    required this.unreadIds,
    required this.onSeen,
    required this.builder,
    this.enabled = true,
    this.retryKey = 0,
    this.dwell = const Duration(milliseconds: 600),
    super.key,
  });

  final String ownerId;
  final Set<String> unreadIds;
  final Future<Set<String>> Function(List<String> ids) onSeen;
  final Widget Function(BuildContext context, Key Function(String id) marker)
  builder;
  final bool enabled;
  final int retryKey;
  final Duration dwell;

  @override
  State<CommunityVisibleActivityScope> createState() =>
      _CommunityVisibleActivityScopeState();
}

class _CommunityVisibleActivityScopeState
    extends State<CommunityVisibleActivityScope>
    with WidgetsBindingObserver {
  final _viewport = GlobalKey();
  final _markers = <String, GlobalKey>{};
  final _timers = <String, Timer>{};
  final _confirmed = <String>{};
  final _blocked = <String>{};
  final _ready = <String>{};
  Timer? _batchTimer;
  bool _scheduled = false;
  bool _writing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ModalRoute.of(context);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant CommunityVisibleActivityScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ownerId != oldWidget.ownerId ||
        widget.retryKey != oldWidget.retryKey) {
      _generation++;
      _cancelPending();
      _confirmed.clear();
      _blocked.clear();
      _writing = false;
      if (widget.ownerId != oldWidget.ownerId) _markers.clear();
    } else if (!oldWidget.enabled && widget.enabled) {
      _blocked.clear();
    }
    _confirmed.retainAll(widget.unreadIds);
    _blocked.retainAll(widget.unreadIds);
    _schedule();
  }

  bool get _foreground {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return mounted &&
        widget.enabled &&
        widget.ownerId.isNotEmpty &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        ModalRoute.of(context)?.isCurrent != false;
  }

  Set<String> _visibleIds() {
    if (!_foreground) return {};
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached || !viewport.hasSize) {
      return {};
    }
    final media = MediaQuery.of(context);
    final screen = Rect.fromLTWH(
      0,
      media.padding.top,
      media.size.width,
      (media.size.height - media.padding.top - media.viewInsets.bottom)
          .clamp(0.0, media.size.height),
    );
    final clip = (viewport.localToGlobal(Offset.zero) & viewport.size)
        .intersect(screen);
    if (clip.width <= 0 || clip.height <= 0) return {};
    final result = <String>{};
    for (final id in widget.unreadIds) {
      final box = _markers[id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final visible = rect.intersect(clip);
      final height = rect.height.clamp(0.0, clip.height);
      if (height > 0 &&
          rect.width > 0 &&
          visible.height >= height * .5 &&
          visible.width >= rect.width.clamp(0.0, clip.width) * .5) {
        result.add(id);
      }
    }
    return result;
  }

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _scan();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _scan() {
    final visible = _visibleIds();
    for (final id in _timers.keys.toList(growable: false)) {
      if (!visible.contains(id)) _timers.remove(id)?.cancel();
    }
    _ready.retainAll(visible);
    if (visible.isEmpty) {
      _batchTimer?.cancel();
      _batchTimer = null;
      return;
    }
    final generation = _generation;
    for (final id in visible) {
      if (_confirmed.contains(id) ||
          _blocked.contains(id) ||
          _timers.containsKey(id) ||
          _ready.contains(id)) {
        continue;
      }
      _timers[id] = Timer(widget.dwell, () {
        _timers.remove(id);
        if (!mounted || generation != _generation) return;
        if (_visibleIds().contains(id)) {
          _ready.add(id);
          _queueBatch();
        }
      });
    }
  }

  void _queueBatch() {
    if (_writing || _batchTimer != null || _ready.isEmpty) return;
    _batchTimer = Timer(const Duration(milliseconds: 16), () {
      _batchTimer = null;
      unawaited(_flush());
    });
  }

  Future<void> _flush() async {
    if (_writing || !_foreground) return;
    final ids = _ready
        .intersection(_visibleIds())
        .difference(_confirmed)
        .difference(_blocked)
        .take(100)
        .toList(growable: false);
    if (ids.isEmpty) return;
    final generation = _generation;
    final owner = widget.ownerId;
    _ready.removeAll(ids);
    _writing = true;
    try {
      final confirmed = await widget.onSeen(ids);
      if (!mounted || generation != _generation || owner != widget.ownerId) {
        return;
      }
      _confirmed.addAll(confirmed.where(ids.contains));
      _blocked.addAll(ids.where((id) => !confirmed.contains(id)));
    } on Object {
      if (mounted && generation == _generation && owner == widget.ownerId) {
        _blocked.addAll(ids);
      }
    } finally {
      if (mounted && generation == _generation && owner == widget.ownerId) {
        _writing = false;
        // Rows becoming visible during a write must not be lost. Failed rows
        // wait for an explicit scroll, resume, or refresh rather than looping.
        _queueBatch();
        _schedule();
      }
    }
  }

  void _cancelPending() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _ready.clear();
    _batchTimer?.cancel();
    _batchTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _cancelPending();
    } else {
      _blocked.clear();
      _schedule();
    }
  }

  @override
  void didChangeMetrics() => _schedule();

  @override
  void dispose() {
    _generation++;
    _cancelPending();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    return NotificationListener<ScrollNotification>(
      onNotification: (event) {
        if (event.depth == 0) {
          if (event is ScrollStartNotification && event.dragDetails != null) {
            _blocked.clear();
          }
          _schedule();
        }
        return false;
      },
      child: SizedBox.expand(
        key: _viewport,
        child: widget.builder(
          context,
          (id) => _markers.putIfAbsent(id, GlobalKey.new),
        ),
      ),
    );
  }
}
