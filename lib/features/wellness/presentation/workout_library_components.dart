part of 'wellness_tools_pages.dart';

final class _WorkoutHistoryEntry {
  const _WorkoutHistoryEntry({
    required this.id,
    required this.name,
    required this.minutes,
    required this.date,
  });

  final String id, name;
  final int minutes;
  final DateTime date;
}

class _WorkoutDiscoveryHero extends StatelessWidget {
  const _WorkoutDiscoveryHero({
    required this.onStrength,
    required this.onMobility,
  });

  final VoidCallback onStrength;
  final VoidCallback onMobility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            wellnessCopy(
              context,
              'Featured workouts',
              '\u062a\u0645\u0627\u0631\u064a\u0646 \u0645\u0645\u064a\u0632\u0629',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 196,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _WorkoutFeatureCard(
                  image: StaticWorkoutArtwork.strength,
                  title: wellnessCopy(
                    context,
                    'Full-body strength',
                    '\u0642\u0648\u0629 \u0644\u0643\u0627\u0645\u0644 \u0627\u0644\u062c\u0633\u0645',
                  ),
                  detail: wellnessCopy(
                    context,
                    '20 min \u2022 Full body',
                    '20 \u062f\u0642\u064a\u0642\u0629 \u2022 \u0643\u0627\u0645\u0644 \u0627\u0644\u062c\u0633\u0645',
                  ),
                  onTap: onStrength,
                ),
                const SizedBox(width: 12),
                _WorkoutFeatureCard(
                  image: StaticWorkoutArtwork.mobility,
                  title: wellnessCopy(
                    context,
                    'Mobility flow',
                    '\u062d\u0631\u0643\u0629 \u0648\u0645\u0631\u0648\u0646\u0629',
                  ),
                  detail: wellnessCopy(
                    context,
                    '15 min \u2022 Recovery',
                    '15 \u062f\u0642\u064a\u0642\u0629 \u2022 \u062a\u0639\u0627\u0641\u064d',
                  ),
                  onTap: onMobility,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkoutFeatureCard extends StatelessWidget {
  const _WorkoutFeatureCard({
    required this.image,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final String image;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 244,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(image),
                fit: BoxFit.cover,
              ),
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x08000000), Color(0xE6000000)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: .86),
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

class _WorkoutLibraryTabs extends StatelessWidget {
  const _WorkoutLibraryTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = <(String, String)>[
      ('History', 'السجل'),
      ('My Exercises', 'تماريني'),
      ('All Exercises', 'كل التمارين'),
    ];
    return Row(
      children: [
        for (final entry in labels.indexed)
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == entry.$1,
              label: wellnessCopy(context, entry.$2.$1, entry.$2.$2),
              child: InkWell(
                onTap: () => onSelected(entry.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: selected == entry.$1 ? 3 : 1,
                        color: selected == entry.$1
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: Text(
                    wellnessCopy(context, entry.$2.$1, entry.$2.$2),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: selected == entry.$1
                          ? FontWeight.w800
                          : FontWeight.w500,
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

class _WorkoutEmptyState extends StatelessWidget {
  const _WorkoutEmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 48, 32, 20),
    child: Column(
      children: [
        Icon(
          Icons.fitness_center_rounded,
          size: 42,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}

class _WorkoutHistoryError extends StatelessWidget {
  const _WorkoutHistoryError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 44, 32, 20),
    child: Column(
      children: [
        const Icon(Icons.error_outline_rounded, size: 42),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(wellnessCopy(context, 'Retry', 'إعادة المحاولة')),
        ),
      ],
    ),
  );
}
