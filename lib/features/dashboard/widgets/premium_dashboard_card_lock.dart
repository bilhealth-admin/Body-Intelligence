import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/localization/runtime_copy.dart';

/// A compact, truthful Premium preview for dashboard cards.
///
/// The real card stays visible behind glass, while the overlay names the
/// hidden capability and its concrete value. It never authorizes access; the
/// destination route repeats the server-verified entitlement check.
class PremiumDashboardCardLock extends StatelessWidget {
  const PremiumDashboardCardLock({
    required this.locked,
    required this.title,
    required this.detail,
    required this.child,
    required this.onTap,
    this.borderRadius = 24,
    this.revealPreview = false,
    super.key,
  });

  final bool locked;
  final String title;
  final String detail;
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final bool revealPreview;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: IgnorePointer(child: child),
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Material(
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0x24FFFFFF)
                    : const Color(0x29000000),
                child: InkWell(
                  key: const Key('dashboard-premium-glass-lock'),
                  onTap: onTap,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 165;
                      final locale = Localizations.localeOf(
                        context,
                      ).toLanguageTag();
                      final trialLabel =
                          RuntimeCopy.resolve('7 days free', locale) ??
                          '7 days free';
                      final light =
                          Theme.of(context).brightness == Brightness.light;
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 11 : 18,
                          vertical: compact ? 9 : 15,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0x88E8BB4F)),
                        ),
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              // Neutral frosted glass: the real card stays
                              // visible. No grey/brand-coloured veil replaces
                              // the protected content.
                              color: light
                                  ? const Color(0x8CFFFFFF)
                                  : const Color(0x52000000),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0x72E8BB4F),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 10 : 14,
                                vertical: compact ? 7 : 10,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.workspace_premium_rounded,
                                          color: Color(0xFFD79A1E),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 7),
                                        Flexible(
                                          child: Text(
                                            title,
                                            maxLines: compact ? 1 : 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: light
                                                      ? const Color(0xFF17130B)
                                                      : Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  height: 1.15,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      detail,
                                      maxLines: compact ? 2 : 3,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: light
                                                ? const Color(0xFF35404A)
                                                : const Color(0xFFE1E8EF),
                                            height: 1.28,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 7),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: light
                                            ? const Color(0x38FFD66B)
                                            : const Color(0x22FFD66B),
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(
                                          color: const Color(0x55FFD66B),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              trialLabel,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: light
                                                        ? const Color(
                                                            0xFF805000,
                                                          )
                                                        : const Color(
                                                            0xFFFFD66B,
                                                          ),
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 14,
                                              color: Color(0xFFD79A1E),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
