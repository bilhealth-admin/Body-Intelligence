// Copyright 2014 The Flutter Authors. All rights reserved.
// BSD-3-Clause; see LICENSE.flutter in this directory.
// Pinned Flutter 3.44.6 single-date picker; static BIL arrow decoration only.
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../bil_crystal_arrow.dart';

part 'bil_crystal_calendar_mode.dart';
part 'bil_crystal_calendar_month.dart';
part 'bil_crystal_calendar_day.dart';
part 'bil_crystal_calendar_year.dart';

const Duration _monthScrollDuration = Duration(milliseconds: 200);

// Current M2 implementation is not compliant with the M2 specification.
// Instead of a 42 pixels row height it should be 40 with a 2 pixels inner padding.
// See: https://m2.material.io/components/date-pickers#specs.
const double _dayPickerRowHeightM2 = 42.0;
// For M3, row height is 48 pxiels with 4 pixels inner padding.
// See: https://m3.material.io/components/date-pickers/specs#2d53890e-a08f-4c63-a0d9-abd9e95b4245.
const double _dayPickerRowHeightM3 = 48.0;

const int _maxDayPickerRowCount = 6; // A 31 day month that starts on Saturday.
// One extra row for the day-of-week header.
const double _maxDayPickerHeightM2 =
    _dayPickerRowHeightM2 * (_maxDayPickerRowCount + 1);
const double _maxDayPickerHeightM3 =
    _dayPickerRowHeightM3 * (_maxDayPickerRowCount + 1);

const double _monthPickerHorizontalPaddingPortraitM3 = 12.0;
const double _monthPickerHorizontalPaddingOther = 8.0;

const int _yearPickerColumnCount = 3;
const double _yearPickerPadding = 16.0;
const double _yearPickerRowHeight = 52.0;
const double _yearPickerRowSpacing = 8.0;

const double _subHeaderHeight = 52.0;
const double _monthNavButtonsWidth = 108.0;

// 3.0 is the maximum scale factor on mobile phones. As of 07/30/24, iOS goes up
// to a max of 3.0 text scale factor, and Android goes up to 2.0. This is the
// default used for non-range date pickers. This default is changed to a lower
// value at different parts of the date pickers depending on content, and device
// orientation.
const double _kMaxTextScaleFactor = 3.0;

const double _kModeToggleButtonMaxScaleFactor = 2.0;

// The max scale factor of the day picker grid. This affects the size of the
// individual days in calendar view. Due to them filling a majority of the modal,
// which covers most of the screen, there's a limit in how large they can grow.
// There is also less room vertically in landscape orientation.
const double _kDayPickerGridPortraitMaxScaleFactor = 2.0;
const double _kDayPickerGridLandscapeMaxScaleFactor = 1.5;

// 14 is a common font size used to compute the effective text scale.
const double _fontSizeToScale = 14.0;

/// Displays a grid of days for a given month and allows the user to select a
/// date.
///
/// Days are arranged in a rectangular grid with one column for each day of the
/// week. Controls are provided to change the year and month that the grid is
/// showing.
///
/// The calendar picker widget is rarely used directly. Instead, consider using
/// [showDatePicker], which will create a dialog that uses this as well as
/// provides a text entry option.
///
/// See also:
///
///  * [showDatePicker], which creates a Dialog that contains a
///    [CalendarDatePicker] and provides an optional compact view where the
///    user can enter a date as a line of text.
///  * [showTimePicker], which shows a dialog that contains a Material Design
///    time picker.
///
class BilCrystalCalendarDatePicker extends StatefulWidget {
  /// Creates a calendar date picker.
  ///
  /// It will display a grid of days for the [initialDate]'s month, or, if that
  /// is null, the [currentDate]'s month. The day indicated by [initialDate] will
  /// be selected if it is not null.
  ///
  /// The optional [onDisplayedMonthChanged] callback can be used to track
  /// the currently displayed month.
  ///
  /// The user interface provides a way to change the year of the month being
  /// displayed. By default it will show the day grid, but this can be changed
  /// to start in the year selection interface with [initialCalendarMode] set
  /// to [DatePickerMode.year].
  ///
  /// The [lastDate] must be after or equal to [firstDate].
  ///
  /// The [initialDate], if provided, must be between [firstDate] and [lastDate]
  /// or equal to one of them.
  ///
  /// The [currentDate] represents the current day (i.e. today). This
  /// date will be highlighted in the day grid. If null, the date of
  /// `DateTime.now()` will be used.
  ///
  /// If [selectableDayPredicate] and [initialDate] are both non-null,
  /// [selectableDayPredicate] must return `true` for the [initialDate].
  ///
  /// {@template flutter.material.calendar_date_picker.calendarDelegate}
  /// The [calendarDelegate] controls date interpretation, formatting, and
  /// navigation within the picker. By providing a custom implementation,
  /// you can support alternative calendar systems such as Nepali, Hijri,
  /// Buddhist, and more. Defaults to [GregorianCalendarDelegate].
  /// {@endtemplate}
  BilCrystalCalendarDatePicker({
    super.key,
    required DateTime? initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    DateTime? currentDate,
    required this.onDateChanged,
    this.onDisplayedMonthChanged,
    this.initialCalendarMode = DatePickerMode.day,
    this.selectableDayPredicate,
    this.calendarDelegate = const GregorianCalendarDelegate(),
  }) : initialDate = initialDate == null
           ? null
           : calendarDelegate.dateOnly(initialDate),
       firstDate = calendarDelegate.dateOnly(firstDate),
       lastDate = calendarDelegate.dateOnly(lastDate),
       currentDate = calendarDelegate.dateOnly(
         currentDate ?? calendarDelegate.now(),
       ) {
    assert(
      !this.lastDate.isBefore(this.firstDate),
      'lastDate ${this.lastDate} must be on or after firstDate ${this.firstDate}.',
    );
    assert(
      this.initialDate == null || !this.initialDate!.isBefore(this.firstDate),
      'initialDate ${this.initialDate} must be on or after firstDate ${this.firstDate}.',
    );
    assert(
      this.initialDate == null || !this.initialDate!.isAfter(this.lastDate),
      'initialDate ${this.initialDate} must be on or before lastDate ${this.lastDate}.',
    );
    assert(
      selectableDayPredicate == null ||
          this.initialDate == null ||
          selectableDayPredicate!(this.initialDate!),
      'Provided initialDate ${this.initialDate} must satisfy provided selectableDayPredicate.',
    );
  }

