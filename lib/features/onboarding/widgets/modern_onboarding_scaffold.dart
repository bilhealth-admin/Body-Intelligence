import 'package:flutter/material.dart';

import '../../../shared/widgets/bil_wordmark.dart';
import '../onboarding_runtime_copy.dart';

String _copy(BuildContext context, String english) =>
    OnboardingRuntimeCopy.resolve(english, Localizations.localeOf(context));

class ModernOnboardingScaffold extends StatelessWidget {
  const ModernOnboardingScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.body,
    required this.onBack,
    required this.onNext,
    this.subtitle,
    this.onSkip,
    this.nextLabel,
    this.nextEnabled = true,
    this.busy = false,
    this.artwork,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final Widget body;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final String? nextLabel;
  final bool nextEnabled;
  final bool busy;

  /// Optional BIL-owned photo hero. The slot collapses when a step deliberately
  /// has no approved release asset.
  final Widget? artwork;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final baseScheme = baseTheme.colorScheme;
    final dark = baseTheme.brightness == Brightness.dark;
    final scheme = baseScheme.copyWith(
      primary: dark ? const Color(0xFFAFC6FF) : const Color(0xFF1D4ED8),
      onPrimary: dark ? const Color(0xFF091A3B) : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF172B57)
          : const Color(0xFFE4EDFF),
      onPrimaryContainer: dark
          ? const Color(0xFFE7EDFF)
          : const Color(0xFF071B46),
    );
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Theme(
      data: baseTheme.copyWith(colorScheme: scheme),
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DecoratedBox(
                            key: const Key('onboarding-identity-surface'),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEFEFF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFDCE6FA),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                12,
                                8,
                                12,
                                8,
                              ),
                              child: BilFullWordmark(
                                key: Key('onboarding-wordmark'),
                                height: 24,
                                alignment: AlignmentDirectional.centerStart,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _SegmentedProgress(
                            step: step,
                            total: totalSteps,
                            reducedMotion: reducedMotion,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: ValueKey<String>('onboarding-scroll-$step'),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                key: const Key('onboarding-step-title'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.7,
                                      height: 1.12,
                                    ),
                              ),
                            ),
                            if (subtitle case final subtitle?) ...[
                              const SizedBox(height: 10),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                              ),
                            ],
                            if (artwork case final artwork?) ...[
                              const SizedBox(height: 18),
                              artwork,
                            ],
                            const SizedBox(height: 24),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1),
                              child: body,
                            ),
                          ],
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        border: Border(
                          top: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final textScale = MediaQuery.textScalerOf(
                              context,
                            ).scale(1);
                            final stackActions =
                                textScale >= 1.6 || constraints.maxWidth < 330;
                            final back = FocusTraversalOrder(
                              order: const NumericFocusOrder(2),
                              child: IconButton.filledTonal(
                                key: const Key('onboarding-back'),
                                tooltip: _copy(context, 'Back'),
                                onPressed: busy ? null : onBack,
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                            );
                            final skip = onSkip == null
                                ? null
                                : FocusTraversalOrder(
                                    order: const NumericFocusOrder(3),
                                    child: TextButton(
                                      key: const Key('onboarding-skip'),
                                      onPressed: busy ? null : onSkip,
                                      child: Text(
                                        _copy(context, 'Skip'),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                            final next = FocusTraversalOrder(
                              order: const NumericFocusOrder(4),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 52,
                                ),
                                child: FilledButton(
                                  key: const Key('onboarding-next'),
                                  onPressed: busy || !nextEnabled
                                      ? null
                                      : onNext,
                                  child: busy
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          nextLabel ??
                                              _copy(context, 'Continue'),
                                          textAlign: TextAlign.center,
                                        ),
                                ),
                              ),
                            );
                            if (stackActions) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      back,
                                      if (skip != null) ...[
                                        const SizedBox(width: 8),
                                        Expanded(child: skip),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  next,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                back,
                                if (skip != null) ...[
                                  const SizedBox(width: 8),
                                  skip,
                                ],
                                const SizedBox(width: 12),
                                Expanded(child: next),
                              ],
                            );
                          },
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
    );
  }
}

/// Responsive, decorative photo slot for approved BIL-owned onboarding
/// photography. It is intentionally absent from semantics: every instruction
/// remains available as real text, and the crop never controls page height.
class ModernOnboardingPhotoHero extends StatelessWidget {
  const ModernOnboardingPhotoHero({
    super.key,
    required this.image,
    this.alignment = Alignment.center,
    this.height = 176,
  });

  final ImageProvider image;
  final AlignmentGeometry alignment;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(1);
    final compactHeight = media.size.height < 650;
    final resolvedHeight = scale >= 1.8
        ? 84.0
        : scale >= 1.4 || compactHeight
        ? 104.0
        : height;
    return ExcludeSemantics(
      child: SizedBox(
        height: resolvedHeight,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: image,
                fit: BoxFit.cover,
                alignment: alignment,
                filterQuality: FilterQuality.medium,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      scheme.primary.withValues(alpha: .02),
                      scheme.primary.withValues(alpha: .20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({
    required this.step,
    required this.total,
    required this.reducedMotion,
  });

  final int step;
  final int total;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('onboarding-progress-semantics'),
      label: _copy(context, 'Setup progress'),
      value: '${step + 1} / $total',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var index = 0; index < total; index++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  height: 4,
                  decoration: BoxDecoration(
                    color: index <= step
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (index != total - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class OnboardingChoiceCard extends StatelessWidget {
  const OnboardingChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon case final icon?) ...[
                  Icon(
                    icon,
                    color: enabled
                        ? (selected ? scheme.primary : scheme.onSurfaceVariant)
                        : scheme.outline,
                  ),
                  const SizedBox(width: 13),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: enabled
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (subtitle case final subtitle?) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? scheme.primary : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingStatusCard extends StatelessWidget {
  const OnboardingStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.actionLabel,
    this.status,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? action;
  final String? actionLabel;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (status case final status?) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      status,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: action, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
