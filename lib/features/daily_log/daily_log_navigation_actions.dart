part of 'daily_log_page.dart';

extension _DailyLogNavigationActions on _DailyLogPageState {
  void _focusMealEntry() {
    final mealContext = mealEntryKey.currentContext;
    if (!mounted || mealContext == null) return;
    mealFocusApplied = true;
    Scrollable.ensureVisible(
      mealContext,
      alignment: 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _leaveMealDetail() {
    if (widget.focusMealEntry) {
      context.go(widget.returnPath ?? '/daily-log');
      return;
    }
    _updateState(() {
      selectedFood = null;
      mealSearchActive = false;
    });
  }

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
        case 'recovered-photo':
          await _analyzeMealImage(recoveredOnly: true);
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
      } else if (mounted &&
          widget.initialAction == action &&
          const {
            'barcode',
            'voice',
            'photo',
            'recovered-photo',
            'notes',
            'exercise',
            'quick-macros',
          }.contains(action)) {
        // Consume one-shot Quick Add/deep-link actions after their flow has
        // closed. Leaving `action=barcode` (or voice/photo) in the location
        // means selecting the same action again can reuse the same GoRouter
        // page with an unchanged `initialAction`, so didUpdateWidget has no
        // change to dispatch and the user sees only Today. Preserve the safe
        // return destination while clearing the action for the next request.
        final cleanLocation = Uri(
          path: '/daily-log',
          queryParameters: {
            if (widget.returnPath != null) 'from': widget.returnPath!,
          },
        ).toString();
        context.go(cleanLocation);
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
              leading: const BilSemanticIconBadge(
                kind: BilSemanticIconKind.calendar,
              ),
              title: Text(_tr('Previous day', 'اليوم السابق')),
              subtitle: Text(
                _tr('Copy all meals from yesterday.', 'انسخ جميع وجبات الأمس.'),
              ),
              onTap: () => Navigator.pop(sheetContext, 'previous'),
            ),
            ListTile(
              leading: const BilSemanticIconBadge(
                kind: BilSemanticIconKind.calendar,
              ),
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
