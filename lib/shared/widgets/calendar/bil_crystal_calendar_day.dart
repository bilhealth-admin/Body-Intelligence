// Copyright 2014 The Flutter Authors. All rights reserved.
// BSD-3-Clause; see LICENSE.flutter in this directory.
// Pinned Flutter 3.44.6 single-date picker; static BIL arrow decoration only.
part of 'bil_crystal_calendar_date_picker.dart';

class _FocusedDate extends InheritedWidget {
  const _FocusedDate({
    required super.child,
    required this.calendarDelegate,
    this.date,
  });

  final CalendarDelegate<DateTime> calendarDelegate;
  final DateTime? date;

  @override
  bool updateShouldNotify(_FocusedDate oldWidget) {
    return !calendarDelegate.isSameDay(date, oldWidget.date);
  }

  static DateTime? maybeOf(BuildContext context) {
    final _FocusedDate? focusedDate = context
        .dependOnInheritedWidgetOfExactType<_FocusedDate>();
    return focusedDate?.date;
  }
}

/// Displays the days of a given month and allows choosing a day.
///
/// The days are arranged in a rectangular grid with one column for each day of
/// the week.
class _DayPicker extends StatefulWidget {
  /// Creates a day picker.
  _DayPicker({
    super.key,
    required this.currentDate,
    required this.displayedMonth,
    required this.firstDate,
    required this.lastDate,
    required this.selectedDate,
    required this.onChanged,
    required this.calendarDelegate,
    this.selectableDayPredicate,
  }) : assert(!firstDate.isAfter(lastDate)),
       assert(selectedDate == null || !selectedDate.isBefore(firstDate)),
       assert(selectedDate == null || !selectedDate.isAfter(lastDate));

  /// The currently selected date.
  ///
  /// This date is highlighted in the picker.
  final DateTime? selectedDate;

  /// The current date at the time the picker is displayed.
  final DateTime currentDate;

  /// Called when the user picks a day.
  final ValueChanged<DateTime> onChanged;

  /// The earliest date the user is permitted to pick.
  ///
  /// This date must be on or before the [lastDate].
  final DateTime firstDate;

  /// The latest date the user is permitted to pick.
  ///
  /// This date must be on or after the [firstDate].
  final DateTime lastDate;

  /// The month whose days are displayed by this picker.
  final DateTime displayedMonth;

  /// Optional user supplied predicate function to customize selectable days.
  final SelectableDayPredicate? selectableDayPredicate;

  /// {@macro flutter.material.calendar_date_picker.calendarDelegate}
  final CalendarDelegate<DateTime> calendarDelegate;

  @override
  _DayPickerState createState() => _DayPickerState();
}

class _DayPickerState extends State<_DayPicker> {
  /// List of [FocusNode]s, one for each day of the month.
  late List<FocusNode> _dayFocusNodes;

