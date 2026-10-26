// Copyright 2014 The Flutter Authors. All rights reserved.
// BSD-3-Clause; see LICENSE.flutter in this directory.
// Pinned Flutter 3.44.6 single-date picker; static BIL arrow decoration only.
part of 'bil_crystal_calendar_date_picker.dart';

class _MonthPicker extends StatefulWidget {
  /// Creates a month picker.
  _MonthPicker({
    super.key,
    required this.initialMonth,
    required this.currentDate,
    required this.firstDate,
    required this.lastDate,
    required this.selectedDate,
    required this.onChanged,
    required this.onDisplayedMonthChanged,
    required this.calendarDelegate,
    this.selectableDayPredicate,
  }) : assert(!firstDate.isAfter(lastDate)),
       assert(selectedDate == null || !selectedDate.isBefore(firstDate)),
       assert(selectedDate == null || !selectedDate.isAfter(lastDate));

  /// The initial month to display.
  ///
  /// Subsequently changing this has no effect. To change the selected month,
  /// change the [key] to create a new instance of the [_MonthPicker], and
  /// provide that widget the new [initialMonth]. This will reset the widget's
  /// interactive state.
  final DateTime initialMonth;

  /// The current date.
  ///
  /// This date is subtly highlighted in the picker.
  final DateTime currentDate;

  /// The earliest date the user is permitted to pick.
  ///
  /// This date must be on or before the [lastDate].
  final DateTime firstDate;

  /// The latest date the user is permitted to pick.
  ///
  /// This date must be on or after the [firstDate].
  final DateTime lastDate;

  /// The currently selected date.
  ///
  /// This date is highlighted in the picker.
  final DateTime? selectedDate;

  /// Called when the user picks a day.
  final ValueChanged<DateTime> onChanged;

  /// Called when the user navigates to a new month.
  final ValueChanged<DateTime> onDisplayedMonthChanged;

  /// Optional user supplied predicate function to customize selectable days.
  final SelectableDayPredicate? selectableDayPredicate;

  /// {@macro flutter.material.calendar_date_picker.calendarDelegate}
  final CalendarDelegate<DateTime> calendarDelegate;

