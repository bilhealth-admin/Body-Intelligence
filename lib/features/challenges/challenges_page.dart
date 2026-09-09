import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/theme/bil_semantic_icons.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../data/repositories/challenge_repository.dart';
import '../../data/repositories/meal_repository.dart';
import '../../engine/challenge_engine.dart';
import '../../shared/widgets/secondary_page_app_bar.dart';

final challengeRepositoryProvider = Provider(
  (ref) => ChallengeRepository(ref.watch(databaseProvider)),
);
final challengesProvider = StreamProvider(
  (ref) => ref.watch(challengeRepositoryProvider).watchAll(),
);
final challengeProgressProvider =
    FutureProvider.family<ChallengeProgress, Challenge>((ref, challenge) async {
      final database = ref.watch(databaseProvider);
      final meals = await MealRepository(database).watchAll().first;
      final weights = await (database.select(
        database.weightEntries,
      )..where((row) => row.deletedAt.isNull())).get();
      final water = await database.select(database.waterEntries).get();
      final plan = await database
          .select(database.planSettings)
          .getSingleOrNull();
      String key(DateTime value) =>
          '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
      final today = DateTime.now();
      final end = challenge.endsAt.isBefore(today) ? challenge.endsAt : today;
      final days = <ChallengeDayEvidence>[];
      for (
        var day = DateTime(
          challenge.startedAt.year,
          challenge.startedAt.month,
          challenge.startedAt.day,
        );
        !day.isAfter(DateTime(end.year, end.month, end.day));
        day = day.add(const Duration(days: 1))
      ) {
        final dayMeals = meals.where((meal) => key(meal.meal.date) == key(day));
        final items = dayMeals.expand((meal) => meal.items);
        days.add(
          ChallengeDayEvidence(
            hasMeal: items.isNotEmpty,
            hasWeight: weights.any((entry) => key(entry.date) == key(day)),
            protein: items.fold(0, (sum, item) => sum + item.protein),
            fiber: items.fold(0, (sum, item) => sum + item.fiber),
            waterMl: water
                .where((entry) => key(entry.occurredAt) == key(day))
                .fold(0, (sum, entry) => sum + entry.amountMl),
          ),
        );
      }
      return ChallengeEngine.calculate(
        type: challenge.type,
        targetDays: challenge.targetDays,
        days: days,
        proteinTarget: plan?.overrideProtein ?? plan?.recommendedProtein ?? 100,
        fiberTarget: plan?.overrideFiber ?? plan?.recommendedFiber ?? 30,
        waterTarget: plan?.overrideWater ?? plan?.recommendedWater ?? 2500,
      );
    });

class ChallengesPage extends ConsumerWidget {
  const ChallengesPage({super.key});

