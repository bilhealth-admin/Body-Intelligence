part of 'reference_goals_page.dart';

extension _ReferenceGoalWeightEditors on _ReferenceGoalsPageState {
  Future<double?> numberEditor(
    String title,
    double initial,
    double min,
    double max,
    MeasurementSystem system,
    _ReferenceGoalVisit visit,
  ) async {
    if (_numberEditorOpen || !visit.current) {
      return null;
    }
    _numberEditorOpen = true;
    final controller = TextEditingController(
      text: UnitConverter.weightFromKg(initial, system).toStringAsFixed(1),
    );
    double? result;
    try {
      result = await showBilPearlBottomSheet<double>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (!visit.current || !sheetContext.mounted) {
                        return;
                      }
                      final value = referenceGoalWeightInput(
                        controller.text,
                        system,
                        initialKg: initial,
                        minKg: min,
                        maxKg: max,
                      );
                      if (value != null) {
                        Navigator.pop(sheetContext, value);
                      }
                    },
                    icon: const Icon(Icons.check_rounded),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 18),
              TextField(
                key: const Key('goals-weight-input'),
                controller: controller,
                autofocus: false,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: c(UnitConverter.weightUnit(system)),
                  suffixText: c(UnitConverter.weightUnit(system)),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      controller.dispose();
      _numberEditorOpen = false;
    }
    return visit.current ? result : null;
  }

  Future<({double weight, DateTime? date})?> startingWeightEditor(
    double initial,
    MeasurementSystem system,
    _ReferenceGoalVisit visit,
  ) async {
    if (_numberEditorOpen || !visit.current) {
      return null;
    }
    _numberEditorOpen = true;
    final controller = TextEditingController(
      text: UnitConverter.weightFromKg(initial, system).toStringAsFixed(1),
    );
    // Missing/cleared dates remain unknown until the user actually selects one.
    var date = DateTime.tryParse(startingDate ?? '');
    ({double weight, DateTime? date})? result;
    try {
      result = await showBilPearlBottomSheet<({double weight, DateTime? date})>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: Text(
                        c('Starting Weight'),
                        textAlign: TextAlign.center,
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        if (!visit.current || !sheetContext.mounted) {
                          return;
                        }
                        final weight = referenceGoalWeightInput(
                          controller.text,
                          system,
                          initialKg: initial,
                        );
                        if (weight != null) {
                          Navigator.pop(sheetContext, (
                            weight: weight,
                            date: date,
                          ));
                        }
                      },
                      icon: const Icon(Icons.check_rounded),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('goals-starting-weight-input'),
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: c(UnitConverter.weightUnit(system)),
                    suffixText: c(UnitConverter.weightUnit(system)),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  key: const Key('goals-starting-date'),
                  contentPadding: EdgeInsets.zero,
                  leading: const BilSemanticIconBadge(
                    kind: BilSemanticIconKind.calendar,
                  ),
                  title: Text(c('Starting Date')),
                  subtitle: Text(
                    date == null
                        ? '—'
                        : MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(date!),
                  ),
                  onTap: () async {
                    if (!visit.current) {
                      return;
                    }
                    final selected = await showBilCrystalDatePicker(
                      context: sheetContext,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null &&
                        visit.current &&
                        sheetContext.mounted) {
                      setSheetState(() => date = selected);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      controller.dispose();
      _numberEditorOpen = false;
    }
    return visit.current ? result : null;
  }
}
