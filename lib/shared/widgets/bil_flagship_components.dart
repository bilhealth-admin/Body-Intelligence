import 'package:flutter/material.dart';
import '../../app/theme/bil_flagship_motion.dart';
import '../../app/theme/bil_flagship_tokens.dart';

class BilPremiumSurface extends StatelessWidget {
  const BilPremiumSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BilFlagshipTokens.space24),
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = AnimatedContainer(
      duration: BilFlagshipMotion.duration(context),
      curve: BilFlagshipMotion.enterCurve,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? scheme.surface : null,
        borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusLg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .72)),
        boxShadow: BilFlagshipTokens.shadowCard,
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusLg),
        onTap: onTap,
        child: body,
      ),
    );
  }
}

class BilGradientButton extends StatelessWidget {
  const BilGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: BilFlagshipTokens.brandGradient,
      borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
      boxShadow: BilFlagshipTokens.shadowFloating,
    ),
    child: FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label),
    ),
  );
}

class BilChoiceCard<T> extends StatelessWidget {
  const BilChoiceCard({
    super.key,
    required this.value,
    required this.groupValue,
    required this.title,
    required this.onSelected,
    this.subtitle,
    this.icon,
  });
  final T value;
  final T groupValue;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: title,
      child: AnimatedContainer(
        duration: BilFlagshipMotion.duration(context),
        curve: BilFlagshipMotion.emphasizedCurve,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: .72)
              : scheme.surface,
          borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(BilFlagshipTokens.radiusMd),
          onTap: () => onSelected(value),
          child: Padding(
            padding: const EdgeInsets.all(BilFlagshipTokens.space16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: selected ? scheme.primary : null),
                  const SizedBox(width: BilFlagshipTokens.space12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: BilFlagshipTokens.space4),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? scheme.primary : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
