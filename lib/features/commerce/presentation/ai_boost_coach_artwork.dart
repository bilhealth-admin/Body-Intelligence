import 'package:flutter/material.dart';

import '../../../shared/widgets/bil_coach_identity.dart';

const bilAiBoostCoachArtworkAsset = bilApprovedAiCoachAsset;

/// Approved coach identity shared by the live AI Boost purchase surfaces.
class BilAiBoostCoachArtwork extends StatelessWidget {
  const BilAiBoostCoachArtwork({
    required this.size,
    required this.semanticLabel,
    super.key,
  }) : assert(size > 0);

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * .24);
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: const Color(0xFF59E2EF),
              borderRadius: radius,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2859E2EF),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * .24 - 1),
              child: BilCoachPortrait(
                imageKey: const ValueKey('ai-boost-coach-artwork-image'),
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