  static const presets = <(String, String, int)>[
    ('protein', '7 days of protein support', 7),
    ('water', '14 days of hydration', 14),
    ('consistentLogging', '7 days of consistent logging', 7),
    ('fiber', '7 fiber-supporting days', 7),
    ('return', '3-day fresh return', 3),
    ('weightCheckIn', '7 daily weight check-ins', 7),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(challengesProvider);
    final t = context.strings.text;
    return Scaffold(
      appBar: SecondaryPageAppBar(title: Text(t('Challenges'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _choose(context, ref),
        icon: const Icon(Icons.add),
        label: Text(t('Start challenge')),
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(t('Could not load challenges. Try again.'))),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t(
                    'BIL challenges reward supportive behavior—not starvation, extreme deficits, or fastest weight loss.',
                  ),
                ),
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t(
                    'No challenge yet. Choose a private challenge that works offline.',
                  ),
                ),
              ),
            for (final challenge in items) _ChallengeTile(challenge: challenge),
            const SizedBox(height: 16),
            _SharedChallengesUnavailableCard(
              title: t('Shared challenges'),
              audiences: [
                for (final audience in const [
                  'Friends',
                  'Community',
                  'Coach-created',
                  'Team',
                ])
                  _audienceLabel(context, audience),
              ],
              reason: t(
                'Requires authenticated identity, a secure sharing service, and explicit consent.',
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  static String _audienceLabel(BuildContext context, String value) {
    final code = Localizations.localeOf(context).languageCode;
    const labels = <String, Map<String, String>>{
      'Friends': {
        'ar': 'الأصدقاء',
        'fr': 'Amis',
        'es': 'Amigos',
        'tr': 'Arkadaşlar',
      },
      'Community': {
        'ar': 'المجتمع',
        'fr': 'Communauté',
        'es': 'Comunidad',
        'tr': 'Topluluk',
      },
      'Coach-created': {
        'ar': 'بإشراف مدرب',
        'fr': 'Créés par un coach',
        'es': 'Creados por un entrenador',
        'tr': 'Antrenör tarafından',
      },
      'Team': {'ar': 'الفريق', 'fr': 'Équipe', 'es': 'Equipo', 'tr': 'Takım'},
    };
    return labels[value]?[code] ?? value;
  }

  // ignore: unused_element
  static String _audienceArabic(String value) => switch (value) {
    'Friends' => 'الأصدقاء',
    'Community' => 'المجتمع',
    'Coach-created' => 'بإشراف مختص',
    _ => 'الفريق',
  };

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final t = context.strings.text;
    final selected = await showModalBottomSheet<(String, String, int)>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(t('Choose a private challenge'))),
          for (final preset in presets)
            ListTile(
              leading: BilSemanticIconBadge(kind: _challengeKind(preset.$1)),
              title: Text(t(preset.$2)),
              subtitle: Text(
                '${preset.$3} ${t('days · private on this device')}',
              ),
              onTap: () => Navigator.pop(context, preset),
            ),
        ],
      ),
    );
    if (selected == null) return;
    await ref
        .read(challengeRepositoryProvider)
        .start(type: selected.$1, title: selected.$2, targetDays: selected.$3);
  }

  static BilSemanticIconKind _challengeKind(String type) => switch (type) {
    'water' => BilSemanticIconKind.water,
    'weightCheckIn' => BilSemanticIconKind.weight,
    'protein' || 'fiber' => BilSemanticIconKind.nutrition,
    'consistentLogging' => BilSemanticIconKind.notes,
    _ => BilSemanticIconKind.challenges,
  };

  // ignore: unused_element
  static String _presetArabic(String type) => switch (type) {
    'protein' => '7 أيام داعمة للبروتين',
    'water' => '14 يومًا للترطيب',
    'consistentLogging' => '7 أيام من التسجيل المنتظم',
    'fiber' => '7 أيام داعمة للألياف',
    'return' => 'عودة جديدة لمدة 3 أيام',
    _ => '7 قياسات وزن يومية',
  };
}

class _SharedChallengesUnavailableCard extends StatelessWidget {
  const _SharedChallengesUnavailableCard({
    required this.title,
    required this.audiences,
    required this.reason,
  });

  final String title;
  final List<String> audiences;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('shared-challenges-unavailable'),
      container: true,
      label: '$title. ${audiences.join(', ')}. $reason',
      child: Card(
        margin: const EdgeInsets.only(top: 10),
        color: colors.surfaceContainerLow,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lock_clock_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(reason),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final audience in audiences)
                      Chip(
                        avatar: const Icon(Icons.people_outline, size: 16),
                        label: Text(audience),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeTile extends ConsumerWidget {
  const _ChallengeTile({required this.challenge});
  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(challengeProgressProvider(challenge));
    final t = context.strings.text;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: progress.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) =>
              Text(t('Could not calculate challenge progress.')),
          data: (value) {
            if (value.complete && challenge.status != 'completed') {
              Future.microtask(
                () => ref
                    .read(challengeRepositoryProvider)
                    .markComplete(challenge.id),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    value.complete ? Icons.emoji_events : Icons.flag_outlined,
                  ),
                  title: Text(t(challenge.title)),
                  subtitle: Text(
                    '${value.qualifyingDays} ${t('of')} ${value.targetDays} ${t('qualifying days')}',
                  ),
                  trailing: IconButton(
                    tooltip: t('Delete'),
                    onPressed: () => ref
                        .read(challengeRepositoryProvider)
                        .delete(challenge.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
                LinearProgressIndicator(value: value.fraction),
                const SizedBox(height: 6),
                Text(
                  t('Progress is calculated only from actual local records.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