  @override
  void initState() {
    super.initState();
    final int daysInMonth = widget.calendarDelegate.getDaysInMonth(
      widget.displayedMonth.year,
      widget.displayedMonth.month,
    );
    _dayFocusNodes = List<FocusNode>.generate(
      daysInMonth,
      (int index) =>
          FocusNode(skipTraversal: true, debugLabel: 'Day ${index + 1}'),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check to see if the focused date is in this month, if so focus it.
    final DateTime? focusedDate = _FocusedDate.maybeOf(context);
    if (focusedDate != null &&
        widget.calendarDelegate.isSameMonth(
          widget.displayedMonth,
          focusedDate,
        )) {
      _dayFocusNodes[focusedDate.day - 1].requestFocus();
    }
  }

  @override
  void dispose() {
    for (final FocusNode node in _dayFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Builds widgets showing abbreviated days of week. The first widget in the
  /// returned list corresponds to the first day of week for the current locale.
  ///
  /// Examples:
  ///
  ///     ┌ Sunday is the first day of week in the US (en_US)
  ///     |
  ///     S M T W T F S  ← the returned list contains these widgets
  ///     _ _ _ _ _ 1 2
  ///     3 4 5 6 7 8 9
  ///
  ///     ┌ But it's Monday in the UK (en_GB)
  ///     |
  ///     M T W T F S S  ← the returned list contains these widgets
  ///     _ _ _ _ 1 2 3
  ///     4 5 6 7 8 9 10
  ///
  List<Widget> _dayHeaders(
    TextStyle? headerStyle,
    MaterialLocalizations localizations,
  ) {
    final result = <Widget>[];
    for (
      int i = localizations.firstDayOfWeekIndex;
      result.length < DateTime.daysPerWeek;
      i = (i + 1) % DateTime.daysPerWeek
    ) {
      final String weekday = localizations.narrowWeekdays[i];
      result.add(
        ExcludeSemantics(
          child: Center(child: Text(weekday, style: headerStyle)),
        ),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final DatePickerThemeData datePickerTheme = DatePickerTheme.of(context);
    final DatePickerThemeData defaults = DatePickerTheme.defaults(context);
    final TextStyle? weekdayStyle =
        datePickerTheme.weekdayStyle ?? defaults.weekdayStyle;

    final Orientation orientation = MediaQuery.orientationOf(context);
    final isLandscapeOrientation = orientation == Orientation.landscape;

    final int year = widget.displayedMonth.year;
    final int month = widget.displayedMonth.month;

    final int daysInMonth = widget.calendarDelegate.getDaysInMonth(year, month);
    final int dayOffset = widget.calendarDelegate.firstDayOffset(
      year,
      month,
      localizations,
    );

    final List<Widget> dayItems = _dayHeaders(weekdayStyle, localizations);
    // 1-based day of month, e.g. 1-31 for January, and 1-29 for February on
    // a leap year.
    int day = -dayOffset;
    while (day < daysInMonth) {
      day++;
      if (day < 1) {
        dayItems.add(const SizedBox.shrink());
      } else {
        final DateTime dayToBuild = widget.calendarDelegate.getDay(
          year,
          month,
          day,
        );
        final bool isDisabled =
            dayToBuild.isAfter(widget.lastDate) ||
            dayToBuild.isBefore(widget.firstDate) ||
            (widget.selectableDayPredicate != null &&
                !widget.selectableDayPredicate!(dayToBuild));
        final bool isSelectedDay = widget.calendarDelegate.isSameDay(
          widget.selectedDate,
          dayToBuild,
        );
        final bool isToday = widget.calendarDelegate.isSameDay(
          widget.currentDate,
          dayToBuild,
        );

        dayItems.add(
          _Day(
            dayToBuild,
            key: ValueKey<DateTime>(dayToBuild),
            isDisabled: isDisabled,
            isSelectedDay: isSelectedDay,
            isToday: isToday,
            onChanged: widget.onChanged,
            focusNode: _dayFocusNodes[day - 1],
            calendarDelegate: widget.calendarDelegate,
          ),
        );
      }
    }

    final double monthPickerHorizontalPadding =
        Theme.of(context).useMaterial3 && !isLandscapeOrientation
        ? _monthPickerHorizontalPaddingPortraitM3
        : _monthPickerHorizontalPaddingOther;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: monthPickerHorizontalPadding),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: isLandscapeOrientation
            ? _kDayPickerGridLandscapeMaxScaleFactor
            : _kDayPickerGridPortraitMaxScaleFactor,
        child: GridView.custom(
          physics: const ClampingScrollPhysics(),
          gridDelegate: _DayPickerGridDelegate(context),
          childrenDelegate: SliverChildListDelegate(
            dayItems,
            addRepaintBoundaries: false,
          ),
        ),
      ),
    );
  }
}

class _Day extends StatefulWidget {
  const _Day(
    this.day, {
    super.key,
    required this.isDisabled,
    required this.isSelectedDay,
    required this.isToday,
    required this.onChanged,
    required this.focusNode,
    required this.calendarDelegate,
  });

  final DateTime day;
  final bool isDisabled;
  final bool isSelectedDay;
  final bool isToday;
  final ValueChanged<DateTime> onChanged;
  final FocusNode focusNode;
  final CalendarDelegate<DateTime> calendarDelegate;

  @override
  State<_Day> createState() => _DayState();
}

class _DayState extends State<_Day> {
  final WidgetStatesController _statesController = WidgetStatesController();

  @override
  Widget build(BuildContext context) {
    final DatePickerThemeData defaults = DatePickerTheme.defaults(context);
    final DatePickerThemeData datePickerTheme = DatePickerTheme.of(context);
    final TextStyle? dayStyle = datePickerTheme.dayStyle ?? defaults.dayStyle;
    T? effectiveValue<T>(T? Function(DatePickerThemeData? theme) getProperty) {
      return getProperty(datePickerTheme) ?? getProperty(defaults);
    }

    T? resolve<T>(
      WidgetStateProperty<T>? Function(DatePickerThemeData? theme) getProperty,
      Set<WidgetState> states,
    ) {
      return effectiveValue((DatePickerThemeData? theme) {
        return getProperty(theme)?.resolve(states);
      });
    }

    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final semanticLabelSuffix = widget.isToday
        ? ', ${localizations.currentDateLabel}'
        : '';

    final states = <WidgetState>{
      if (widget.isDisabled) WidgetState.disabled,
      if (widget.isSelectedDay) WidgetState.selected,
    };

    _statesController.value = states;

    final Color? dayForegroundColor = resolve<Color?>(
      (DatePickerThemeData? theme) => widget.isToday
          ? theme?.todayForegroundColor
          : theme?.dayForegroundColor,
      states,
    );
    final Color? dayBackgroundColor = resolve<Color?>(
      (DatePickerThemeData? theme) => widget.isToday
          ? theme?.todayBackgroundColor
          : theme?.dayBackgroundColor,
      states,
    );
    final WidgetStateProperty<Color?> dayOverlayColor =
        WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => effectiveValue(
            (DatePickerThemeData? theme) =>
                theme?.dayOverlayColor?.resolve(states),
          ),
        );
    final OutlinedBorder dayShape = resolve<OutlinedBorder?>(
      (DatePickerThemeData? theme) => theme?.dayShape,
      states,
    )!;
    final bool hasCustomBorderColor =
        datePickerTheme.todayBorder != null &&
        datePickerTheme.todayBorder!.color.a != 0.0;
    final BorderSide todayBorderSide = hasCustomBorderColor
        ? datePickerTheme.todayBorder!
        : (datePickerTheme.todayBorder ?? defaults.todayBorder!).copyWith(
            color: dayForegroundColor,
          );
    final decoration = widget.isToday
        ? ShapeDecoration(
            color: dayBackgroundColor,
            shape: dayShape.copyWith(side: todayBorderSide),
          )
        : ShapeDecoration(color: dayBackgroundColor, shape: dayShape);

    Widget dayWidget = Ink(
      decoration: decoration,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            localizations.formatDecimal(widget.day.day),
            style: dayStyle?.apply(color: dayForegroundColor),
          ),
        ),
      ),
    );

    // Adds padding as per M3 guidelines for portrait mode. Not applied in landscape
    // mode currently due to unclear specifications.
    final Orientation orientation = MediaQuery.orientationOf(context);
    if (Theme.of(context).useMaterial3 && orientation == Orientation.portrait) {
      dayWidget = Padding(padding: const EdgeInsets.all(4.0), child: dayWidget);
    }
    dayWidget = Semantics(
      // We want the day of month to be spoken first irrespective of the
      // locale-specific preferences or TextDirection. This is because
      // an accessibility user is more likely to be interested in the
      // day of month before the rest of the date, as they are looking
      // for the day of month. To do that we prepend day of month to the
      // formatted full date.
      label:
          '${localizations.formatDecimal(widget.day.day)}, ${widget.calendarDelegate.formatFullDate(widget.day, localizations)}$semanticLabelSuffix',
      // Set button to true to make the date selectable.
      button: true,
      selected: widget.isSelectedDay,
      enabled: !widget.isDisabled,
      excludeSemantics: true,
      child: dayWidget,
    );

    if (!widget.isDisabled) {
      dayWidget = InkResponse(
        focusNode: widget.focusNode,
        onTap: () => widget.onChanged(widget.day),
        statesController: _statesController,
        overlayColor: dayOverlayColor,
        customBorder: dayShape,
        containedInkWell: true,
        child: dayWidget,
      );
    }

    return dayWidget;
  }

  @override
  void dispose() {
    _statesController.dispose();
    super.dispose();
  }
}

