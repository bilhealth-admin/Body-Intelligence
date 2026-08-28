import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../connected_health_model.dart';
import '../connected_health_copy.dart';
import 'live_health_watch.dart';

class HealthHubEmptyState extends StatelessWidget {
  const HealthHubEmptyState({
    super.key,
    required this.snapshot,
    required this.languageCode,
    required this.compact,
    required this.onConnect,
  });

  final ConnectedHealthSnapshot snapshot;
  final String languageCode;
  final bool compact;
  final VoidCallback onConnect;

  String tr(String en, String ar) =>
      connectedHealthTextForLanguage(languageCode, en, ar);

  @override
  Widget build(BuildContext context) {
    final watchSize = compact ? 276.0 : 304.0;
    final carouselHeight = watchSize;
    final shellHeight = compact ? 438.0 : 404.0;
    return SizedBox(
      key: const Key('health-hub-empty-state'),
      height: shellHeight,
      child: Container(
        padding: EdgeInsets.all(
          compact ? PremiumDesignTokens.spaceSm : PremiumDesignTokens.spaceLg,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .36),
              const Color(0xFFDDEEFF).withValues(alpha: .30),
              Colors.white.withValues(alpha: .14),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: .72),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF76B8E8).withValues(alpha: .12),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = !compact && constraints.maxWidth >= 760;
            final illustration = SizedBox(
              height: carouselHeight,
              child: Center(
                child: SizedBox.square(
                  key: const Key('health-hub-fixed-square-watch'),
                  dimension: watchSize,
                  child: LiveHealthWatch(
                    snapshot: snapshot,
                    languageCode: languageCode,
                  ),
                ),
              ),
            );
            final connectButton = FilledButton.icon(
              key: const Key('health-hub-connect-button'),
              onPressed: onConnect,
              icon: const Icon(Icons.link_rounded),
              label: Text(tr('Connect now', 'ربط الآن')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(250, 58),
                backgroundColor: Colors.white.withValues(alpha: .34),
                foregroundColor: const Color(0xFF0A3153),
                elevation: 0,
                side: BorderSide(color: Colors.white.withValues(alpha: .86)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                textStyle: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            );

            if (!horizontal) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  illustration,
                  const SizedBox(height: PremiumDesignTokens.spaceMd),
                  connectButton,
                ],
              );
            }
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: watchSize + 44, child: illustration),
                  const SizedBox(width: PremiumDesignTokens.spaceXl),
                  SizedBox(width: 330, child: connectButton),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
