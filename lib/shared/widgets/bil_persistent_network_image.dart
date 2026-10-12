import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/services/scoped_media_file_cache.dart';
import '../../app/services/scoped_media_access.dart';

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
    this.cache,
    this.access,
    this.viewerId,
    this.onDecoded,
  });
  final String url;
  final BoxFit? fit;
  final int? decodeWidth;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final String? semanticLabel;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ScopedMediaFileCache? cache;
  final ScopedMediaAccess? access;
  final String? viewerId;
  final VoidCallback? onDecoded;
  @override
  State<BilPersistentNetworkImage> createState() =>
      _BilPersistentNetworkImageState();
}

class _BilPersistentNetworkImageState extends State<BilPersistentNetworkImage>
    with WidgetsBindingObserver {
  late final _cache = widget.cache ?? ScopedMediaFileCache.instance;
  late final _access = widget.access ?? ScopedMediaAccess.instance;
  Uri? _activeUri;
  File? _file;
  Object? _error;
  int _generation = 0;
  String? _viewer;
  bool _retired = false;
  StreamSubscription<AuthState>? _auth;
  Timer? _expiry;
  Timer? _renewal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewer = widget.viewerId;
    try {
      final client = Supabase.instance.client;
      _viewer = widget.viewerId ?? client.auth.currentUser?.id;
      _cache.bindViewer(_viewer);
      _auth = client.auth.onAuthStateChange.listen((state) {
        if (state.session == null && state.event != AuthChangeEvent.signedOut) {
          return;
        }
        final next = state.session?.user.id;
        if (next == _viewer) return;
        final uri = Uri.tryParse(widget.url);
        _viewer = next;
        _generation++;
        _retired = uri != null && ScopedMediaFileCache.isPrivate(uri);
        _file = null;
        _error = null;
        _cache.bindViewer(next);
        _access.bindViewer(next);
        _refresh();
        // The previous private URL is a capability of the previous visit. A
        // newly authorized feed must supply a fresh widget/URL before reusing it.
        if (!_retired) unawaited(_load());
      });
    } on Object {
      /* Isolated public-image previews need no Supabase client. */
    }
    _cache.addListener(_onInvalidated);
    _access.bindViewer(_viewer);
    _cache.bindViewer(_viewer);
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
    _renewal?.cancel();
    _retired = uri != null && ScopedMediaFileCache.isPrivate(uri);
    _error = StateError('Photo access changed.');
    _refresh();
  }

  @override
  void didUpdateWidget(covariant BilPersistentNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewerId != widget.viewerId) {
      _generation++;
      _viewer = widget.viewerId;
      _file = null;
      _activeUri = null;
      _cache.bindViewer(_viewer);
      _access.bindViewer(_viewer);
      unawaited(_load());
      return;
    }
    if (oldWidget.url == widget.url) return;
    final oldUri = Uri.tryParse(oldWidget.url),
        nextUri = Uri.tryParse(widget.url);
    if (oldUri == null ||
        nextUri == null ||
        (ScopedMediaFileCache.identity(oldUri, _viewer) !=
                ScopedMediaFileCache.identity(nextUri, _viewer) &&
            !_samePublicOwner(oldUri, nextUri))) {
      _file = null;
    }
    _retired = false;
    _activeUri = null;
    unawaited(_load());
  }

  bool _samePublicOwner(Uri a, Uri b) =>
      ScopedMediaFileCache.supports(a) &&
      ScopedMediaFileCache.supports(b) &&
      !ScopedMediaFileCache.isPrivate(a) &&
      !ScopedMediaFileCache.isPrivate(b) &&
      a.pathSegments.take(a.pathSegments.length - 1).join('/') ==
          b.pathSegments.take(b.pathSegments.length - 1).join('/');

  Future<void> _verifyDecode(File file) async {
    if (_file?.path == file.path) return;
    final codec = await ui.instantiateImageCodec(
      await file.readAsBytes(),
      targetWidth: widget.decodeWidth,
    );
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load(renew: true));
  }

  Future<void> _load({bool renew = false}) async {
    final generation = ++_generation,
        viewer = _viewer,
        original = Uri.tryParse(widget.url);
    _expiry?.cancel();
    _renewal?.cancel();
    _error = null;
    if (original == null || !ScopedMediaFileCache.supports(original)) return;
    bool current() => mounted && generation == _generation && viewer == _viewer;
    var uri = _activeUri ?? original;
    void scheduleExpiry(Uri value) {
      final expiry = ScopedMediaFileCache.capabilityExpiry(value);
      if (ScopedMediaFileCache.isPrivate(value) && expiry != null) {
        final remaining = expiry.difference(DateTime.now());
        _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
          if (!current()) return;
          _file = null;
          _retired = true;
          _error = StateError('Photo access expired. Refresh the post.');
          _refresh();
        });
        final before = remaining - ScopedMediaAccess.renewBefore;
        if (!before.isNegative && before > Duration.zero) {
          _renewal = Timer(before, () => unawaited(_load(renew: true)));
        }
      }
    }

    scheduleExpiry(uri);
    try {
      if (ScopedMediaFileCache.isPrivate(uri)) {
        if (viewer == null) throw const PhotoAccessDenied();
        uri = await _access.authorize(original, viewer, refresh: renew);
        if (!current()) return;
        _activeUri = uri;
        _retired = false;
        _expiry?.cancel();
        _renewal?.cancel();
        scheduleExpiry(uri);
      }
      var cached = await _cache.peek(uri, viewer);
      if (!current()) return;
      if (cached != null) {
        try {
          await _verifyDecode(cached);
        } on Object {
          await _cache.remove(uri, viewer);
          cached = null;
        }
        if (!current()) return;
        if (cached != null) {
          _file = cached;
          _refresh();
        }
      }
      final file = await _cache.resolve(uri, viewer, current: current);
      await _verifyDecode(file);
      if (current()) {
        _file = file;
        _refresh();
      }
    } on Object catch (error) {
      if (current()) {
        if (error is PhotoAccessDenied) {
          _file = null;
          _retired = true;
          await _cache.remove(uri, viewer);
          _access.invalidate(uri, viewer);
        }
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
    _renewal?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _fallback(BuildContext context, Object error, StackTrace? stack) =>
      widget.errorBuilder?.call(context, error, stack) ??
      const Icon(Icons.image_not_supported_outlined);

  @override
  Widget build(BuildContext context) {
    final uri = _activeUri ?? Uri.tryParse(widget.url);
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
        key: ValueKey(
          '$_viewer|${uri.host}|${uri.pathSegments.take(uri.pathSegments.isNotEmpty ? uri.pathSegments.length - 1 : 0).join('/')}',
        ),
        widget.url,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        gaplessPlayback: widget.gaplessPlayback,
        semanticLabel: widget.semanticLabel,
        errorBuilder: _fallback,
        frameBuilder: (_, child, frame, _) {
          if (frame != null) widget.onDecoded?.call();
          return child;
        },
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
        frameBuilder: (_, child, frame, _) {
          if (frame != null) widget.onDecoded?.call();
          return child;
        },
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
