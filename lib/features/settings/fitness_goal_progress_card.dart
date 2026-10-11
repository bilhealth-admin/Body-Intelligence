import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/app_localizations.dart';
import '../../data/database/database_provider.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../profile/providers/user_profile_provider.dart';
import '../nutrition/providers/nutrition_goal_defaults_provider.dart';

final fitnessWeeklyMinutesProvider =
    StreamProvider<({int sessions, int minutes})>((ref) async* {
      final repository = DailyLogRepository(ref.watch(databaseProvider));
      await for (final rows in repository.watchAll()) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final start = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );
        var minutes = 0, sessions = 0;
        final seen = <String>{};
        for (final row in rows) {
          final day = DateTime(row.date.year, row.date.month, row.date.day);
          if (day.isBefore(start) || day.isAfter(today)) continue;
          for (final line in const LineSplitter().convert(
            row.exerciseNotes ?? '',
          )) {
            try {
              final entry = jsonDecode(line);
              if (entry is! Map ||
                  entry['id'] is! String ||
                  entry['name'] is! String ||
                  entry['minutes'] is! int) {
                continue;
              }
              final amount = entry['minutes'] as int;
              final recorded = DateTime.tryParse('${entry['recordedAt']}');
              if (amount < 5 ||
                  amount > 120 ||
                  recorded == null ||
                  recorded.isAfter(now)) {
                continue;
              }
              if (!seen.add('${row.dayKey}:${entry['id']}:$recorded')) continue;
              sessions++;
              minutes += amount;
            } on Object {
              /* Text notes are not evidence of a completed workout. */
            }
          }
        }
        yield (sessions: sessions, minutes: minutes);
      }
    });

final fitnessWeeklyTargetProvider =
    StreamProvider<({int sessions, int minutes})>((ref) {
      return ref
          .watch(preferencesRepositoryProvider)
          .watchSnapshot(['goals.workoutsPerWeek', 'goals.minutesPerWorkout'])
          .map((values) {
            final sessions =
                (int.tryParse(values['goals.workoutsPerWeek'] ?? '') ?? 0)
                    .clamp(0, 14);
            final perWorkout =
                (int.tryParse(values['goals.minutesPerWorkout'] ?? '') ?? 0)
                    .clamp(0, 300);
            return (sessions: sessions, minutes: sessions * perWorkout);
          });
    });

class FitnessGoalProgressCard extends ConsumerWidget {
  const FitnessGoalProgressCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String arabic) =>
        ar ? arabic : context.strings.text(en);
    final progress = ref.watch(fitnessWeeklyMinutesProvider);
    final target = ref.watch(fitnessWeeklyTargetProvider).value;
    final defaults = ref.watch(nutritionGoalDefaultsProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Your recorded activity this week', 'نشاطك المسجل هذا الأسبوع'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          progress.when(
            loading: () => Text(
              tr('Reading your activity log…', 'جارٍ قراءة سجل النشاط…'),
            ),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(fitnessWeeklyMinutesProvider),
              child: Text(
                tr('Retry activity summary', 'إعادة تحميل ملخص النشاط'),
              ),
            ),
            data: (value) => Text(
              ar
                  ? '${value.sessions} جلسة / ${target?.sessions ?? 0} • ${value.minutes} دقيقة / ${target?.minutes ?? 0} خلال الأسبوع من الاثنين إلى الأحد'
                  : '${value.sessions} / ${target?.sessions ?? 0} sessions • ${value.minutes} / ${target?.minutes ?? 0} minutes (Monday–Sunday)',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Weekly goals track recorded sessions and minutes; they do not create burned calories. Activity level sets the baseline recommendation. Your manual nutrition overrides stay unchanged until reset.',
              'الأهداف الأسبوعية تتابع الجلسات والدقائق المسجلة، ولا تُنشئ سعرات محروقة. مستوى النشاط يدخل في اقتراح السعرات الأساسي. تبقى أهداف التغذية اليدوية كما حددتها حتى تعيدها إلى الاقتراح.',
            ),
          ),
          if (defaults['goal.calories'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                ar
                    ? 'المرجع الحالي: ${defaults['goal.calories']!.round()} سعرة؛ بروتين ${defaults['goal.proteinGrams']?.toStringAsFixed(1)} جم، كربوهيدرات ${defaults['goal.carbsGrams']?.toStringAsFixed(1)} جم، دهون ${defaults['goal.fatGrams']?.toStringAsFixed(1)} جم.'
                    : 'Current reference: ${defaults['goal.calories']!.round()} kcal; P ${defaults['goal.proteinGrams']?.toStringAsFixed(1)} g, C ${defaults['goal.carbsGrams']?.toStringAsFixed(1)} g, F ${defaults['goal.fatGrams']?.toStringAsFixed(1)} g.',
              ),
            ),
          Text(
            tr(
              'Exercise calorie controls can add verified active energy, using the existing overlap protection. Planned minutes are never converted into a claimed calorie burn.',
              'يمكن لإعداد سعرات التمرين إضافة الطاقة النشطة الموثقة وفق سياسة منع الاحتساب المتكرر. لا تتحول الدقائق المخططة إلى حرق مزعوم.',
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => context.push('/wellness/workouts/log'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('Log an exercise', 'سجّل تمرينًا')),
              ),
              IconButton(
                onPressed: () => context.push(
                  '/health-information-sources?topic=nutrition-targets',
                ),
                tooltip: tr('Sources and calculation', 'المصادر وطريقة الحساب'),
                icon: const Icon(Icons.menu_book_outlined, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
