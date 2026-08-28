import 'dart:typed_data';

import 'package:flutter/material.dart';

const bilCoachFallbackAvatarAsset =
    'assets/images/ai_coach/bil_male_smart_coach_v1.png';

/// The single visual contract for the signed-in member's avatar.
///
/// AI Coach keeps its own fixed portrait. Account surfaces use that portrait
/// only as the established fallback until the member chooses a personal photo.
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

  ImageProvider<Object> get _backgroundImage {
    final bytes = photoBytes;
    if (bytes != null && bytes.isNotEmpty) return MemoryImage(bytes);
    return const AssetImage(bilCoachFallbackAvatarAsset);
  }

  ImageProvider<Object>? get _foregroundImage {
    final url = networkUrl?.trim();
    return url == null || url.isEmpty ? null : NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _foregroundImage;
    final avatar = CircleAvatar(
      radius: radius,
      // The cloud URL is authoritative across devices. Local bytes remain a
      // resilient offline fallback, followed by the fixed AI Coach portrait.
      foregroundImage: foreground,
      onForegroundImageError: foreground == null ? null : (_, _) {},
      backgroundImage: _backgroundImage,
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