  @override
  _MonthPickerState createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  final GlobalKey _pageViewKey = GlobalKey();
  String _announcementText = '';
  late DateTime _currentMonth;
  late PageController _pageController;
  late MaterialLocalizations _localizations;
  Map<ShortcutActivator, Intent>? _shortcutMap;
  Map<Type, Action<Intent>>? _actionMap;
  late FocusNode _dayGridFocus;
  DateTime? _focusedDay;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialMonth;
    _pageController = PageController(
      initialPage: widget.calendarDelegate.monthDelta(
        widget.firstDate,
        _currentMonth,
      ),
    );
    _shortcutMap = const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
        TraversalDirection.left,
      ),
      SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(
        TraversalDirection.right,
      ),
      SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
        TraversalDirection.down,
      ),
      SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
        TraversalDirection.up,
      ),
    };
    _actionMap = <Type, Action<Intent>>{
      NextFocusIntent: CallbackAction<NextFocusIntent>(
        onInvoke: _handleGridNextFocus,
      ),
      PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
        onInvoke: _handleGridPreviousFocus,
      ),
      DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
        onInvoke: _handleDirectionFocus,
      ),
    };
    _dayGridFocus = FocusNode(debugLabel: 'Day Grid');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localizations = MaterialLocalizations.of(context);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dayGridFocus.dispose();
    super.dispose();
  }

  void _handleDateSelected(DateTime selectedDate) {
    _focusedDay = selectedDate;
    widget.onChanged(selectedDate);
  }

  // Auxiliary method for handling the difference between platforms
  void _announce(String message) {
    if (MediaQuery.maybeSupportsAnnounceOf(context) ?? false) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ).catchError(_reportAnnouncementError);
    } else {
      // If SemanticsService.sendAnnouncement is not supported,
      // we use live region to achieve the announcement effect instead.
      _announcementText = message;
    }
  }

  void _handleMonthPageChanged(int monthPage) {
    setState(() {
      final DateTime monthDate = widget.calendarDelegate.addMonthsToMonthDate(
        widget.firstDate,
        monthPage,
      );
      if (!widget.calendarDelegate.isSameMonth(_currentMonth, monthDate)) {
        _currentMonth = widget.calendarDelegate.getMonth(
          monthDate.year,
          monthDate.month,
        );
        widget.onDisplayedMonthChanged(_currentMonth);
        if (_focusedDay != null &&
            !widget.calendarDelegate.isSameMonth(_focusedDay, _currentMonth)) {
          // We have navigated to a new month with the grid focused, but the
          // focused day is not in this month. Choose a new one trying to keep
          // the same day of the month.
          _focusedDay = _focusableDayForMonth(_currentMonth, _focusedDay!.day);
        }
        _announce(
          widget.calendarDelegate.formatMonthYear(
            _currentMonth,
            _localizations,
          ),
        );
      }
    });
  }

  /// Returns a focusable date for the given month.
  ///
  /// If the preferredDay is available in the month it will be returned,
  /// otherwise the first selectable day in the month will be returned. If
  /// no dates are selectable in the month, then it will return null.
  DateTime? _focusableDayForMonth(DateTime month, int preferredDay) {
    final int daysInMonth = widget.calendarDelegate.getDaysInMonth(
      month.year,
      month.month,
    );

    // Can we use the preferred day in this month?
    if (preferredDay <= daysInMonth) {
      final DateTime newFocus = widget.calendarDelegate.getDay(
        month.year,
        month.month,
        preferredDay,
      );
      if (_isSelectable(newFocus)) {
        return newFocus;
      }
    }

    // Start at the 1st and take the first selectable date.
    for (var day = 1; day <= daysInMonth; day++) {
      final DateTime newFocus = widget.calendarDelegate.getDay(
        month.year,
        month.month,
        day,
      );
      if (_isSelectable(newFocus)) {
        return newFocus;
      }
    }
    return null;
  }

  /// Navigate to the next month.
  void _handleNextMonth() {
    if (!_isDisplayingLastMonth) {
      _pageController.nextPage(
        duration: _monthScrollDuration,
        curve: Curves.ease,
      );
    }
  }

  /// Navigate to the previous month.
  void _handlePreviousMonth() {
    if (!_isDisplayingFirstMonth) {
      _pageController.previousPage(
        duration: _monthScrollDuration,
        curve: Curves.ease,
      );
    }
  }

  /// Navigate to the given month.
  void _showMonth(DateTime month, {bool jump = false}) {
    final int monthPage = widget.calendarDelegate.monthDelta(
      widget.firstDate,
      month,
    );
    if (jump) {
      _pageController.jumpToPage(monthPage);
    } else {
      _pageController.animateToPage(
        monthPage,
        duration: _monthScrollDuration,
        curve: Curves.ease,
      );
    }
  }

  /// True if the earliest allowable month is displayed.
  bool get _isDisplayingFirstMonth {
    return !_currentMonth.isAfter(
      widget.calendarDelegate.getMonth(
        widget.firstDate.year,
        widget.firstDate.month,
      ),
    );
  }

  /// True if the latest allowable month is displayed.
  bool get _isDisplayingLastMonth {
    return !_currentMonth.isBefore(
      widget.calendarDelegate.getMonth(
        widget.lastDate.year,
        widget.lastDate.month,
      ),
    );
  }

  /// Handler for when the overall day grid obtains or loses focus.
  void _handleGridFocusChange(bool focused) {
    setState(() {
      if (focused && _focusedDay == null) {
        if (widget.calendarDelegate.isSameMonth(
          widget.selectedDate,
          _currentMonth,
        )) {
          _focusedDay = widget.selectedDate;
        } else if (widget.calendarDelegate.isSameMonth(
          widget.currentDate,
          _currentMonth,
        )) {
          _focusedDay = _focusableDayForMonth(
            _currentMonth,
            widget.currentDate.day,
          );
        } else {
          _focusedDay = _focusableDayForMonth(_currentMonth, 1);
        }
      }
    });
  }

  /// Move focus to the next element after the day grid.
  void _handleGridNextFocus(NextFocusIntent intent) {
    _dayGridFocus.requestFocus();
    _dayGridFocus.nextFocus();
  }

  /// Move focus to the previous element before the day grid.
  void _handleGridPreviousFocus(PreviousFocusIntent intent) {
    _dayGridFocus.requestFocus();
    _dayGridFocus.previousFocus();
  }

  /// Move the internal focus date in the direction of the given intent.
  ///
  /// This will attempt to move the focused day to the next selectable day in
  /// the given direction. If the new date is not in the current month, then
  /// the page view will be scrolled to show the new date's month.
  ///
  /// For horizontal directions, it will move forward or backward a day (depending
  /// on the current [TextDirection]). For vertical directions it will move up and
  /// down a week at a time.
  void _handleDirectionFocus(DirectionalFocusIntent intent) {
    assert(_focusedDay != null);
    setState(() {
      final DateTime? nextDate = _nextDateInDirection(
        _focusedDay!,
        intent.direction,
      );
      if (nextDate != null) {
        _focusedDay = nextDate;
        if (!widget.calendarDelegate.isSameMonth(_focusedDay, _currentMonth)) {
          _showMonth(_focusedDay!);
        }
      }
    });
  }

  static const Map<TraversalDirection, int> _directionOffset =
      <TraversalDirection, int>{
        TraversalDirection.up: -DateTime.daysPerWeek,
        TraversalDirection.right: 1,
        TraversalDirection.down: DateTime.daysPerWeek,
        TraversalDirection.left: -1,
      };

  int _dayDirectionOffset(
    TraversalDirection traversalDirection,
    TextDirection textDirection,
  ) {
    // Swap left and right if the text direction if RTL
    if (textDirection == TextDirection.rtl) {
      if (traversalDirection == TraversalDirection.left) {
        traversalDirection = TraversalDirection.right;
      } else if (traversalDirection == TraversalDirection.right) {
        traversalDirection = TraversalDirection.left;
      }
    }
    return _directionOffset[traversalDirection]!;
  }

  DateTime? _nextDateInDirection(DateTime date, TraversalDirection direction) {
    final TextDirection textDirection = Directionality.of(context);
    DateTime nextDate = widget.calendarDelegate.addDaysToDate(
      date,
      _dayDirectionOffset(direction, textDirection),
    );
    while (!nextDate.isBefore(widget.firstDate) &&
        !nextDate.isAfter(widget.lastDate)) {
      if (_isSelectable(nextDate)) {
        return nextDate;
      }
      nextDate = widget.calendarDelegate.addDaysToDate(
        nextDate,
        _dayDirectionOffset(direction, textDirection),
      );
    }
    return null;
  }

  bool _isSelectable(DateTime date) {
    return widget.selectableDayPredicate?.call(date) ?? true;
  }

  Widget _buildItems(BuildContext context, int index) {
    final DateTime month = widget.calendarDelegate.addMonthsToMonthDate(
      widget.firstDate,
      index,
    );
    return _DayPicker(
      key: ValueKey<DateTime>(month),
      calendarDelegate: widget.calendarDelegate,
      selectedDate: widget.selectedDate,
      currentDate: widget.currentDate,
      onChanged: _handleDateSelected,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      displayedMonth: month,
      selectableDayPredicate: widget.selectableDayPredicate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color? subHeaderForegroundColor =
        DatePickerTheme.of(context).subHeaderForegroundColor ??
        DatePickerTheme.defaults(context).subHeaderForegroundColor;

    final bool supportsAnnounce =
        MediaQuery.maybeSupportsAnnounceOf(context) ?? false;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: !supportsAnnounce,
      accessibilityFocusBlockType: !supportsAnnounce
          ? AccessibilityFocusBlockType.blockNode
          : AccessibilityFocusBlockType.none,
      label: !supportsAnnounce ? _announcementText : null,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: _subHeaderHeight,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
              child: Row(
                children: <Widget>[
                  const Spacer(),
                  IconButton(
                    icon: BilCrystalArrow(
                      child: Icon(
                        Icons.chevron_left,
                        semanticLabel: _isDisplayingFirstMonth
                            ? _localizations.previousMonthTooltip
                            : null,
                      ),
                    ),
                    color: subHeaderForegroundColor,
                    tooltip: _isDisplayingFirstMonth
                        ? null
                        : _localizations.previousMonthTooltip,
                    onPressed: _isDisplayingFirstMonth
                        ? null
                        : _handlePreviousMonth,
                  ),
                  IconButton(
                    icon: BilCrystalArrow(
                      child: Icon(
                        Icons.chevron_right,
                        semanticLabel: _isDisplayingLastMonth
                            ? _localizations.nextMonthTooltip
                            : null,
                      ),
                    ),
                    color: subHeaderForegroundColor,
                    tooltip: _isDisplayingLastMonth
                        ? null
                        : _localizations.nextMonthTooltip,
                    onPressed: _isDisplayingLastMonth ? null : _handleNextMonth,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FocusableActionDetector(
              shortcuts: _shortcutMap,
              actions: _actionMap,
              focusNode: _dayGridFocus,
              onFocusChange: _handleGridFocusChange,
              child: _FocusedDate(
                calendarDelegate: widget.calendarDelegate,
                date: _dayGridFocus.hasFocus ? _focusedDay : null,
                // Wrap the PageView with `Material`, so when its child paints on materials
                // the content won't go out of boundary during page transition.
                child: Material(
                  type: MaterialType.transparency,
                  child: PageView.builder(
                    key: _pageViewKey,
                    controller: _pageController,
                    itemBuilder: _buildItems,
                    itemCount:
                        widget.calendarDelegate.monthDelta(
                          widget.firstDate,
                          widget.lastDate,
                        ) +
                        1,
                    onPageChanged: _handleMonthPageChanged,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// InheritedWidget indicating what the current focused date is for its children.
///
/// This is used by the [_MonthPicker] to let its children [_DayPicker]s know
/// what the currently focused date (if any) should be.