  /// The initially selected [DateTime] that the picker should display.
  ///
  /// Subsequently changing this has no effect. To change the selected date,
  /// change the [key] to create a new instance of the [BilCrystalCalendarDatePicker], and
  /// provide that widget the new [initialDate]. This will reset the widget's
  /// interactive state.
  final DateTime? initialDate;

  /// The earliest allowable [DateTime] that the user can select.
  final DateTime firstDate;

  /// The latest allowable [DateTime] that the user can select.
  final DateTime lastDate;

  /// The [DateTime] representing today. It will be highlighted in the day grid.
  final DateTime currentDate;

  /// Called when the user selects a date in the picker.
  final ValueChanged<DateTime> onDateChanged;

  /// Called when the user navigates to a new month/year in the picker.
  final ValueChanged<DateTime>? onDisplayedMonthChanged;

  /// The initial display of the calendar picker.
  ///
  /// Subsequently changing this has no effect. To change the calendar mode,
  /// change the [key] to create a new instance of the [BilCrystalCalendarDatePicker], and
  /// provide that widget a new [initialCalendarMode]. This will reset the
  /// widget's interactive state.
  final DatePickerMode initialCalendarMode;

  /// Function to provide full control over which dates in the calendar can be selected.
  final SelectableDayPredicate? selectableDayPredicate;

  /// {@macro flutter.material.calendar_date_picker.calendarDelegate}
  final CalendarDelegate<DateTime> calendarDelegate;

  @override
  State<BilCrystalCalendarDatePicker> createState() =>
      _CalendarDatePickerState();
}

