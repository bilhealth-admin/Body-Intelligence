import 'package:flutter/material.dart';

import '../../../app/theme/premium_design_tokens.dart';
import '../connected_health_model.dart';
import '../connected_health_copy.dart';

class HealthSlide extends StatelessWidget {
  const HealthSlide({
    super.key,
    required this.title,
    required this.result,
    required this.explanation,
    required this.footer,
    required this.icon,
  });

  final String title;
  final String result;
  final String explanation;
  final String footer;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .105),
            const Color(0xFF5BDAFF).withValues(alpha: .045),
            Colors.white.withValues(alpha: .035),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .14),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(
          compact ? PremiumDesignTokens.spaceXs : PremiumDesignTokens.spaceSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: PremiumDesignTokens.spaceXs),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 3 : 5),
            Text(
              result,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: compact
                  ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )
                  : Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: compact ? 3 : 6),
            Expanded(
              child: Text(
                explanation,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            SizedBox(height: compact ? 3 : 6),
            Text(
              footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectedHealthStatusDot extends StatelessWidget {
  const ConnectedHealthStatusDot({super.key, required this.status});
  final ConnectedHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectedHealthStatus.ready ||
      ConnectedHealthStatus.synchronized => Colors.greenAccent,
      ConnectedHealthStatus.permissionRequired ||
      ConnectedHealthStatus.permissionDenied ||
      ConnectedHealthStatus.authorizationRequested ||
      ConnectedHealthStatus.syncing => Colors.amberAccent,
      ConnectedHealthStatus.updateRequired => Colors.orangeAccent,
      ConnectedHealthStatus.degraded => Colors.orangeAccent,
      ConnectedHealthStatus.unavailable => Colors.grey,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class ConnectedHealthErrorContent extends StatelessWidget {
  const ConnectedHealthErrorContent({
    super.key,
    required this.languageCode,
    required this.onRetry,
  });
  final String languageCode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        connectedHealthTextForLanguage(
          languageCode,
          'Health Hub',
          'المركز الصحي',
        ),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: PremiumDesignTokens.spaceSm),
      Text(
        connectedHealthTextForLanguage(
          languageCode,
          'Health Hub status could not be read. No data was deleted or uploaded.',
          'تعذر قراءة حالة المركز الصحي. لم تُحذف أو تُرفع أي بيانات.',
        ),
      ),
      const SizedBox(height: PremiumDesignTokens.spaceSm),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(
            connectedHealthTextForLanguage(
              languageCode,
              'Try again',
              'إعادة المحاولة',
            ),
          ),
        ),
      ),
    ],
  );
}
