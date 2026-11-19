import '../../shared/widgets/bil_pearl_feature_welcome.dart';
import 'package:body_intelligence_log/shared/widgets/calendar/bil_crystal_date_picker.dart';
import 'package:body_intelligence_log/shared/widgets/bil_crystal_arrow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/localization/bil_locale_policy.dart';
import '../../app/localization/runtime_copy.dart';
import '../../app/theme/premium_design_tokens.dart';
import '../../shared/widgets/actionable_error_state.dart';
import '../../data/database/app_database.dart';
import '../../data/database/date_keys.dart';
import 'daily_body_context_copy.dart';
import 'domain/daily_body_context_codec.dart';
import 'presentation/daily_log_input_sections.dart';
import 'presentation/daily_log_summary_widgets.dart';
import 'providers/daily_log_provider.dart';

// A visit changes even when an owner/day returns to an earlier value. It is
// a retirement token, not authorization; the repository still owns storage.
final _bodyContextVisitProvider = Provider<Object>((ref) {
  ref.watch(dailyLogRepositoryProvider);
  ref.watch(selectedLogDateProvider);
  return Object();
});

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
  Object? _loadedVisit;
  bool _dirty = false;
  bool _saving = false;
  int _draftRevision = 0;

  String get languageCode =>
      Localizations.localeOf(context).languageCode.toLowerCase();
  bool get arabic => languageCode == 'ar';
  String copy(String key) => dailyBodyContextCopy(context, key);

  String labelFor(String value) => copy(value);

  void loadSelection(String value, String identity) {
    if (_dirty || loadedIdentity == identity) return;
    loadedIdentity = identity;
    selected.clear();
    otherContext.clear();
    dailyNote.clear();
    final decoded = DailyBodyContextCodec.decode(value);
    selected.addAll(decoded.selected);
    dailyNote.text = decoded.note;
    otherContext.text = decoded.other;
  }

  void _activateVisit(Object visit) {
    if (identical(_loadedVisit, visit)) return;
    _loadedVisit = visit;
    loadedIdentity = null;
    _dirty = false;
    _saving = false;
    _draftRevision = 0;
    selected.clear();
    otherContext.clear();
    dailyNote.clear();
  }

  bool _selectionReady(AsyncValue<DailyLog?> value, DateTime date) {
    final current = value.asData;
    return !value.isLoading &&
        !value.hasError &&
        current != null &&
        (current.value == null || current.value!.dayKey == dayKeyFor(date));
  }

  String encodeSelection() => DailyBodyContextCodec.encode(
    selected: selected,
    note: dailyNote.text,
    other: otherContext.text,
  );

  Future<void> save() async {
    final visit = ref.read(_bodyContextVisitProvider);
    final repository = ref.read(dailyLogRepositoryProvider);
    final date = ref.read(selectedLogDateProvider);
    final selectedLog = ref.read(selectedDailyLogProvider);
    if (_saving ||
        !identical(_loadedVisit, visit) ||
        !_selectionReady(selectedLog, date)) {
      return;
    }
    final expected = selectedLog.asData!.value;
    // A fresh provider emission may precede its next frame. A clean editor
    // must seed that value before an untouched Save can replace it.
    if (!_dirty && loadedIdentity != (expected?.notes ?? '')) return;
    final notes = encodeSelection();
    final revision = _draftRevision;
    bool isCurrent() =>
        mounted &&
        identical(_loadedVisit, visit) &&
        identical(visit, ref.read(_bodyContextVisitProvider)) &&
        identical(repository, ref.read(dailyLogRepositoryProvider));
    setState(() => _saving = true);
    try {
      await repository.saveBodyContext(
        date: date,
        notes: notes.isEmpty ? null : notes,
        expectedRecord: expected,
        expectAbsent: expected == null,
        isCurrent: isCurrent,
      );
      if (!mounted || !isCurrent() || _draftRevision != revision) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(widget.returnPath ?? '/daily-log');
      }
    } on Object {
      if (mounted && isCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.strings.text('Could not save changes.')),
          ),
        );
      }
    } finally {
      if (isCurrent()) setState(() => _saving = false);
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
    final visit = ref.watch(_bodyContextVisitProvider);
    final selectedLog = ref.watch(selectedDailyLogProvider);
    _activateVisit(visit);
    final selectionReady = _selectionReady(selectedLog, date);
    if (selectionReady) {
      final value = selectedLog.asData!.value?.notes ?? '';
      // watch supplies cached AsyncData on the first build as well as later
      // emissions; a listener alone misses the cached reopen case.
      loadSelection(value, value);
    }
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
          leading: BilCrystalArrow(child: BackButton(onPressed: leave)),
        ),
        body: ListView(
          padding: PremiumDesignTokens.screenPadding.add(
            const EdgeInsets.only(bottom: 48),
          ),
          children: [
            if (selectedLog.isLoading) const BilFeatureWelcomeStatus(),
            if (selectedLog.hasError && !selectedLog.isLoading)
              ActionableErrorState(
                key: const Key('body-context-read-error'),
                title: copy('title'),
                onRetry: () => ref.invalidate(selectedDailyLogProvider),
              ),
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
                final pickerVisit = ref.read(_bodyContextVisitProvider);
                final picked = await showBilCrystalDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: normalizedToday,
                );
                if (!mounted ||
                    !identical(
                      pickerVisit,
                      ref.read(_bodyContextVisitProvider),
                    )) {
                  return;
                }
                if (picked != null) {
                  ref.read(selectedLogDateProvider.notifier).state = picked;
                }
              },
            ),
            const SizedBox(height: PremiumDesignTokens.spaceLg),
            if (selectionReady)
              DailyBodyContextSection(
                arabic: arabic,
                options: options,
                selected: selected,
                otherController: otherContext,
                dailyNoteController: dailyNote,
                labelFor: labelFor,
                onOtherChanged: () => setState(() {
                  _dirty = true;
                  _draftRevision++;
                }),
                onDailyNoteChanged: () => setState(() {
                  _dirty = true;
                  _draftRevision++;
                }),
                onToggle: (option, active) {
                  setState(() {
                    _dirty = true;
                    _draftRevision++;
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
              onPressed: selectionReady && !_saving ? save : null,
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
