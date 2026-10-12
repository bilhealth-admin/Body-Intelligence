import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'scoped_media_file_cache.dart';

typedef PrivatePhotoSigner = Future<Uri?> Function(Uri object, String viewer);

/// A capability is renewed only by the authorized backend. Decoded JWT dates
/// can shorten access, but cannot establish visibility or extend a lease.
class ScopedMediaAccess {
  ScopedMediaAccess({PrivatePhotoSigner? signer, DateTime Function()? clock})
    : _signer = signer ?? _signVisiblePhoto,
      _clock = clock ?? DateTime.now;

  static final instance = ScopedMediaAccess();
  static const renewBefore = Duration(seconds: 60);
  final PrivatePhotoSigner _signer;
  final DateTime Function() _clock;
  final Map<String, Uri> _leases = {};
  final Map<String, Future<Uri>> _pending = {};
  String? _viewer;
  int _epoch = 0;

  void bindViewer(String? viewer) {
    if (_viewer == viewer) return;
    _viewer = viewer;
    _epoch++;
    _leases.clear();
    _pending.clear();
  }

  Future<Uri> authorize(Uri original, String viewer, {bool refresh = false}) {
    if (_viewer != viewer ||
        !ScopedMediaFileCache.supports(original) ||
        !ScopedMediaFileCache.isPrivate(original)) {
      return Future.error(StateError('Photo owner changed.'));
    }
    final key = ScopedMediaFileCache.identity(original, viewer);
    final cached = _leases[key];
    final candidate = cached ?? original;
    final expiry = ScopedMediaFileCache.capabilityExpiry(candidate);
    if (!refresh &&
        cached != null &&
        expiry != null &&
        expiry.difference(_clock()) > renewBefore) {
      _leases[key] = candidate;
      return Future.value(candidate);
    }
    final epoch = _epoch;
    return _pending.putIfAbsent(key, () async {
      try {
        final renewed = await _signer(original, viewer);
        if (epoch != _epoch || _viewer != viewer) {
          throw StateError('Photo request retired.');
        }
        final end = renewed == null
            ? null
            : ScopedMediaFileCache.capabilityExpiry(renewed);
        if (renewed == null ||
            end == null ||
            !end.isAfter(_clock()) ||
            !ScopedMediaFileCache.supports(renewed) ||
            ScopedMediaFileCache.identity(renewed, viewer) != key) {
          throw const PhotoAccessDenied();
        }
        _leases[key] = renewed;
        while (_leases.length > 256) {
          _leases.remove(_leases.keys.first);
        }
        return renewed;
      } finally {
        if (epoch == _epoch) _pending.remove(key);
      }
    });
  }

  void invalidate(Uri uri, String? viewer) {
    _epoch++;
    _pending.clear();
    _leases.remove(ScopedMediaFileCache.identity(uri, viewer));
  }

  static Future<Uri?> _signVisiblePhoto(Uri object, String viewer) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser?.id != viewer) {
      throw StateError('Photo owner changed.');
    }
    const prefix = '/storage/v1/object/sign/community-post-images/';
    final path = object.path.substring(prefix.length);
    final parts = path.split('/');
    if (parts.length < 3) throw const PhotoAccessDenied();
    // RLS is checked again even when the CDN still returns an expired URL.
    final post = await client
        .from('bil_community_posts')
        .select('id')
        .eq('id', parts[1])
        .eq('author_id', parts[0])
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (client.auth.currentUser?.id != viewer) {
      throw StateError('Photo owner changed.');
    }
    if (post == null) throw const PhotoAccessDenied();
    final signed = await client.storage
        .from('community-post-images')
        .createSignedUrl(path, 3600);
    if (client.auth.currentUser?.id != viewer) {
      throw StateError('Photo owner changed.');
    }
    return Uri.tryParse(signed);
  }
}

class PhotoAccessDenied implements Exception {
  const PhotoAccessDenied();
}
