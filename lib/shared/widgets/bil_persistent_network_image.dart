import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/services/scoped_media_file_cache.dart';

/// Retains pixels for the same authorized object during a refresh. A changed
/// account or object never inherits the old picture, even on queued A -> B -> A.
class BilPersistentNetworkImage extends StatefulWidget {
  const BilPersistentNetworkImage(
    this.url, {
    super.key,
    this.fit,
    this.filterQuality = FilterQuality.medium,
    this.gaplessPlayback = true,
    this.semanticLabel,
    this.errorBuilder,
    this.decodeWidth = 1440,
  });
  final String url;
  final BoxFit? fit;
  final int? decodeWidth;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final String? semanticLabel;
  final ImageErrorWidgetBuilder? errorBuilder;
  @override
  State<BilPersistentNetworkImage> createState() =>
      _BilPersistentNetworkImageState();
}

class _BilPersistentNetworkImageState extends State<BilPersistentNetworkImage> {
  final _cache = ScopedMediaFileCache.instance;
  File? _file;
  Object? _error;
  int _generation = 0;
  String? _viewer;
  bool _retired = false;
  StreamSubscription<AuthState>? _auth;
  Timer? _expiry;

  @override
  void initState() {
    super.initState();
    try {
      final client = Supabase.instance.client;
      _viewer = client.auth.currentUser?.id;
      _cache.bindViewer(_viewer);
      _auth = client.auth.onAuthStateChange.listen((state) {
        final next = state.session?.user.id;
        if (next == _viewer) return;
        final uri = Uri.tryParse(widget.url);
        _viewer = next;
        _generation++;
        _retired = uri != null && ScopedMediaFileCache.isPrivate(uri);
        _file = null;
        _error = null;
        _cache.bindViewer(next);
        _refresh();
        // The previous private URL is a capability of the previous visit. A
        // newly authorized feed must supply a fresh widget/URL before reusing it.
        if (!_retired) unawaited(_load());
      });
    } on Object {
      /* Isolated public-image previews need no Supabase client. */
    }
    _cache.addListener(_onInvalidated);
    unawaited(_load());
  }

  void _refresh() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _onInvalidated() {
    final uri = Uri.tryParse(widget.url), post = _cache.invalidatedPost;
    if (post != null && (uri == null || !uri.path.contains('/$post/'))) return;
    _generation++;
    _file = null;
    _expiry?.cancel();
    _retired = uri != null && ScopedMediaFileCache.isPrivate(uri);
    _error = StateError('Photo access changed.');
    _refresh();
  }

  @override
  void didUpdateWidget(covariant BilPersistentNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    final oldUri = Uri.tryParse(oldWidget.url),
        nextUri = Uri.tryParse(widget.url);
    if (oldUri == null ||
        nextUri == null ||
        ScopedMediaFileCache.identity(oldUri, _viewer) !=
            ScopedMediaFileCache.identity(nextUri, _viewer)) {
      _file = null;
    }
    _retired = false;
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation,
        viewer = _viewer,
        uri = Uri.tryParse(widget.url);
    _expiry?.cancel();
    _error = null;
    if (_retired || uri == null || !ScopedMediaFileCache.supports(uri)) return;
    bool current() =>
        mounted && !_retired && generation == _generation && viewer == _viewer;
    final expiry = ScopedMediaFileCache.capabilityExpiry(uri);
    if (ScopedMediaFileCache.isPrivate(uri) && expiry != null) {
      final remaining = expiry.difference(DateTime.now());
      _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
        if (!current()) return;
        _file = null;
        _retired = true;
        _error = StateError('Photo access expired. Refresh the post.');
        _refresh();
      });
    }
    try {
      final cached = await _cache.peek(uri, viewer);
      if (!current()) return;
      if (cached != null) {
        _file = cached;
        _refresh();
      }
      final file = await _cache.resolve(uri, viewer, current: current);
      if (current()) {
        _file = file;
        _refresh();
      }
    } on Object catch (error) {
      if (current()) {
        // Explicit denial also deletes cached bytes. Other transient errors may
        // keep a valid authorized local image, but never a deleted file.
        if (_file != null && !await _file!.exists()) _file = null;
        if (current()) {
          _error = error;
          _refresh();
        }
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _cache.removeListener(_onInvalidated);
    _auth?.cancel();
    _expiry?.cancel();
    super.dispose();
  }

  Widget _fallback(BuildContext context, Object error, StackTrace? stack) =>
      widget.errorBuilder?.call(context, error, stack) ??
      const Icon(Icons.image_not_supported_outlined);

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      return _fallback(
        context,
        const FormatException('Invalid photo URL'),
        null,
      );
    }
    if (_retired) {
      return _fallback(context, StateError('Photo access unavailable'), null);
    }
    if (!ScopedMediaFileCache.supports(uri)) {
      return Image.network(
        widget.url,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        gaplessPlayback: widget.gaplessPlayback,
        semanticLabel: widget.semanticLabel,
        errorBuilder: _fallback,
      );
    }
    if (!ScopedMediaFileCache.authorizationCurrent(uri, _viewer)) {
      return _fallback(context, StateError('Photo access unavailable'), null);
    }
    final file = _file;
    if (file != null) {
      return Image.file(
        file,
        fit: widget.fit,
        cacheWidth: widget.decodeWidth,
        filterQuality: widget.filterQuality,
        gaplessPlayback: widget.gaplessPlayback,
        semanticLabel: widget.semanticLabel,
        errorBuilder: (context, error, stack) {
          unawaited(_cache.remove(uri, _viewer));
          return _fallback(context, error, stack);
        },
      );
    }
    if (_error != null) return _fallback(context, _error!, null);
    return const Center(child: Icon(Icons.photo_outlined));
  }
}
