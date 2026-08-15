import 'package:flutter/material.dart';

import 'bil_wordmark.dart';

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
            child: Column(
              children: [
                SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 152,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: languageSelector,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          title ?? '',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      SizedBox.square(
                        dimension: 48,
                        child: onBack == null
                            ? null
                            : IconButton.filledTonal(
                                onPressed: onBack,
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
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
        const BilWordmark(height: 46),
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
