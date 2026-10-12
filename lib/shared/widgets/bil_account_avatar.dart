import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'bil_persistent_network_image.dart';

/// The single visual contract for the signed-in member's avatar.
///
/// AI Coach keeps its own fixed portrait. Account surfaces deliberately use a
/// neutral member placeholder until the member chooses a personal photo.
class BilAccountAvatar extends StatefulWidget {
  const BilAccountAvatar({
    super.key,
    required this.radius,
    this.photoBytes,
    this.networkUrl,
    this.borderColor,
    this.backgroundColor,
    this.placeholderColor,
    this.ownerId,
    this.loading = false,
  });

  final double radius;
  final Uint8List? photoBytes;
  final String? networkUrl;
  final Color? borderColor;
  final Color? backgroundColor;
  final Color? placeholderColor;
  final String? ownerId;
  final bool loading;

  @override
  State<BilAccountAvatar> createState() => _BilAccountAvatarState();
}

class _BilAccountAvatarState extends State<BilAccountAvatar> {
  ImageProvider<Object>? _display;
  ImageProvider<Object>? _requested;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  int _generation = 0;
  String? _owner;
  String? _displayOwner() {
    if (widget.ownerId != null) return widget.ownerId;
    String? viewer;
    try {
      viewer = Supabase.instance.client.auth.currentUser?.id;
    } on Object {
      /* Preview has no session. */
    }
    return viewer;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestImage();
  }

  @override
  void didUpdateWidget(covariant BilAccountAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_owner != _displayOwner()) {
      _owner = _displayOwner();
      _display = null;
      _requested = null;
    }
    _requestImage();
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _requestImage() {
    if (_owner != _displayOwner()) {
      _owner = _displayOwner();
      _display = null;
      _requested = null;
    }
    final bytes = widget.photoBytes;
    final next = bytes == null || bytes.isEmpty
        ? null
        : ResizeImage.resizeIfNeeded(
            (widget.radius * 2 * MediaQuery.devicePixelRatioOf(context)).ceil(),
            null,
            MemoryImage(bytes),
          );
    final hasRemote = widget.networkUrl?.trim().isNotEmpty == true;
    if (next == null && !widget.loading && !hasRemote) _display = null;
    if (next == _requested) return;
    _detach();
    final generation = ++_generation;
    _requested = next;
    if (next == null) {
      if (!widget.loading && !hasRemote) _display = null;
      return;
    }
    _stream = next.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (image, synchronous) {
        image.dispose();
        if (!mounted || generation != _generation) return;
        if (synchronous) {
          _display = next;
        } else {
          setState(() => _display = next);
        }
        _detach();
      },
      onError: (Object _, StackTrace? _) {
        if (!mounted || generation != _generation) return;
        _detach();
        // A bad new local file does not replace the last decoded image. If there
        // is no previous image, the independently cached cloud path is shown.
      },
    );
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    _generation++;
    _detach();
    super.dispose();
  }

  ImageProvider<Object>? get _foregroundImage {
    return _display;
  }

  ImageProvider<Object>? get _backgroundImage {
    final url = widget.networkUrl?.trim();
    return url == null || url.isEmpty ? null : NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    // A just-selected local image is the visible source of truth. The cloud
    // image remains only behind it as a cross-device/offline fallback, so a
    // delayed NetworkImage can never replace a newer local selection or flash
    // during an unrelated rebuild.
    final foreground = _foregroundImage;
    final background = _backgroundImage;
    final generation = _generation, owner = _owner, url = widget.networkUrl;
    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
      foregroundImage: foreground,
      onForegroundImageError: foreground == null ? null : (_, _) {},
      child: background != null
          ? ClipOval(
              child: SizedBox.square(
                dimension: widget.radius * 2,
                child: BilPersistentNetworkImage(
                  key: ValueKey(_owner),
                  widget.networkUrl!.trim(),
                  decodeWidth:
                      (widget.radius *
                              2 *
                              MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                  fit: BoxFit.cover,
                  onDecoded: () {
                    if (_requested != null || _display == null) return;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          generation == _generation &&
                          owner == _owner &&
                          url == widget.networkUrl &&
                          _requested == null &&
                          _display != null) {
                        setState(() => _display = null);
                      }
                    });
                  },
                  errorBuilder: (_, _, _) => Icon(
                    Icons.person_rounded,
                    size: widget.radius,
                    color: widget.placeholderColor ?? Colors.white,
                  ),
                ),
              ),
            )
          : foreground == null && background == null
          ? Icon(
              Icons.person_rounded,
              size: widget.radius,
              color: widget.placeholderColor ?? Colors.white,
            )
          : null,
    );
    final border = widget.borderColor;
    if (border == null) return avatar;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
      child: avatar,
    );
  }
}
