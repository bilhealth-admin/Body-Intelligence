import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../shared/widgets/bil_wordmark.dart';

/// The exercise decision step shown before manual logging or guided routines.
///
/// Cardio and strength lead to the measured manual logger. Guided routines
/// remain a separate, verified-content path so the app never implies that a
/// catalog item or its media was logged merely by opening it.
class WorkoutEntryChooserPage extends StatelessWidget {
  const WorkoutEntryChooserPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    void close() => context.canPop() ? context.pop() : context.go('/dashboard');

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('exercise-chooser-barrier'),
              behavior: HitTestBehavior.opaque,
              onTap: close,
              child: ColoredBox(color: colors.scrim.withValues(alpha: .48)),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 410),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: .96),
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: .55),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: .24),
                            blurRadius: 42,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: BilWordmark(
                                      height: 30,
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: const ValueKey('exercise-chooser-close'),
                                  tooltip: MaterialLocalizations.of(
                                    context,
                                  ).closeButtonTooltip,
                                  onPressed: close,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.text('Add exercise'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.text(
                                'Choose how you want to log today\'s movement.',
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 22),
                            _ExercisePathCard(
                              key: const ValueKey('exercise-path-cardio'),
                              icon: Icons.directions_run_rounded,
                              title: strings.text('Cardio'),
                              description: strings.text(
                                'Log cardio activity and the duration you confirm.',
                              ),
                              onTap: () => context.pushReplacement(
                                '/wellness/workouts/log?category=Cardio',
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ExercisePathCard(
                              key: const ValueKey('exercise-path-strength'),
                              icon: Icons.fitness_center_rounded,
                              title: strings.text('Strength'),
                              description: strings.text(
                                'Log resistance activity without estimating calorie burn.',
                              ),
                              onTap: () => context.pushReplacement(
                                '/wellness/workouts/log?category=Strength',
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ExercisePathCard(
                              key: const ValueKey('exercise-path-routines'),
                              icon: Icons.video_library_rounded,
                              title: strings.text('Workout Routines'),
                              description: strings.text(
                                "Choose how you want to log today's movement.",
                              ),
                              onTap: () => context.pushReplacement(
                                '/wellness/workouts/routines',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExercisePathCard extends StatelessWidget {
  const _ExercisePathCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$title. $description',
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 78,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: colors.primary, size: 25),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
