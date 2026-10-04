import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';
import '../../app/theme/premium_design_tokens.dart';
import 'daily_body_context_copy.dart';
import 'domain/daily_body_context_codec.dart';
import 'presentation/daily_log_input_sections.dart';
import 'presentation/daily_log_summary_widgets.dart';
import 'providers/daily_log_provider.dart';

class DailyBodyContextPage extends ConsumerStatefulWidget {
  const DailyBodyContextPage({super.key, this.returnPath});

  final String? returnPath;

  @override
  ConsumerState<DailyBodyContextPage> createState() =>
      _DailyBodyContextPageState();
}

class _DailyBodyContextPageState extends ConsumerState<DailyBodyContextPage> {
  static const options = DailyBodyContextCodec.optionKeys;

  final dailyNote = TextEditingController();
  final otherContext = TextEditingController();
  final Set<String> selected = {};
  String? loadedIdentity;

  String get languageCode =>
      Localizations.localeOf(context).languageCode.toLowerCase();
  bool get arabic => languageCode == 'ar';
  String copy(String key) => dailyBodyContextCopy(context, key);

  String labelFor(String value) => copy(value);

  void loadSelection(String value, String identity) {
    if (loadedIdentity == identity) return;
    loadedIdentity = identity;
    selected.clear();
    otherContext.clear();
    dailyNote.clear();
    final decoded = DailyBodyContextCodec.decode(value);
    selected.addAll(decoded.selected);
    dailyNote.text = decoded.note;
    otherContext.text = decoded.other;
  }

  String encodeSelection() => DailyBodyContextCodec.encode(
    selected: selected,
    note: dailyNote.text,
    other: otherContext.text,
  );

  Future<void> save() async {
    final notes = encodeSelection();
    await ref
        .read(dailyLogRepositoryProvider)
        .saveBodyContext(
          date: ref.read(selectedLogDateProvider),
          notes: notes.isEmpty ? null : notes,
        );
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.returnPath ?? '/daily-log');
    }
  }

  void leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.returnPath ?? '/daily-log');
    }
  }

  @override
  void dispose() {
    dailyNote.dispose();
    otherContext.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(selectedLogDateProvider);
    final selectedLog = ref.watch(selectedDailyLogProvider);
    ref.listen(selectedDailyLogProvider, (_, next) {
      next.whenData((log) {
        final value = log?.notes ?? '';
        final identity = '${date.toIso8601String()}|$value';
        if (!mounted || loadedIdentity == identity) return;
        setState(() => loadSelection(value, identity));
      });
    });
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(copy('title')),
          leading: BackButton(onPressed: leave),
        ),
        body: ListView(
          padding: PremiumDesignTokens.screenPadding.add(
            const EdgeInsets.only(bottom: 48),
          ),
          children: [
            if (selectedLog.isLoading) const LinearProgressIndicator(),
            DiaryDateNavigator(
              date: date,
              arabic: arabic,
              onPrevious: () =>
                  ref.read(selectedLogDateProvider.notifier).state = date
                      .subtract(const Duration(days: 1)),
              onNext: date.isBefore(normalizedToday)
                  ? () => ref.read(selectedLogDateProvider.notifier).state =
                        date.add(const Duration(days: 1))
                  : null,
              onPick: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: normalizedToday,
                );
                if (picked != null) {
                  ref.read(selectedLogDateProvider.notifier).state = picked;
                }
              },
            ),
            const SizedBox(height: PremiumDesignTokens.spaceLg),
            DailyBodyContextSection(
              arabic: arabic,
              options: options,
              selected: selected,
              otherController: otherContext,
              dailyNoteController: dailyNote,
              labelFor: labelFor,
              onOtherChanged: () => setState(() {}),
              onDailyNoteChanged: () => setState(() {}),
              onToggle: (option, active) {
                setState(() {
                  if (option == 'nothingNotable' && active) {
                    selected
                      ..clear()
                      ..add(option);
                  } else {
                    selected.remove('nothingNotable');
                    if (active) {
                      selected.add(option);
                    } else {
                      selected.remove(option);
                    }
                  }
                  if (!selected.contains('other')) otherContext.clear();
                });
              },
            ),
            const SizedBox(height: PremiumDesignTokens.spaceLg),
            FilledButton(
              key: const Key('daily-body-context-save-action'),
              onPressed: selectedLog.hasValue ? save : null,
              child: Text(
                RuntimeCopy.resolve(
                      'Save log',
                      BilLocalePolicy.canonicalTag(
                        Localizations.localeOf(context),
                      ),
                    ) ??
                    context.strings.text('Save log'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
