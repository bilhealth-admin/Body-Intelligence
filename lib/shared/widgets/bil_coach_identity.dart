import 'package:flutter/material.dart';

/// The immutable visual identity used by every AI Coach and AI Boost surface.
///
/// Account photos deliberately are not accepted by this widget. A member can
/// change or remove their profile photo without changing the BIL coach.
const bilApprovedAiCoachAsset =
    'assets/images/commerce/bil_ai_boost_coach_icon_512.png';

class BilCoachPortrait extends StatelessWidget {
  const BilCoachPortrait({
    super.key,
    this.imageKey,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.cacheWidth,
    this.cacheHeight,
  });

  final Key? imageKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) => Image.asset(
    bilApprovedAiCoachAsset,
    key: imageKey,
    width: width,
    height: height,
    fit: fit,
    alignment: alignment,
    filterQuality: filterQuality,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    excludeFromSemantics: true,
  );
}
