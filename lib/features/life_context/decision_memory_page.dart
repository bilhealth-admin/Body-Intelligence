import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_localizations.dart';
import '../profile/providers/user_profile_provider.dart';
import 'providers/life_context_provider.dart';

class DecisionMemoryPage extends ConsumerWidget {
  const DecisionMemoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.strings.text;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final enabled = ref.watch(decisionMemoryEnabledProvider).value ?? true;
    final memories = ref.watch(decisionMemoriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t('Decision Memory'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: enabled,
            onChanged: (value) => ref
                .read(preferencesRepositoryProvider)
                .set('decisionMemoryEnabled', value.toString()),
            title: Text(t('Remember recommendation responses')),
            subtitle: Text(
              t(
                'When off, BIL does not store new action responses or outcomes. Existing memories remain available for deletion.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          memories.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (rows) {
              if (rows.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      t(
                        'No recommendation responses have been stored. BIL will never invent outcomes.',
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: rows.map((row) {
                  final evidence =
                      (jsonDecode(row.evidenceJson) as List<dynamic>)
                          .map((item) => item.toString())
                          .toList();
                  return Card(
                    child: ExpansionTile(
                      title: Text(arabic ? _arabicTitle(row.title) : row.title),
                      subtitle: Text('${row.dayKey} · ${t(row.response)}'),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            arabic
                                ? '${_arabicReason(row.reason)}\nالدليل: ${evidence.map(_arabicEvidence).join(' · ')}'
                                : '${row.reason}\nEvidence: ${evidence.join(' · ')}',
                          ),
                        ),
                        if (row.outcome != null)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text('${t('Outcome')}: ${row.outcome}'),
                          ),
                        if (row.helpfulness == null)
                          Wrap(
                            spacing: 4,
                            children: [
                              Text(t('Helpful?')),
                              for (var rating = 1; rating <= 5; rating++)
                                IconButton(
                                  tooltip: '$rating ${t('of 5')}',
                                  onPressed: () => ref
                                      .read(decisionMemoryRepositoryProvider)
                                      .evaluate(
                                        id: row.id,
                                        helpfulness: rating,
                                      ),
                                  icon: const Icon(Icons.star_border),
                                ),
                            ],
                          )
                        else
                          Text('${t('Helpfulness')}: ${row.helpfulness}/5'),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: () => ref
                                .read(decisionMemoryRepositoryProvider)
                                .delete(row.id),
                            icon: const Icon(Icons.delete_outline),
                            label: Text(t('Delete memory')),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _arabicTitle(String value) {
    if (value.startsWith('Add about')) return 'أضف مصدر بروتين مناسبًا';
    if (value.startsWith('Drink')) return 'اشرب الماء تدريجيًا';
    return switch (value) {
      'Log today’s weight' => 'سجّل وزن اليوم',
      'Complete one missing meal' => 'أكمل وجبة ناقصة',
      'Keep the plan unchanged today' => 'حافظ على الخطة دون تغيير اليوم',
      'No plan change needed' => 'لا حاجة لتغيير الخطة',
      _ => 'إجراء BIL محفوظ',
    };
  }

  static String _arabicReason(String value) => switch (value) {
    'A comparable daily check-in improves trend confidence.' =>
      'القياس اليومي المتقارب يحسن ثقة الاتجاه.',
    'An incomplete day can make intake-based explanations weaker.' =>
      'اليوم غير المكتمل يضعف التفسيرات المعتمدة على المدخول.',
    'Protein is the largest actionable gap in today’s logged plan.' =>
      'البروتين هو أكبر فجوة قابلة للتنفيذ في خطة اليوم المسجلة.',
    'Recorded hydration remains meaningfully below target.' =>
      'الترطيب المسجل ما زال أقل بوضوح من الهدف.',
    'More consistent observations are safer than reacting early.' =>
      'الملاحظات الأكثر اتساقًا أكثر أمانًا من الاستجابة المبكرة.',
    'Today’s recorded priorities are broadly covered.' =>
      'الأولويات المسجلة اليوم مغطاة بصورة عامة.',
    _ => 'تم حفظ سبب هذا الإجراء مع السجل المحلي.',
  };

  static String _arabicEvidence(String value) {
    if (value.contains('weight check-in')) return 'لا يوجد قياس وزن اليوم';
    if (value.contains('meal record')) return 'قد يكون سجل وجبات اليوم ناقصًا';
    if (value.contains('target')) {
      return 'الهدف المحفوظ: ${value.split(' ').first}';
    }
    if (value.contains('logged') || value.contains('recorded')) {
      return 'القيمة المسجلة: ${value.split(' ').first}';
    }
    if (value.contains('14')) return 'أقل من 14 يومًا متقاربًا';
    return 'سجل محلي متاح';
  }
}
