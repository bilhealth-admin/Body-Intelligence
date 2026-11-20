import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import '../../app/theme/bil_navigation_press_style.dart';
import 'package:flutter/material.dart';

import 'bil_wordmark.dart';
import 'bil_page_heading.dart';

class BilAccountSurface extends StatelessWidget {
  const BilAccountSurface({
    required this.child,
    super.key,
    this.title,
    this.onBack,
    this.languageSelector,
  });

  final Widget child;
  final String? title;
  final VoidCallback? onBack;
  final Widget? languageSelector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  ConstrainedBox(
                    key: const Key('bil-account-header'),
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight / 2,
                    ),
                    child: SingleChildScrollView(
                      primary: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: LayoutBuilder(
                          builder: (context, headerConstraints) {
                            final style = bilPageHeadingStyle(context);
                            final slotWidth =
                                headerConstraints.maxWidth -
                                (languageSelector == null ? 0 : 152) -
                                64;
                            final painter = TextPainter(
                              text: TextSpan(text: title ?? '', style: style),
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                              maxLines: 2,
                            );
                            late final bool stack;
                            try {
                              painter.layout(
                                maxWidth: slotWidth.clamp(0.0, double.infinity),
                              );
                              stack =
                                  slotWidth <= 0 || painter.didExceedMaxLines;
                            } finally {
                              painter.dispose();
                            }
                            final heading = Semantics(
                              header: true,
                              child: Text(
                                title ?? '',
                                key: const Key('bil-account-page-title'),
                                textAlign: TextAlign.center,
                                style: style,
                              ),
                            );
                            final back = SizedBox.square(
                              dimension: 48,
                              child: onBack == null
                                  ? null
                                  : IconButton.filledTonal(
                                      key: const Key('bil-account-back'),
                                      style:
                                          BilNavigationPressStyle.neutralBubble(
                                            context,
                                          ),
                                      onPressed: onBack,
                                      icon: const BilCrystalArrow(
                                        child: BackButtonIcon(),
                                      ),
                                    ),
                            );
                            if (stack) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: languageSelector,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      back,
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  heading,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                if (languageSelector != null) ...[
                                  SizedBox(
                                    width: 152,
                                    child: Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: languageSelector,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(child: heading),
                                const SizedBox(width: 8),
                                back,
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BilAccountBrand extends StatelessWidget {
  const BilAccountBrand({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BilFullWordmark(height: 46),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
