import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../data/repositories/daily_log_repository.dart';
import 'presentation/daily_log_input_sections.dart';
import 'presentation/daily_log_summary_widgets.dart';
import 'providers/daily_log_provider.dart';
import 'water_mutation_coordinator.dart';

class DailyWaterPage extends ConsumerStatefulWidget {
  const DailyWaterPage({super.key, this.returnPath});

  final String? returnPath;

  @override
  ConsumerState<DailyWaterPage> createState() => _DailyWaterPageState();
}

class _DailyWaterPageState extends ConsumerState<DailyWaterPage> {
  final amountController = TextEditingController(text: '250');
  late final WaterMutationCoordinator mutations;

  bool get saving => mutations.busy;

  @override
  void initState() {
    super.initState();
    mutations = WaterMutationCoordinator(
      onBusyChanged: (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  void leave() => context.go(widget.returnPath ?? '/daily-log');

  void message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.strings.text(value))));
  }

  Future<bool> ensureDiaryOpen() async {
    final ledger = await ref
        .read(dailyLogRepositoryProvider)
        .readLedger(ref.read(selectedLogDateProvider));
    if (ledger.state != DayLifecycleState.closed) return true;
    message('Reopen the completed diary before making changes.');
    return false;
  }

  Future<void> addWater([int? quickAmount]) async {
    if (saving || !await ensureDiaryOpen()) return;
    final amount = quickAmount ?? int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0 || amount > 5000) {
      message('Enter a water amount from 1 to 5000 ml.');
      return;
    }
    final date = ref.read(selectedLogDateProvider);
    final now = DateTime.now();
    final outcome = await mutations.add(
      repository: ref.read(waterRepositoryProvider),
      occurredAt: DateTime(
        date.year,
        date.month,
        date.day,
        now.hour,
        now.minute,
      ),
      amountMl: amount,
    );
    if (outcome == WaterMutationOutcome.success) {
      amountController.clear();
      ref.invalidate(dailyWaterProvider);
      ref.invalidate(selectedDailyLedgerProvider);
    } else if (outcome == WaterMutationOutcome.failure) {
      message('Water could not be saved. Try again.');
    }
  }

  Future<void> deleteWater(int id) async {
    final outcome = await mutations.delete(
      repository: ref.read(waterRepositoryProvider),
      id: id,
    );
    if (outcome == WaterMutationOutcome.success) {
      ref.invalidate(dailyWaterProvider);
      ref.invalidate(selectedDailyLedgerProvider);
    } else if (outcome == WaterMutationOutcome.failure) {
      message('Water entry could not be removed. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(selectedLogDateProvider);
    final entries = ref.watch(dailyWaterProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !saving) leave();
      },
      child: Scaffold(
        key: const Key('daily-water-page'),
        backgroundColor: const Color(0xFFF5F5F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F5F8),
          surfaceTintColor: Colors.transparent,
          leading: BackButton(onPressed: saving ? null : leave),
          title: Text(
            context.strings.text('Water'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 148),
          children: [
            DiaryDateNavigator(
              date: date,
              arabic: arabic,
              onPrevious: saving
                  ? null
                  : () => ref.read(selectedLogDateProvider.notifier).state =
                        date.subtract(const Duration(days: 1)),
              onNext: date.isBefore(today) && !saving
                  ? () => ref.read(selectedLogDateProvider.notifier).state =
                        date.add(const Duration(days: 1))
                  : null,
              onPick: saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: today,
                      );
                      if (picked != null) {
                        ref.read(selectedLogDateProvider.notifier).state =
                            picked;
                      }
                    },
            ),
            const SizedBox(height: 8),
            DailyWaterSection(
              arabic: arabic,
              controller: amountController,
              entries: entries,
              saving: saving,
              onAdd: addWater,
              onDelete: deleteWater,
              onRetry: () => ref.invalidate(dailyWaterProvider),
            ),
          ],
        ),
      ),
    );
  }
}
