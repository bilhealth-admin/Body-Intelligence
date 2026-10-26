// Copyright 2014 The Flutter Authors. All rights reserved.
// BSD-3-Clause; see LICENSE.flutter in this directory.
// Pinned Flutter 3.44.6 single-date picker; static BIL arrow decoration only.
part of 'bil_crystal_calendar_date_picker.dart';

class BilCrystalYearPicker extends StatefulWidget {
  /// Creates a year picker.
  ///
  /// The [lastDate] must be after the [firstDate].
  BilCrystalYearPicker({
    super.key,
    DateTime? currentDate,
    required this.firstDate,
    required this.lastDate,
    @Deprecated(
      'This parameter has no effect and can be removed. Previously it controlled '
      'the month that was used in "onChanged" when a new year was selected, but '
      'now that role is filled by "selectedDate" instead. '
      'This feature was deprecated after v3.13.0-0.3.pre.',
    )
    DateTime? initialDate,
    required this.selectedDate,
    required this.onChanged,
    this.dragStartBehavior = DragStartBehavior.start,
    this.calendarDelegate = const GregorianCalendarDelegate(),
  }) : assert(!firstDate.isAfter(lastDate)),
       currentDate = calendarDelegate.dateOnly(currentDate ?? DateTime.now());

  /// The current date.
  ///
  /// This date is subtly highlighted in the picker.
  final DateTime currentDate;

  /// The earliest date the user is permitted to pick.
  final DateTime firstDate;

  /// The latest date the user is permitted to pick.
  final DateTime lastDate;

  /// The currently selected date.
  ///
  /// This date is highlighted in the picker.
  final DateTime? selectedDate;

  /// Called when the user picks a year.
  final ValueChanged<DateTime> onChanged;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@macro flutter.material.calendar_date_picker.calendarDelegate}
  final CalendarDelegate<DateTime> calendarDelegate;

  @override
  State<BilCrystalYearPicker> createState() => _YearPickerState();
}

class _YearPickerState extends State<BilCrystalYearPicker> {
  ScrollController? _scrollController;
  final WidgetStatesController _statesController = WidgetStatesController();

