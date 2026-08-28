import 'dart:ui';

import 'package:flutter/material.dart';

import 'premium_crown_emblem.dart';

enum BilPaidContentTier { premium, premiumAiCoach }

/// Unified visual preview. Authorization must come from trusted server/store
/// state. The full payload builder is never invoked while access is denied.
class PremiumLockedPreview extends StatelessWidget {
  const PremiumLockedPreview({
    required this.requiredTier,
    required this.hasEntitlement,
    required this.preview,
    required this.fullContentBuilder,
    required this.lockedTitle,
    required this.upgradeLabel,
    required this.onUpgrade,
    super.key,
  });

  final BilPaidContentTier requiredTier;
  final bool hasEntitlement;
  final Widget preview;
  final WidgetBuilder fullContentBuilder;
  final String lockedTitle;
  final String upgradeLabel;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    if (hasEntitlement) return fullContentBuilder(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
            child: IgnorePointer(child: preview),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(child: ColoredBox(color: Color(0x52030B14))),
        ),
        Semantics(
          container: true,
          label: lockedTitle,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xF5182A3F),
                      Color(0xF8071523),
                      Color(0xFA030A13),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0x66F5D477)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x9900030A),
                      blurRadius: 42,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PremiumCrownEmblem(size: 58),
                      const SizedBox(height: 14),
                      Text(
                        lockedTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 17),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFE99C),
                              Color(0xFFF3C24E),
                              Color(0xFFD99B27),
                            ],
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onUpgrade,
                            borderRadius: BorderRadius.circular(17),
                            child: SizedBox(
                              height: 52,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      upgradeLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: const Color(0xFF07121E),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Color(0xFF07121E),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
