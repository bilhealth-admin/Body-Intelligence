import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/life_context_repository.dart';
import '../../shared/widgets/secondary_page_app_bar.dart';
import 'providers/life_context_provider.dart';

class LifeContextPage extends ConsumerWidget {
  const LifeContextPage({super.key});

  bool isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';
  String tr(BuildContext context, String en, String ar) =>
      isArabic(context) ? ar : en;

  Future<void> addContext(BuildContext context, WidgetRef ref) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: LifeContextRepository.allowedTypes
              .map(
                (value) => ListTile(
                  leading: Icon(_icon(value)),
                  title: Text(_label(context, value)),
                  onTap: () => Navigator.pop(context, value),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (type == null || !context.mounted) return;
    final details = TextEditingController();
    var consent = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(_label(context, type)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: details,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: tr(
                    context,
                    'Optional context — avoid sensitive detail you do not want stored',
                    'سياق اختياري — تجنب التفاصيل الحساسة التي لا تريد حفظها',
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: consent,
                onChanged: (value) => setState(() => consent = value),
                title: Text(
                  tr(
                    context,
                    'Allow BIL to use this item as interpretation evidence',
                    'السماح لـ BIL باستخدام هذا العنصر كدليل في التفسير',
                  ),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Correlation is not treated as causation.',
                    'لا يتم اعتبار الارتباط سببًا مؤكدًا.',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr(context, 'Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr(context, 'Save', 'حفظ')),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await ref
          .read(lifeContextRepositoryProvider)
          .add(
            occurredAt: DateTime.now(),
            type: type,
            details: details.text,
            useInInsights: consent,
          );
    }
    details.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(todayLifeContextProvider);
    return Scaffold(
      appBar: SecondaryPageAppBar(
        title: Text(tr(context, 'Life context', 'سياق الحياة')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addContext(context, ref),
        icon: const Icon(Icons.add),
        label: Text(tr(context, 'Add context', 'إضافة سياق')),
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (rows) => rows.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr(
                      context,
                      'No context is required. Add something only when it may help explain today’s body changes.',
                      'لا يلزم إضافة سياق. أضف شيئًا فقط عندما قد يساعد في تفسير تغيرات جسمك اليوم.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(_icon(row.type)),
                      title: Text(_label(context, row.type)),
                      subtitle: Text(
                        [
                          if (row.details != null) row.details!,
                          row.useInInsights
                              ? tr(
                                  context,
                                  'Used with consent',
                                  'يُستخدم بموافقتك',
                                )
                              : tr(
                                  context,
                                  'Excluded from insights',
                                  'مستبعد من الرؤى',
                                ),
                        ].join('\n'),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          final repository = ref.read(
                            lifeContextRepositoryProvider,
                          );
                          if (value == 'toggle') {
                            await repository.setInsightConsent(
                              row.id,
                              !row.useInInsights,
                            );
                          } else if (value == 'delete') {
                            await repository.delete(row.id);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              row.useInInsights
                                  ? tr(
                                      context,
                                      'Exclude from insights',
                                      'استبعاد من الرؤى',
                                    )
                                  : tr(
                                      context,
                                      'Allow in insights',
                                      'السماح في الرؤى',
                                    ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(tr(context, 'Delete', 'حذف')),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  static IconData _icon(String type) => switch (type) {
    'travel' => Icons.flight_outlined,
    'poorSleep' => Icons.bedtime_outlined,
    'stress' => Icons.psychology_outlined,
    'fasting' || 'ramadan' => Icons.nights_stay_outlined,
    'illness' || 'medicationChange' => Icons.health_and_safety_outlined,
    'highSodiumMeal' => Icons.restaurant_outlined,
    _ => Icons.event_note_outlined,
  };

  String _label(BuildContext context, String type) {
    const en = {
      'travel': 'Travel',
      'illness': 'Illness',
      'medicationChange': 'Medication change',
      'menstrualContext': 'Menstrual context',
      'stress': 'Stress',
      'event': 'Event',
      'poorSleep': 'Poor sleep',
      'stoppedTraining': 'Stopped training',
      'fasting': 'Fasting',
      'ramadan': 'Ramadan',
      'highSodiumMeal': 'High-sodium meal',
      'other': 'Other',
    };
    const ar = {
      'travel': 'سفر',
      'illness': 'مرض',
      'medicationChange': 'تغيير دواء',
      'menstrualContext': 'سياق الدورة الشهرية',
      'stress': 'ضغط نفسي',
      'event': 'حدث',
      'poorSleep': 'نوم سيئ',
      'stoppedTraining': 'توقف التدريب',
      'fasting': 'صيام',
      'ramadan': 'رمضان',
      'highSodiumMeal': 'وجبة عالية الصوديوم',
      'other': 'أخرى',
    };
    return isArabic(context) ? (ar[type] ?? type) : (en[type] ?? type);
  }
}
