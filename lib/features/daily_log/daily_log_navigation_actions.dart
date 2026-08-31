part of 'daily_log_page.dart';

extension _DailyLogNavigationActions on _DailyLogPageState {
  void _openFoodSearchAfterBuild([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (foodSearch.isAttached) {
        foodSearch.openView();
        return;
      }
      // SearchAnchor is inserted by the same state change that exposes the
      // meal-entry surface. On slower devices it may attach one frame later.
      if (attempt < 3) _openFoodSearchAfterBuild(attempt + 1);
    });
  }

  Future<void> _applyInitialAction() async {
    if (!mounted || initialActionApplied) return;
    final action = widget.initialAction;
    if (action == null || initialActionInFlight != null) return;
    initialActionApplied = true;
    initialActionInFlight = action;
    try {
      switch (action) {
        case 'barcode':
          await _scanBarcode();
        case 'voice':
          await _captureMealVoice();
        case 'photo':
          await _analyzeMealImage();
        case 'water':
          final origin = Uri.encodeComponent(widget.returnPath ?? '/daily-log');
          context.go('/daily-log/water?from=$origin');
        case 'notes':
          final location = Uri(
            path: '/daily-log/body-context',
            queryParameters: {'from': widget.returnPath ?? '/daily-log'},
          ).toString();
          await context.push(location);
        case 'exercise':
          await _reveal(exerciseSectionKey);
        case 'quick-macros':
          await _quickAddMacrosV2();
      }
    } finally {
      if (initialActionInFlight == action) initialActionInFlight = null;
      if (mounted && widget.initialAction != action) {
        initialActionApplied = false;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _applyInitialAction(),
        );
      }
    }
  }

  Future<void> _reveal(GlobalKey key) async {
    final target = key.currentContext;
    if (!mounted || target == null) return;
    await Scrollable.ensureVisible(
      target,
      alignment: .08,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showDiaryCopyOptions() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(_tr('Previous day', 'اليوم السابق')),
              subtitle: Text(
                _tr('Copy all meals from yesterday.', 'انسخ جميع وجبات الأمس.'),
              ),
              onTap: () => Navigator.pop(sheetContext, 'previous'),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_rounded),
              title: Text(_tr('Choose days', 'اختيار أيام')),
              subtitle: Text(
                _tr(
                  'Copy this diary to one or more dates.',
                  'انسخ هذه اليوميات إلى تاريخ واحد أو أكثر.',
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, 'multiple'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (selection == 'previous') {
      await _copyPreviousDayMeals();
    } else if (selection == 'multiple') {
      await _copyToMultipleDays();
    }
  }
}

double? _parsePositiveQuantity(String raw) {
  final value = double.tryParse(raw.replaceAll(',', '.'));
  if (value == null || !value.isFinite || value < 0.1 || value > 100000) {
    return null;
  }
  return value;
}
