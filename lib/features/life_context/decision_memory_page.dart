import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/secondary_page_app_bar.dart';

import '../../app/localization/app_localizations.dart';
import '../profile/providers/user_profile_provider.dart';
import '../intelligence_center/services/coach_memory_repository.dart';
import '../intelligence_center/services/coach_context_provider.dart';
import 'providers/life_context_provider.dart';

final explicitCoachMemoriesProvider = FutureProvider((ref) {
  return CoachMemoryRepository(
    preferences: ref.watch(preferencesRepositoryProvider),
  ).readLocal();
});

class DecisionMemoryPage extends ConsumerWidget {
  const DecisionMemoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.strings.text;
    final enabled = ref.watch(decisionMemoryEnabledProvider).value ?? true;
    final memories = ref.watch(decisionMemoriesProvider);
    final explicit = ref.watch(explicitCoachMemoriesProvider);
    return Scaffold(
      appBar: SecondaryPageAppBar(title: Text(t('What BIL knows about me'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_alt_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t('Your living BIL memory'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'Confirmed facts are yours to review or remove. Inferred patterns stay separate from facts, and experiment results keep their limitations.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t('Confirmed by you'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          explicit.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(t('Could not load Coach memories.')),
            data: (rows) => rows.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        t(
                          'Nothing is assumed. Tell BIL “remember…” and confirm before it is saved.',
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: rows
                        .map(
                          (row) => Card(
                            child: ListTile(
                              leading: Icon(_memoryKindIcon(row['kind'])),
                              title: Text(row['text']?.toString() ?? ''),
                              subtitle: Text(
                                '${t(_memoryKindLabel(row['kind']))} · ${t('Confirmed')}',
                              ),
                              trailing: IconButton(
                                tooltip: t('Forget this'),
                                onPressed: () async {
                                  await CoachMemoryRepository(
                                    preferences: ref.read(
                                      preferencesRepositoryProvider,
                                    ),
                                  ).delete(row['id']?.toString() ?? '');
                                  ref.invalidate(explicitCoachMemoriesProvider);
                                  ref.invalidate(coachContextSnapshotProvider);
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => context.push('/experiments'),
            icon: const Icon(Icons.science_outlined),
            label: Text(t('Open personal experiments')),
          ),
          const SizedBox(height: 18),
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
          Text(
            t('Recommendation history'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          memories.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Text(t('Could not load decision memories. Try again.')),
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
                children: [
                  if (rows.any((row) => (row.helpfulness ?? 5) <= 2))
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: () => _confirmForgetUnhelpful(context, ref),
                        icon: const Icon(Icons.auto_delete_outlined),
                        label: Text(t('Forget unhelpful memories')),
                      ),
                    ),
                  ...rows.map((row) {
                    final evidence =
                        (jsonDecode(row.evidenceJson) as List<dynamic>)
                            .map((item) => item.toString())
                            .toList();
                    return Card(
                      child: ExpansionTile(
                        title: Text(t(row.title)),
                        subtitle: Text('${row.dayKey} · ${t(row.response)}'),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              '${t(row.reason)}\n${t('Evidence')}: ${evidence.map(t).join(' · ')}',
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
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static IconData _memoryKindIcon(Object? raw) => switch (raw?.toString()) {
    'preference' => Icons.favorite_outline_rounded,
    'constraint' => Icons.block_outlined,
    'goal' => Icons.flag_outlined,
    'routine' => Icons.schedule_outlined,
    _ => Icons.bookmark_outline_rounded,
  };

  static String _memoryKindLabel(Object? raw) => switch (raw?.toString()) {
    'preference' => 'Preference',
    'constraint' => 'Constraint',
    'goal' => 'Goal',
    'routine' => 'Routine',
    _ => 'Personal fact',
  };

  Future<void> _confirmForgetUnhelpful(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.text('Forget memories?')),
        content: Text(
          context.strings.text(
            'Only memories you rated two stars or less will be deleted. Nothing is deleted automatically.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings.text('Forget')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(decisionMemoryRepositoryProvider).forgetUnhelpful();
    }
  }

  // ignore: unused_element
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

  // ignore: unused_element
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

  // ignore: unused_element
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