class _DayPickerGridDelegate extends SliverGridDelegate {
  const _DayPickerGridDelegate(this.context);

  final BuildContext context;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final double textScaleFactor =
        MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 3.0).scale(_fontSizeToScale) /
        _fontSizeToScale;
    // Conform to M3 spec in portrait mode (landscape mode is not specified).
    final Orientation orientation = MediaQuery.orientationOf(context);
    final double dayPickerRowHeight =
        Theme.of(context).useMaterial3 && orientation == Orientation.portrait
        ? _dayPickerRowHeightM3
        : _dayPickerRowHeightM2;
    final double scaledRowHeight = textScaleFactor > 1.3
        ? ((textScaleFactor - 1) * 30) + dayPickerRowHeight
        : dayPickerRowHeight;
    const int columnCount = DateTime.daysPerWeek;
    final double tileWidth = constraints.crossAxisExtent / columnCount;
    final double tileHeight = math.min(
      scaledRowHeight,
      constraints.viewportMainAxisExtent / (_maxDayPickerRowCount + 1),
    );
    return SliverGridRegularTileLayout(
      childCrossAxisExtent: tileWidth,
      childMainAxisExtent: tileHeight,
      crossAxisCount: columnCount,
      crossAxisStride: tileWidth,
      mainAxisStride: tileHeight,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_DayPickerGridDelegate oldDelegate) => false;
}

/// A scrollable grid of years to allow picking a year.
///
/// The year picker widget is rarely used directly. Instead, consider using
/// [BilCrystalCalendarDatePicker], or [showDatePicker] which create full date pickers.
///
/// See also:
///
///  * [BilCrystalCalendarDatePicker], which provides a Material Design date picker
///    interface.
///
///  * [showDatePicker], which shows a dialog containing a Material Design
///    date picker.
///
