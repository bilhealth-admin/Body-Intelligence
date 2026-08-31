import 'dart:typed_data';

import 'package:flutter/material.dart';

/// The single visual contract for the signed-in member's avatar.
///
/// AI Coach keeps its own fixed portrait. Account surfaces deliberately use a
/// neutral member placeholder until the member chooses a personal photo.
class BilAccountAvatar extends StatelessWidget {
  const BilAccountAvatar({
    super.key,
    required this.radius,
    this.photoBytes,
    this.networkUrl,
    this.borderColor,
  });

  final double radius;
  final Uint8List? photoBytes;
  final String? networkUrl;
  final Color? borderColor;

  ImageProvider<Object>? get _backgroundImage {
    final bytes = photoBytes;
    if (bytes != null && bytes.isNotEmpty) return MemoryImage(bytes);
    return null;
  }

  ImageProvider<Object>? get _foregroundImage {
    final url = networkUrl?.trim();
    return url == null || url.isEmpty ? null : NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _foregroundImage;
    final background = _backgroundImage;
    final avatar = CircleAvatar(
      radius: radius,
      // The cloud URL is authoritative across devices. Local bytes remain a
      // resilient offline fallback. The coach identity is never an account
      // placeholder.
      foregroundImage: foreground,
      onForegroundImageError: foreground == null ? null : (_, _) {},
      backgroundImage: background,
      child: foreground == null && background == null
          ? Icon(Icons.person_rounded, size: radius, color: Colors.white)
          : null,
    );
    final border = borderColor;
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
