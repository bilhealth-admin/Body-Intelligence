import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/providers/user_profile_provider.dart';
import 'providers/life_context_provider.dart';

class DecisionMemoryPage extends ConsumerWidget {
  const DecisionMemoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(decisionMemoryEnabledProvider).value ?? true;
    final memories = ref.watch(decisionMemoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Decision Memory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: enabled,
            onChanged: (value) => ref
                .read(preferencesRepositoryProvider)
                .set('decisionMemoryEnabled', value.toString()),
            title: const Text('Remember recommendation responses'),
            subtitle: const Text(
              'When off, BIL does not store new action responses or outcomes. Existing memories remain available for deletion.',
            ),
          ),
          const SizedBox(height: 8),
          memories.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (rows) {
              if (rows.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No recommendation responses have been stored. BIL will never invent outcomes.',
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
                      title: Text(row.title),
                      subtitle: Text('${row.dayKey} · ${row.response}'),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            '${row.reason}\nEvidence: ${evidence.join(' · ')}',
                          ),
                        ),
                        if (row.outcome != null)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text('Outcome: ${row.outcome}'),
                          ),
                        if (row.helpfulness == null)
                          Wrap(
                            spacing: 4,
                            children: [
                              const Text('Helpful?'),
                              for (var rating = 1; rating <= 5; rating++)
                                IconButton(
                                  tooltip: '$rating of 5',
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
                          Text('Helpfulness: ${row.helpfulness}/5'),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: () => ref
                                .read(decisionMemoryRepositoryProvider)
                                .delete(row.id),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete memory'),
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
}
