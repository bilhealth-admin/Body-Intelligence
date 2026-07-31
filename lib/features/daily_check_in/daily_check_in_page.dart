import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/units/measurement_units.dart';
import '../../data/database/date_keys.dart';
import '../../shared/widgets/wheel_number_field.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';

class DailyCheckInPage extends ConsumerStatefulWidget {
  const DailyCheckInPage({super.key});

  @override
  ConsumerState<DailyCheckInPage> createState() => _DailyCheckInPageState();
}

class _DailyCheckInPageState extends ConsumerState<DailyCheckInPage> {
  double? weightKg;
  String measurementContext = 'morning';
  bool initialized = false;
  bool saving = false;

  bool get arabic => Localizations.localeOf(context).languageCode == 'ar';
  String tr(String en, String ar) => arabic ? ar : en;

  Future<void> save() async {
    final value = weightKg;
    if (value == null || saving) return;
    setState(() => saving = true);
    await ref
        .read(weightRepositoryProvider)
        .addWeight(value, measurementContext: measurementContext);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'Check-in saved. Consistent conditions make your trend clearer.',
            'تم حفظ القياس. ثبات ظروف القياس يجعل اتجاهك أوضح.',
          ),
        ),
      ),
    );
    context.go('/dashboard');
  }

  Future<void> skipToday() async {
    await ref
        .read(preferencesRepositoryProvider)
        .set('weightReminderSkippedDay', dayKeyFor(DateTime.now()));
    if (mounted) context.go('/dashboard');
  }

  Future<void> deleteToday(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("Delete today's weight?", 'حذف وزن اليوم؟')),
        content: Text(
          tr(
            'This removes today’s check-in from trend calculations.',
            'سيؤدي ذلك إلى إزالة قياس اليوم من حسابات الاتجاه.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Delete', 'حذف')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(weightRepositoryProvider).deleteWeight(id);
      if (mounted) setState(() => initialized = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayWeightProvider);
    final profile = ref.watch(userProfileProvider).value;
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    final existing = today.value;
    if (!initialized && !today.isLoading) {
      initialized = true;
      weightKg = existing?.weight ?? profile?.currentWeight ?? 60;
      measurementContext = existing?.measurementContext ?? 'morning';
    }
    final canonical = weightKg ?? profile?.currentWeight ?? 60;
    final display = UnitConverter.weightFromKg(canonical, system);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Daily check-in', 'القياس اليومي')),
        leading: IconButton(
          tooltip: tr('Not now', 'ليس الآن'),
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: today.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.monitor_weight_outlined,
                          size: 44,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr(
                            'Did you weigh yourself today?',
                            'هل قست وزنك اليوم؟',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(
                            'One check-in per day improves goal tracking, trend smoothing, Body Twin evidence, and interpretation confidence.',
                            'قياس واحد يوميًا يحسن متابعة الهدف وتنعيم الاتجاه وأدلة توأم الجسم وثقة التفسير.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        WheelNumberField(
                          key: ValueKey(system),
                          value: display,
                          minimum: UnitConverter.weightFromKg(20, system),
                          maximum: UnitConverter.weightFromKg(350, system),
                          step: UnitConverter.weightStep(system),
                          decimalPlaces: 1,
                          unit: UnitConverter.weightUnit(system),
                          label: tr("Today's weight", 'وزن اليوم'),
                          onChanged: (value) => setState(
                            () => weightKg = UnitConverter.weightToKg(
                              value,
                              system,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: measurementContext,
                          decoration: InputDecoration(
                            labelText: tr(
                              'Measurement conditions',
                              'ظروف القياس',
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'morning',
                              child: Text(tr('Morning', 'صباحًا')),
                            ),
                            DropdownMenuItem(
                              value: 'afterBathroom',
                              child: Text(
                                tr('After using the bathroom', 'بعد الحمام'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'beforeFoodDrink',
                              child: Text(
                                tr(
                                  'Before food or drink',
                                  'قبل الطعام أو الشراب',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'differentConditions',
                              child: Text(
                                tr('Different conditions', 'ظروف مختلفة'),
                              ),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => measurementContext = value ?? 'morning',
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: saving ? null : save,
                          icon: saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            existing == null
                                ? tr('Save check-in', 'حفظ القياس')
                                : tr(
                                    "Update today's weight",
                                    'تحديث وزن اليوم',
                                  ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/dashboard'),
                          child: Text(tr('Not now', 'ليس الآن')),
                        ),
                        TextButton(
                          onPressed: skipToday,
                          child: Text(
                            tr(
                              "Don't remind me again today",
                              'لا تذكرني مرة أخرى اليوم',
                            ),
                          ),
                        ),
                        if (existing != null)
                          TextButton.icon(
                            onPressed: () => deleteToday(existing.id),
                            icon: const Icon(Icons.delete_outline),
                            label: Text(
                              tr("Delete today's weight", 'حذف وزن اليوم'),
                            ),
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