class _CalendarDatePickerState extends State<BilCrystalCalendarDatePicker> {
  bool _announcedInitialDate = false;
  String _announcementText = '';
  late DatePickerMode _mode;
  late DateTime _currentDisplayedMonthDate;
  DateTime? _selectedDate;
  final GlobalKey _monthPickerKey = GlobalKey();
  final GlobalKey _yearPickerKey = GlobalKey();
  late MaterialLocalizations _localizations;
  late TextDirection _textDirection;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialCalendarMode;
    final DateTime currentDisplayedDate =
        widget.initialDate ?? widget.currentDate;
    _currentDisplayedMonthDate = widget.calendarDelegate.getMonth(
      currentDisplayedDate.year,
      currentDisplayedDate.month,
    );
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasDirectionality(context));
    _localizations = MaterialLocalizations.of(context);
    _textDirection = Directionality.of(context);
    if (!_announcedInitialDate && widget.initialDate != null) {
      assert(_selectedDate != null);
      _announcedInitialDate = true;
      final bool isToday = widget.calendarDelegate.isSameDay(
        widget.currentDate,
        _selectedDate,
      );
      final semanticLabelSuffix = isToday
          ? ', ${_localizations.currentDateLabel}'
          : '';
      _announce(
        '${_localizations.formatFullDate(_selectedDate!)}$semanticLabelSuffix',
      );
    }
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

  void _vibrate() {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        HapticFeedback.vibrate();
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        break;
    }
  }

  void _handleModeChanged(DatePickerMode mode) {
    _vibrate();
    setState(() {
      _mode = mode;
      if (_selectedDate case final DateTime selected) {
        final String message = switch (mode) {
          DatePickerMode.day => widget.calendarDelegate.formatMonthYear(
            selected,
            _localizations,
          ),
          DatePickerMode.year => widget.calendarDelegate.formatYear(
            selected.year,
            _localizations,
          ),
        };
        _announce(message);
      }
    });
  }

  void _handleMonthChanged(DateTime date) {
    setState(() {
      if (_currentDisplayedMonthDate.year != date.year ||
          _currentDisplayedMonthDate.month != date.month) {
        _currentDisplayedMonthDate = widget.calendarDelegate.getMonth(
          date.year,
          date.month,
        );
        widget.onDisplayedMonthChanged?.call(_currentDisplayedMonthDate);
      }
    });
  }

  void _handleYearChanged(DateTime value) {
    _vibrate();

    final int daysInMonth = widget.calendarDelegate.getDaysInMonth(
      value.year,
      value.month,
    );
    final int preferredDay = math.min(_selectedDate?.day ?? 1, daysInMonth);
    value = widget.calendarDelegate.getDay(
      value.year,
      value.month,
      preferredDay,
    );

    if (value.isBefore(widget.firstDate)) {
      value = widget.firstDate;
    } else if (value.isAfter(widget.lastDate)) {
      value = widget.lastDate;
    }

    setState(() {
      _mode = DatePickerMode.day;
      _handleMonthChanged(value);

      if (_isSelectable(value)) {
        _selectedDate = value;
        widget.onDateChanged(_selectedDate!);
      }
    });
  }

  void _handleDayChanged(DateTime value) {
    _vibrate();
    setState(() {
      _selectedDate = value;
      widget.onDateChanged(_selectedDate!);
      switch (Theme.of(context).platform) {
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          final bool isToday = widget.calendarDelegate.isSameDay(
            widget.currentDate,
            _selectedDate,
          );
          final semanticLabelSuffix = isToday
              ? ', ${_localizations.currentDateLabel}'
              : '';
          SemanticsService.sendAnnouncement(
            View.of(context),
            '${_localizations.selectedDateLabel} ${widget.calendarDelegate.formatFullDate(_selectedDate!, _localizations)}$semanticLabelSuffix',
            _textDirection,
          ).catchError(_reportAnnouncementError);
        case TargetPlatform.android:
        case TargetPlatform.iOS:
        case TargetPlatform.fuchsia:
          break;
      }
    });
  }

  bool _isSelectable(DateTime date) {
    return widget.selectableDayPredicate?.call(date) ?? true;
  }

  Widget _buildPicker() {
    switch (_mode) {
      case DatePickerMode.day:
        return _MonthPicker(
          key: _monthPickerKey,
          calendarDelegate: widget.calendarDelegate,
          initialMonth: _currentDisplayedMonthDate,
          currentDate: widget.currentDate,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          selectedDate: _selectedDate,
          onChanged: _handleDayChanged,
          onDisplayedMonthChanged: _handleMonthChanged,
          selectableDayPredicate: widget.selectableDayPredicate,
        );
      case DatePickerMode.year:
        return Padding(
          padding: const EdgeInsets.only(top: _subHeaderHeight),
          child: BilCrystalYearPicker(
            key: _yearPickerKey,
            calendarDelegate: widget.calendarDelegate,
            currentDate: widget.currentDate,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            selectedDate: _currentDisplayedMonthDate,
            onChanged: _handleYearChanged,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterial(context));
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasDirectionality(context));
    final double textScaleFactor =
        MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: _kMaxTextScaleFactor).scale(_fontSizeToScale) /
        _fontSizeToScale;

    // Conform to M3 spec in portrait mode (landscape mode is not specified).
    final Orientation orientation = MediaQuery.orientationOf(context);
    final double maxDayPickerHeight =
        Theme.of(context).useMaterial3 && orientation == Orientation.portrait
        ? _maxDayPickerHeightM3
        : _maxDayPickerHeightM2;

    // Scale the height of the picker area up with larger text. The size of the
    // picker has room for larger text, up until a scale factor of 1.3. After
    // after which, we increase the height to add room for content to continue
    // to scale the text size.
    final double scaledMaxDayPickerHeight = textScaleFactor > 1.3
        ? maxDayPickerHeight +
              ((_maxDayPickerRowCount + 1) * ((textScaleFactor - 1) * 8))
        : maxDayPickerHeight;
    final picker = SizedBox(
      height: _subHeaderHeight + scaledMaxDayPickerHeight,
      child: _buildPicker(),
    );
    return Stack(
      children: <Widget>[
        if (MediaQuery.maybeSupportsAnnounceOf(context) ?? false)
          picker
        else
          Semantics(
            container: true,
            liveRegion: true,
            accessibilityFocusBlockType: AccessibilityFocusBlockType.blockNode,
            label: _announcementText,
            child: picker,
          ),

        // Put the mode toggle button on top so that it won't be covered up by the _MonthPicker
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: _kModeToggleButtonMaxScaleFactor,
          child: _DatePickerModeToggleButton(
            mode: _mode,
            title: widget.calendarDelegate.formatMonthYear(
              _currentDisplayedMonthDate,
              _localizations,
            ),
            onTitlePressed: () => _handleModeChanged(switch (_mode) {
              DatePickerMode.day => DatePickerMode.year,
              DatePickerMode.year => DatePickerMode.day,
            }),
          ),
        ),
      ],
    );
  }
}

/// A button that used to toggle the [DatePickerMode] for a date picker.
///
/// This appears above the calendar grid and allows the user to toggle the
/// [DatePickerMode] to display either the calendar view or the year list.