  // The approximate number of years necessary to fill the available space.
  static const int minYears = 18;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _scrollOffsetForYear(
        widget.selectedDate ?? widget.firstDate,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    _statesController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BilCrystalYearPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate &&
        widget.selectedDate != null) {
      _scrollController!.jumpTo(_scrollOffsetForYear(widget.selectedDate!));
    }
  }

  double _scrollOffsetForYear(DateTime date) {
    final int initialYearIndex = date.year - widget.firstDate.year;
    final int initialYearRow = initialYearIndex ~/ _yearPickerColumnCount;
    // Move the offset down by 2 rows to approximately center it.
    final int centeredYearRow = initialYearRow - 2;
    return _itemCount < minYears ? 0 : centeredYearRow * _yearPickerRowHeight;
  }

  Widget _buildYearItem(BuildContext context, int index) {
    final DatePickerThemeData datePickerTheme = DatePickerTheme.of(context);
    final DatePickerThemeData defaults = DatePickerTheme.defaults(context);

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

    final double textScaleFactor =
        MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 3.0).scale(_fontSizeToScale) /
        _fontSizeToScale;

    // Backfill the _YearPicker with disabled years if necessary.
    final int offset = _itemCount < minYears ? (minYears - _itemCount) ~/ 2 : 0;
    final int year = widget.firstDate.year + index - offset;
    final isSelected = year == widget.selectedDate?.year;
    final isCurrentYear = year == widget.currentDate.year;
    final bool isDisabled =
        year < widget.firstDate.year || year > widget.lastDate.year;
    final double decorationHeight = 36.0 * textScaleFactor;
    final double decorationWidth = 72.0 * textScaleFactor;

    final states = <WidgetState>{
      if (isDisabled) WidgetState.disabled,
      if (isSelected) WidgetState.selected,
    };

    final Color? textColor = resolve<Color?>(
      (DatePickerThemeData? theme) => isCurrentYear
          ? theme?.todayForegroundColor
          : theme?.yearForegroundColor,
      states,
    );
    final Color? background = resolve<Color?>(
      (DatePickerThemeData? theme) => isCurrentYear
          ? theme?.todayBackgroundColor
          : theme?.yearBackgroundColor,
      states,
    );
    final WidgetStateProperty<Color?> overlayColor =
        WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => effectiveValue(
            (DatePickerThemeData? theme) =>
                theme?.yearOverlayColor?.resolve(states),
          ),
        );

    final OutlinedBorder yearShape = resolve<OutlinedBorder?>(
      (DatePickerThemeData? theme) => theme?.yearShape,
      states,
    )!;

    BorderSide? borderSide;
    if (isCurrentYear) {
      borderSide = datePickerTheme.todayBorder ?? defaults.todayBorder;
      if (borderSide != null) {
        borderSide = borderSide.copyWith(color: textColor);
      }
    }
    final decoration = ShapeDecoration(
      color: background,
      shape: yearShape.copyWith(side: borderSide),
    );

    final TextStyle? itemStyle =
        (datePickerTheme.yearStyle ?? defaults.yearStyle)?.apply(
          color: textColor,
        );
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    Widget yearItem = Center(
      child: Container(
        decoration: decoration,
        height: decorationHeight,
        width: decorationWidth,
        alignment: Alignment.center,
        child: Semantics(
          selected: isSelected,
          enabled: !isDisabled,
          button: true,
          child: Text(
            widget.calendarDelegate.formatYear(year, localizations),
            style: itemStyle,
          ),
        ),
      ),
    );

    if (!isDisabled) {
      DateTime date = widget.calendarDelegate.getMonth(
        year,
        widget.selectedDate?.month ?? DateTime.january,
      );
      if (date.isBefore(
        widget.calendarDelegate.getMonth(
          widget.firstDate.year,
          widget.firstDate.month,
        ),
      )) {
        // Ignore firstDate.day because we're just working in years and months here.
        assert(date.year == widget.firstDate.year);
        date = widget.calendarDelegate.getMonth(year, widget.firstDate.month);
      } else if (date.isAfter(widget.lastDate)) {
        // No need to ignore the day here because it can only be bigger than what we care about.
        assert(date.year == widget.lastDate.year);
        date = widget.calendarDelegate.getMonth(year, widget.lastDate.month);
      }
      _statesController.value = states;
      yearItem = InkWell(
        key: ValueKey<int>(year),
        onTap: () => widget.onChanged(date),
        statesController: _statesController,
        overlayColor: overlayColor,
        child: yearItem,
      );
    }

    return yearItem;
  }

  int get _itemCount {
    return widget.lastDate.year - widget.firstDate.year + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Divider(),
        Expanded(
          child: Material(
            type: MaterialType.transparency,
            child: GridView.builder(
              controller: _scrollController,
              dragStartBehavior: widget.dragStartBehavior,
              gridDelegate: _YearPickerGridDelegate(context),
              itemBuilder: _buildYearItem,
              itemCount: math.max(_itemCount, minYears),
              padding: const EdgeInsets.symmetric(
                horizontal: _yearPickerPadding,
              ),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}

class _YearPickerGridDelegate extends SliverGridDelegate {
  const _YearPickerGridDelegate(this.context);

  final BuildContext context;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final double textScaleFactor =
        MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 3.0).scale(_fontSizeToScale) /
        _fontSizeToScale;
    final int scaledYearPickerColumnCount = textScaleFactor > 1.65
        ? _yearPickerColumnCount - 1
        : _yearPickerColumnCount;
    final double tileWidth = math.max(
      (constraints.crossAxisExtent -
              (scaledYearPickerColumnCount - 1) * _yearPickerRowSpacing) /
          scaledYearPickerColumnCount,
      0.0,
    );
    final double scaledYearPickerRowHeight = textScaleFactor > 1
        ? _yearPickerRowHeight + ((textScaleFactor - 1) * 9)
        : _yearPickerRowHeight;
    return SliverGridRegularTileLayout(
      childCrossAxisExtent: tileWidth,
      childMainAxisExtent: scaledYearPickerRowHeight,
      crossAxisCount: scaledYearPickerColumnCount,
      crossAxisStride: tileWidth + _yearPickerRowSpacing,
      mainAxisStride: scaledYearPickerRowHeight,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_YearPickerGridDelegate oldDelegate) => false;
}

void _reportAnnouncementError(Object exception, StackTrace stack) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: exception,
      stack: stack,
      library: 'material library',
      context: ErrorDescription('while sending semantics announcement'),
    ),
  );
}
