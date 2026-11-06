import '../../shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_expansion_indicator.dart';
import '../../shared/widgets/bil_pearl_material.dart';
import '../../shared/widgets/bil_navigation_feedback.dart';
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
import 'coach_memory_sync_review_panel.dart';

final explicitCoachMemoriesProvider = FutureProvider((ref) {
  return CoachMemoryRepository(
    preferences: ref.watch(preferencesRepositoryProvider),
  ).readLocal();
});

class DecisionMemoryPage extends ConsumerStatefulWidget {
  const DecisionMemoryPage({super.key});

  @override
  ConsumerState<DecisionMemoryPage> createState() => _DecisionMemoryPageState();
}

class _DecisionMemoryPageState extends ConsumerState<DecisionMemoryPage> {
  bool _writing = false;
  bool _confirming = false;

  Future<String?> _write(
    Future<void> Function() action, {
    bool reportFailure = true,
  }) async {
    if (!mounted) return 'Could not save changes.';
    if (_writing) return context.strings.text('Could not save changes.');
    setState(() => _writing = true);
    String? failure;
    try {
      await action();
    } on CoachMemoryVersionConflict {
      if (mounted) {
        failure = context.strings.text(
          'This memory changed after review. Refresh and select it again.',
        );
      }
    } on Object {
      if (mounted) failure = context.strings.text('Could not save changes.');
    } finally {
      if (mounted) setState(() => _writing = false);
    }
    if (failure != null && mounted && reportFailure) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure)));
    }
    return failure;
  }

  Future<void> _confirmMutation({
    required String title,
    required String message,
    required Future<void> Function() action,
  }) async {
    if (!mounted || _writing || _confirming) return;
    setState(() => _confirming = true);
    var saving = false;
    String? failure;
    ModalRoute<dynamic>? dialogRoute;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialog) {
          dialogRoute = ModalRoute.of(dialog);
          return StatefulBuilder(
            builder: (context, setDialogState) => PopScope(
              canPop: !saving,
              child: BilPearlMaterialAlertDialog(
                title: Text(title),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    if (failure != null)
                      Text(
                        failure!,
                        key: const Key('decision-memory-write-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    key: const Key('decision-memory-cancel'),
                    onPressed: saving ? null : () => Navigator.pop(dialog),
                    child: Text(context.strings.text('Cancel')),
                  ),
                  FilledButton(
                    key: const Key('decision-memory-confirm'),
                    onPressed: saving
                        ? null
                        : () async {
                            if (saving || _writing) return;
                            setDialogState(() {
                              saving = true;
                              failure = null;
                            });
                            final error = await _write(
                              action,
                              reportFailure: false,
                            );
                            final route = dialogRoute;
                            final navigator = route?.navigator;
                            if (!dialog.mounted ||
                                route == null ||
                                !route.isActive ||
                                navigator == null) {
                              return;
                            }
                            if (error == null) {
                              if (route.isCurrent) {
                                navigator.pop();
                              } else {
                                navigator.removeRoute(route);
                              }
                            } else {
                              setDialogState(() {
                                saving = false;
                                failure = error;
                              });
                            }
                          },
                    child: Text(
                      context.strings.text(saving ? 'Saving…' : 'Forget'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings.text;
    final enabled = ref.watch(decisionMemoryEnabledProvider).value ?? true;
    final memories = ref.watch(decisionMemoriesProvider);
    final explicit = ref.watch(explicitCoachMemoriesProvider);
    return Scaffold(
      appBar: SecondaryPageAppBar(title: Text(t('What BIL knows about me'))),
      body: AbsorbPointer(
        absorbing: _writing,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BilPearlMaterialCard(
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
            CoachMemorySyncReviewPanel(
              onChanged: () {
                ref.invalidate(explicitCoachMemoriesProvider);
                ref.invalidate(coachContextSnapshotProvider);
              },
            ),
            Text(
              t('Confirmed by you'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            explicit.when(
              loading: () => const BilFeatureWelcomeStatus(),
              error: (_, _) => Text(t('Could not load Coach memories.')),
              data: (rows) => rows.isEmpty
                  ? BilPearlMaterialCard(
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
                            (row) => BilPearlMaterialCard(
                              child: ListTile(
                                leading: BilNavigationFeedback(
                                  child: Icon(_memoryKindIcon(row['kind'])),
                                ),
                                title: Text(row['text']?.toString() ?? ''),
                                subtitle: Text(
                                  '${t(_memoryKindLabel(row['kind']))} · ${t('Confirmed')}',
                                ),
                                trailing: IconButton(
                                  tooltip: t('Forget this'),
                                  key: Key(
                                    'decision-memory-explicit-${row['id']}',
                                  ),
                                  onPressed: _writing || _confirming
                                      ? null
                                      : () => _confirmForgetExplicit(
                                          context,
                                          ref,
                                          row,
                                        ),
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
              key: const Key('decision-memory-enabled'),
              onChanged: _writing
                  ? null
                  : (value) => _write(
                      () => ref
                          .read(preferencesRepositoryProvider)
                          .set('decisionMemoryEnabled', value.toString()),
                    ),
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
              loading: () => const Center(child: BilFeatureWelcomeStatus()),
              error: (error, _) =>
                  Text(t('Could not load decision memories. Try again.')),
              data: (rows) {
                if (rows.isEmpty) {
                  return BilPearlMaterialCard(
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
                          key: const Key('decision-memory-forget-unhelpful'),
                          onPressed: _writing || _confirming
                              ? null
                              : () => _confirmForgetUnhelpful(context, ref),
                          icon: const Icon(Icons.auto_delete_outlined),
                          label: Text(t('Forget unhelpful memories')),
                        ),
                      ),
                    ...rows.map((row) {
                      final evidence =
                          (jsonDecode(row.evidenceJson) as List<dynamic>)
                              .map((item) => item.toString())
                              .toList();
                      return BilPearlMaterialCard(
                        child: ExpansionTile(
                          title: Text(t(row.title)),
                          subtitle: Text('${row.dayKey} · ${t(row.response)}'),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),

                          trailing: const BilCrystalExpansionIndicator(),
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
                                      key: Key(
                                        'decision-memory-rate-${row.id}-$rating',
                                      ),
                                      onPressed: _writing
                                          ? null
                                          : () => _write(
                                              () => ref
                                                  .read(
                                                    decisionMemoryRepositoryProvider,
                                                  )
                                                  .evaluate(
                                                    id: row.id,
                                                    helpfulness: rating,
                                                  ),
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
                                key: Key('decision-memory-delete-${row.id}'),
                                onPressed: _writing
                                    ? null
                                    : () => _write(
                                        () => ref
                                            .read(
                                              decisionMemoryRepositoryProvider,
                                            )
                                            .delete(row.id),
                                      ),
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

  Future<void> _confirmForgetExplicit(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> row,
  ) async {
    final id = row['id']?.toString() ?? '';
    final expectedUpdatedAt = row['updatedAt']?.toString() ?? '';
    final text = row['text']?.toString().trim() ?? '';
    if (id.isEmpty || expectedUpdatedAt.isEmpty || text.isEmpty) return;
    final preferences = ref.read(preferencesRepositoryProvider);
    await _confirmMutation(
      title: context.strings.text('Forget this memory?'),
      message:
          '${context.strings.text('Only the memory you selected will be deleted.')}\n\n$text',
      action: () async {
        await CoachMemoryRepository(preferences: preferences).deleteSelected(
          [CoachMemorySelection(id: id, expectedUpdatedAt: expectedUpdatedAt)],
          isCurrentOwner: () =>
              mounted &&
              identical(ref.read(preferencesRepositoryProvider), preferences),
        );
        if (!mounted) return;
        ref.invalidate(explicitCoachMemoriesProvider);
        ref.invalidate(coachContextSnapshotProvider);
      },
    );
  }

  Future<void> _confirmForgetUnhelpful(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final repository = ref.read(decisionMemoryRepositoryProvider);
    await _confirmMutation(
      title: context.strings.text('Forget memories?'),
      message: context.strings.text(
        'Only memories you rated two stars or less will be deleted. Nothing is deleted automatically.',
      ),
      action: () async {
        await repository.forgetUnhelpful();
      },
    );
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
