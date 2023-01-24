// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import './pdate_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:persian_datetime_picker/src/date/shamsi_date.dart';

import 'pdate_picker_common.dart';
import 'pdate_utils.dart' as utils;

const Duration _monthScrollDuration = Duration(milliseconds: 200);

const double _dayPickerRowHeight = 42.0;
const int _maxDayPickerRowCount = 6; // A 31 day month that starts on Saturday.
// One extra row for the day-of-week header.
const double _maxDayPickerHeight = _dayPickerRowHeight * (_maxDayPickerRowCount + 1);
const double _monthPickerHorizontalPadding = 8.0;

const int _yearPickerColumnCount = 3;
const double _yearPickerPadding = 16.0;
const double _yearPickerRowHeight = 52.0;
const double _yearPickerRowSpacing = 8.0;

const double _subHeaderHeight = 52.0;

/// Displays a grid of days for a given month and allows the user to select a date.
///
/// Days are arranged in a rectangular grid with one column for each day of the
/// week. Controls are provided to change the year and month that the grid is
/// showing.
///
/// The calendar picker widget is rarely used directly. Instead, consider using
/// [showDatePicker], which will create a dialog that uses this as well as provides
/// a text entry option.
///
/// See also:
///
///  * [showDatePicker], which creates a Dialog that contains a [CalendarDatePicker]
///    and provides an optional compact view where the user can enter a date as
///    a line of text.
///  * [showTimePicker], which shows a dialog that contains a material design
///    time picker.
///
class PCalendarDatePicker extends StatefulWidget {
  /// Creates a calender date picker
  ///
  /// It will display a grid of days for the [initialDate]'s month. The day
  /// indicated by [initialDate] will be selected.
  ///
  /// The optional [onDisplayedMonthChanged] callback can be used to track
  /// the currently displayed month.
  ///
  /// The user interface provides a way to change the year of the month being
  /// displayed. By default it will show the day grid, but this can be changed
  /// to start in the year selection interface with [initialCalendarMode] set
  /// to [PDatePickerMode.year].
  ///
  /// The [initialDate], [firstDate], [lastDate], [onDateChanged], and
  /// [initialCalendarMode] must be non-null.
  ///
  /// [lastDate] must be after or equal to [firstDate].
  ///
  /// [initialDate] must be between [firstDate] and [lastDate] or equal to
  /// one of them.
  ///
  /// If [selectableDayPredicate] is non-null, it must return `true` for the
  /// [initialDate].
  PCalendarDatePicker({
    Key? key,
    required Jalali initialDate,
    required Jalali firstDate,
    required Jalali lastDate,
    required this.onDateChanged,
    this.onDisplayedMonthChanged,
    this.initialCalendarMode = PDatePickerMode.day,
    this.selectableDayPredicate,
  })  : initialDate = utils.dateOnly(initialDate),
        firstDate = utils.dateOnly(firstDate),
        lastDate = utils.dateOnly(lastDate),
        super(key: key) {
    assert(!this.lastDate.isBefore(this.firstDate),
        'lastDate ${this.lastDate} must be on or after firstDate ${this.firstDate}.');
    assert(!this.initialDate.isBefore(this.firstDate),
        'initialDate ${this.initialDate} must be on or after firstDate ${this.firstDate}.');
    assert(!this.initialDate.isAfter(this.lastDate),
        'initialDate ${this.initialDate} must be on or before lastDate ${this.lastDate}.');
    assert(selectableDayPredicate == null || selectableDayPredicate!(this.initialDate),
        'Provided initialDate ${this.initialDate} must satisfy provided selectableDayPredicate.');
  }

  /// The initially selected [Jalali] that the picker should display.
  final Jalali initialDate;

  /// The earliest allowable [Jalali] that the user can select.
  final Jalali firstDate;

  /// The latest allowable [Jalali] that the user can select.
  final Jalali lastDate;

  /// Called when the user selects a date in the picker.
  final ValueChanged<Jalali?> onDateChanged;

  /// Called when the user navigates to a new month/year in the picker.
  final ValueChanged<Jalali?>? onDisplayedMonthChanged;

  /// The initial display of the calendar picker.
  final PDatePickerMode initialCalendarMode;

  /// Function to provide full control over which dates in the calendar can be selected.
  final PSelectableDayPredicate? selectableDayPredicate;

  @override
  State<PCalendarDatePicker> createState() => _CalendarDatePickerState();
}

class _CalendarDatePickerState extends State<PCalendarDatePicker> {
  bool _announcedInitialDate = false;
  PDatePickerMode? _mode;
  Jalali? _currentDisplayedDate;
  Jalali? _selectedDate;
  final GlobalKey _monthPickerKey = GlobalKey();
  final GlobalKey _yearPickerKey = GlobalKey();
  late TextDirection _textDirection;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialCalendarMode;
    _currentDisplayedDate = Jalali(widget.initialDate.year, widget.initialDate.month);
    _selectedDate = widget.initialDate;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _textDirection = Directionality.of(context);
    if (!_announcedInitialDate) {
      _announcedInitialDate = true;
      SemanticsService.announce(
        formatFullDate(_selectedDate!),
        _textDirection,
      );
    }
  }

  void _handleModeChanged(PDatePickerMode mode) {
    setState(() {
      _mode = mode;
      if (_mode == PDatePickerMode.day) {
        SemanticsService.announce(
          formatMonthYear(_selectedDate!),
          _textDirection,
        );
      } else if (_mode == PDatePickerMode.month) {
        SemanticsService.announce(
          formatYear(_selectedDate!),
          _textDirection,
        );
      } else {
        SemanticsService.announce(
          formatYear(_selectedDate!),
          _textDirection,
        );
      }
    });
  }

  void _handleMonthChanged(Jalali? date) {
    setState(() {
      _mode = PDatePickerMode.day;
      if (_currentDisplayedDate!.year != date!.year || _currentDisplayedDate!.month != date.month) {
        _currentDisplayedDate = Jalali(date.year, date.month, date.day);
        widget.onDisplayedMonthChanged?.call(_currentDisplayedDate);
      }
    });
  }

  void _handleYearChanged(Jalali value) {
    setState(() {
      _mode = PDatePickerMode.month;
      if (_currentDisplayedDate!.year != value.year) {
        _currentDisplayedDate = Jalali(value.year, value.month, value.day);
        widget.onDisplayedMonthChanged?.call(_currentDisplayedDate);
      }
    });
  }

  void _handleDayChanged(Jalali value) {
    setState(() {
      _currentDisplayedDate = value;
      _selectedDate = value;
      widget.onDisplayedMonthChanged?.call(_currentDisplayedDate);
      widget.onDateChanged.call(_currentDisplayedDate);
    });
  }

  Widget? _buildPicker() {
    assert(_mode != null);
    switch (_mode) {
      case PDatePickerMode.day:
        return _MonthPicker(
          key: _monthPickerKey,
          initialMonth: _currentDisplayedDate,
          currentDate: Jalali.now(),
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          selectedDate: _selectedDate!,
          onChanged: _handleDayChanged,
          onDisplayedMonthChanged: _handleMonthChanged,
          selectableDayPredicate: widget.selectableDayPredicate,
        );
      case PDatePickerMode.month:
        return Padding(
          padding: const EdgeInsets.only(top: _subHeaderHeight),
          child: _MonthsSelecting(
            key: _yearPickerKey,
            currentDate: Jalali.now(),
            currentDisplayedDate: _currentDisplayedDate,
            selectedDate: _selectedDate!,
            onChanged: _handleMonthChanged,
          ),
        );

      case PDatePickerMode.year:
        return Padding(
          padding: const EdgeInsets.only(top: _subHeaderHeight),
          child: _YearPicker(
            key: _yearPickerKey,
            currentDate: Jalali.now(),
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            currentDisplayedDate: _currentDisplayedDate!,
            selectedDate: _selectedDate!,
            onChanged: _handleYearChanged,
          ),
        );

      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          child: SizedBox(
            height: _maxDayPickerHeight,
            child: _buildPicker(),
          ),
        ),
        // Put the mode toggle button on top so that it won't be covered up by the _MonthPicker
        _DatePickerModeToggleButton(
          mode: _mode,
          currentSelectedMonth: _currentDisplayedDate!,
          onYearPressed: () {
            _handleModeChanged(PDatePickerMode.year);
          },
          onMonthPressed: () {
            _handleModeChanged(PDatePickerMode.month);
          },
          onDayPressed: () {
            _handleModeChanged(PDatePickerMode.day);
          },
        ),
      ],
    );
  }
}

/// A button that used to toggle the [PDatePickerMode] for a date picker.
///
/// This appears above the calendar grid and allows the user to toggle the
/// [PDatePickerMode] to display either the calendar view or the year list.
class _DatePickerModeToggleButton extends StatefulWidget {
  const _DatePickerModeToggleButton({
    required this.mode,
    required this.currentSelectedMonth,
    required this.onYearPressed,
    required this.onMonthPressed,
    required this.onDayPressed,
  });

  /// The current display of the calendar picker.
  final PDatePickerMode? mode;

  /// The current selected month
  final Jalali currentSelectedMonth;

  /// The callback when the year is pressed.
  final VoidCallback onYearPressed;

  /// The callback when the month is pressed.
  final VoidCallback onMonthPressed;

  /// The callback when the day is pressed.
  final VoidCallback onDayPressed;

  @override
  _DatePickerModeToggleButtonState createState() => _DatePickerModeToggleButtonState();
}

class _DatePickerModeToggleButtonState extends State<_DatePickerModeToggleButton> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      height: _subHeaderHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          _buildDatePickerModeItem(
            title: widget.currentSelectedMonth.day.toString(),
            mode: PDatePickerMode.day,
            onPressed: widget.onDayPressed,
          ),
          _buildDatePickerModeItem(
            title: widget.currentSelectedMonth.formatter.mN.toString(),
            mode: PDatePickerMode.month,
            onPressed: widget.onMonthPressed,
          ),
          _buildDatePickerModeItem(
            title: widget.currentSelectedMonth.year.toString(),
            mode: PDatePickerMode.year,
            onPressed: widget.onYearPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerModeItem({
    required String title,
    required PDatePickerMode mode,
    required Function() onPressed,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color controlColor = colorScheme.onSurface.withOpacity(0.60);
    final Color enabledDatePickerModeColor = colorScheme.primary;

    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        side: MaterialStatePropertyAll(
          BorderSide(
            color: widget.mode == mode ? enabledDatePickerModeColor : Colors.transparent,
          ),
        ),
        padding: const MaterialStatePropertyAll(EdgeInsets.zero),
        backgroundColor: MaterialStatePropertyAll(
          widget.mode == mode ? enabledDatePickerModeColor.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: textTheme.subtitle1?.copyWith(
          color: controlColor,
        ),
      ),
    );
  }
}

class _MonthPicker extends StatefulWidget {
  /// Creates a month picker.
  _MonthPicker({
    Key? key,
    required this.initialMonth,
    required this.currentDate,
    required this.firstDate,
    required this.lastDate,
    required this.selectedDate,
    required this.onChanged,
    required this.onDisplayedMonthChanged,
    this.selectableDayPredicate,
  })  : assert(!firstDate.isAfter(lastDate)),
        assert(!selectedDate.isBefore(firstDate)),
        assert(!selectedDate.isAfter(lastDate)),
        super(key: key);

  /// The initial month to display
  final Jalali? initialMonth;

  /// The current date.
  ///
  /// This date is subtly highlighted in the picker.
  final Jalali currentDate;

  /// The earliest date the user is permitted to pick.
  ///
  /// This date must be on or before the [lastDate].
  final Jalali firstDate;

  /// The latest date the user is permitted to pick.
  ///
  /// This date must be on or after the [firstDate].
  final Jalali lastDate;

  /// The currently selected date.
  ///
  /// This date is highlighted in the picker.
  final Jalali selectedDate;

  /// Called when the user picks a day.
  final ValueChanged<Jalali> onChanged;

  /// Called when the user navigates to a new month
  final ValueChanged<Jalali?> onDisplayedMonthChanged;

  /// Optional user supplied predicate function to customize selectable days.
  final PSelectableDayPredicate? selectableDayPredicate;

  @override
  State<StatefulWidget> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  Jalali? _currentMonth;
  late Jalali _nextMonthDate;
  late Jalali _previousMonthDate;
  PageController? _pageController;
  late TextDirection _textDirection;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialMonth;
    _previousMonthDate = utils.addMonthsToMonthDate(_currentMonth!, -1);
    _nextMonthDate = utils.addMonthsToMonthDate(_currentMonth!, 1);
    _pageController = PageController(initialPage: utils.monthDelta(widget.firstDate, _currentMonth!));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _textDirection = Directionality.of(context);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _handleMonthPageChanged(int monthPage) {
    final Jalali monthDate = utils.addMonthsToMonthDate(widget.firstDate, monthPage);
    if (_currentMonth!.year != monthDate.year || _currentMonth!.month != monthDate.month) {
      _currentMonth = Jalali(monthDate.year, monthDate.month);
      _previousMonthDate = utils.addMonthsToMonthDate(_currentMonth!, -1);
      _nextMonthDate = utils.addMonthsToMonthDate(_currentMonth!, 1);
      widget.onDisplayedMonthChanged.call(_currentMonth);
    }
  }

  void _handleNextMonth() {
    if (!_isDisplayingLastMonth) {
      SemanticsService.announce(
        formatMonthYear(_nextMonthDate),
        _textDirection,
      );
      _pageController!.nextPage(
        duration: _monthScrollDuration,
        curve: Curves.ease,
      );
    }
  }

  void _handlePreviousMonth() {
    if (!_isDisplayingFirstMonth) {
      SemanticsService.announce(
        formatMonthYear(_previousMonthDate),
        _textDirection,
      );
      _pageController!.previousPage(
        duration: _monthScrollDuration,
        curve: Curves.ease,
      );
    }
  }

  /// True if the earliest allowable month is displayed.
  bool get _isDisplayingFirstMonth {
    return !_currentMonth!.isAfter(
      Jalali(widget.firstDate.year, widget.firstDate.month),
    );
  }

  /// True if the latest allowable month is displayed.
  bool get _isDisplayingLastMonth {
    return !_currentMonth!.isBefore(
      Jalali(widget.lastDate.year, widget.lastDate.month),
    );
  }

  Widget _buildItems(BuildContext context, int index) {
    final Jalali month = utils.addMonthsToMonthDate(widget.firstDate, index);
    return _DayPicker(
      key: ValueKey<Jalali>(month),
      selectedDate: widget.selectedDate,
      currentDate: widget.currentDate,
      onChanged: widget.onChanged,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      displayedMonth: month,
      selectableDayPredicate: widget.selectableDayPredicate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String previousTooltipText = 'ماه قبل ${_previousMonthDate.formatMonthYear()}';
    final String nextTooltipText = 'ماه بعد ${_nextMonthDate.formatMonthYear()}';
    final Color controlColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.60);

    return Semantics(
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
            height: _subHeaderHeight,
            /* child: Row(
              children: <Widget>[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: controlColor,
                  tooltip: _isDisplayingFirstMonth ? null : previousTooltipText,
                  onPressed:
                      _isDisplayingFirstMonth ? null : _handlePreviousMonth,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: controlColor,
                  tooltip: _isDisplayingLastMonth ? null : nextTooltipText,
                  onPressed: _isDisplayingLastMonth ? null : _handleNextMonth,
                ),
              ],
            ), */
          ),
          _DayHeaders(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemBuilder: _buildItems,
              itemCount: utils.monthDelta(widget.firstDate, widget.lastDate) + 1,
              scrollDirection: Axis.horizontal,
              onPageChanged: _handleMonthPageChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays the days of a given month and allows choosing a day.
///
/// The days are arranged in a rectangular grid with one column for each day of
/// the week.
class _DayPicker extends StatelessWidget {
  /// Creates a day picker.
  _DayPicker({
    Key? key,
    required this.currentDate,
    required this.displayedMonth,
    required this.firstDate,
    required this.lastDate,
    required this.selectedDate,
    required this.onChanged,
    this.selectableDayPredicate,
  })  : assert(!firstDate.isAfter(lastDate)),
        assert(!selectedDate.isBefore(firstDate)),
        assert(!selectedDate.isAfter(lastDate)),
        super(key: key);

  /// The currently selected date.
  ///
  /// This date is highlighted in the picker.
  final Jalali selectedDate;

  /// The current date at the time the picker is displayed.
  final Jalali currentDate;

  /// Called when the user picks a day.
  final ValueChanged<Jalali> onChanged;

  /// The earliest date the user is permitted to pick.
  ///
  /// This date must be on or before the [lastDate].
  final Jalali firstDate;

  /// The latest date the user is permitted to pick.
  ///
  /// This date must be on or after the [firstDate].
  final Jalali lastDate;

  /// The month whose days are displayed by this picker.
  final Jalali displayedMonth;

  /// Optional user supplied predicate function to customize selectable days.
  final PSelectableDayPredicate? selectableDayPredicate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle? dayStyle = textTheme.caption;
    final Color enabledDayColor = colorScheme.onSurface.withOpacity(0.87);
    final Color disabledDayColor = colorScheme.onSurface.withOpacity(0.38);
    final Color selectedDayColor = colorScheme.onPrimary;
    final Color selectedDayBackground = colorScheme.primary;
    final Color todayColor = colorScheme.primary;

    final int year = displayedMonth.year;
    final int month = displayedMonth.month;

    final int daysInMonth = utils.getDaysInMonth(year, month);
    final int dayOffset = utils.firstDayOffset(year, month);

    final List<Widget> dayItems = <Widget>[];
    // 1-based day of month, e.g. 1-31 for January, and 1-29 for February on
    // a leap year.
    int day = -dayOffset;
    while (day < daysInMonth) {
      day++;
      if (day < 1) {
        dayItems.add(Container());
      } else {
        final Jalali dayToBuild = Jalali(year, month, day);
        final bool isDisabled = dayToBuild.isAfter(lastDate) ||
            dayToBuild.isBefore(firstDate) ||
            (selectableDayPredicate != null && !selectableDayPredicate!(dayToBuild));

        BoxDecoration? decoration;
        Color dayColor = enabledDayColor;
        final bool isSelectedDay = utils.isSameDay(selectedDate, dayToBuild);
        if (isSelectedDay) {
          // The selected day gets a circle background highlight, and a
          // contrasting text color.
          dayColor = selectedDayColor;
          decoration = BoxDecoration(
            color: selectedDayBackground,
            shape: BoxShape.circle,
          );
        } else if (isDisabled) {
          dayColor = disabledDayColor;
        } else if (utils.isSameDay(currentDate, dayToBuild)) {
          // The current day gets a different text color and a circle stroke
          // border.
          dayColor = todayColor;
          decoration = BoxDecoration(
            border: Border.all(color: todayColor, width: 1),
            shape: BoxShape.circle,
          );
        }

        Widget dayWidget = Container(
          decoration: decoration,
          child: Center(
            child: Text(formatDecimal(day), style: dayStyle!.apply(color: dayColor)),
          ),
        );

        if (isDisabled) {
          dayWidget = ExcludeSemantics(
            child: dayWidget,
          );
        } else {
          dayWidget = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(dayToBuild),
            child: Semantics(
              // We want the day of month to be spoken first irrespective of the
              // locale-specific preferences or TextDirection. This is because
              // an accessibility user is more likely to be interested in the
              // day of month before the rest of the date, as they are looking
              // for the day of month. To do that we prepend day of month to the
              // formatted full date.
              label: '${formatDecimal(day)}, ${dayToBuild.formatFullDate}',
              selected: isSelectedDay,
              excludeSemantics: true,
              child: dayWidget,
            ),
          );
        }

        dayItems.add(dayWidget);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _monthPickerHorizontalPadding,
      ),
      child: GridView.custom(
        physics: const ClampingScrollPhysics(),
        gridDelegate: _dayPickerGridDelegate,
        childrenDelegate: SliverChildListDelegate(
          dayItems,
          addRepaintBoundaries: false,
        ),
      ),
    );
  }
}

class _DayPickerGridDelegate extends SliverGridDelegate {
  const _DayPickerGridDelegate();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    const int columnCount = JalaliDate.daysPerWeek;
    final double tileWidth = constraints.crossAxisExtent / columnCount;
    final double tileHeight = math.min(_dayPickerRowHeight, constraints.viewportMainAxisExtent / _maxDayPickerRowCount);
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

const _DayPickerGridDelegate _dayPickerGridDelegate = _DayPickerGridDelegate();

class _DayHeaders extends StatelessWidget {
  /// Builds widgets showing abbreviated days of week. The first widget in the
  /// returned list corresponds to the first day of week for the current locale.
  ///
  /// Examples:
  ///
  /// ```
  /// ┌ Sunday is the first day of week in the US (en_US)
  /// |
  /// S M T W T F S  <-- the returned list contains these widgets
  /// _ _ _ _ _ 1 2
  /// 3 4 5 6 7 8 9
  ///
  /// ┌ But it's Monday in the UK (en_GB)
  /// |
  /// M T W T F S S  <-- the returned list contains these widgets
  /// _ _ _ _ 1 2 3
  /// 4 5 6 7 8 9 10
  /// ```
  List<Widget> _getDayHeaders(TextStyle? headerStyle, MaterialLocalizations localizations) {
    final List<Widget> result = <Widget>[];
    int firstDayOfWeekIndex = 0;
    for (int i = firstDayOfWeekIndex; true; i = (i + 1) % 7) {
      final String weekday = narrowWeekdays[i];
      result.add(ExcludeSemantics(
        child: Center(child: Text(weekday, style: headerStyle)),
      ));
      if (i == (firstDayOfWeekIndex - 1) % 7) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle? dayHeaderStyle = theme.textTheme.caption?.apply(
      color: colorScheme.onSurface.withOpacity(0.60),
    );
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final List<Widget> labels = _getDayHeaders(dayHeaderStyle, localizations);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _monthPickerHorizontalPadding,
      ),
      child: GridView.custom(
        shrinkWrap: true,
        gridDelegate: _dayPickerGridDelegate,
        childrenDelegate: SliverChildListDelegate(
          labels,
          addRepaintBoundaries: false,
        ),
      ),
    );
  }
}

/// A scrollable list of years to allow picking a year.
class _YearPicker extends StatefulWidget {
  /// Creates a year picker.
  ///
  /// The [currentDate, [firstDate], [lastDate], [selectedDate], and [onChanged]
  /// arguments must be non-null. The [lastDate] must be after the [firstDate].
  _YearPicker({
    Key? key,
    required this.currentDate,
    required this.firstDate,
    required this.lastDate,
    required this.currentDisplayedDate,
    required this.selectedDate,
    required this.onChanged,
  })  : assert(!firstDate.isAfter(lastDate)),
        super(key: key);

  /// The current date.
  ///
  /// This date is subtly highlighted in the picker.
  final Jalali currentDate;

  /// The earliest date the user is permitted to pick.
  final Jalali firstDate;

  /// The latest date the user is permitted to pick.
  final Jalali lastDate;

  /// The initial date to center the year display around.
  final Jalali currentDisplayedDate;

  /// The currently selected date.
  ///
  /// This date is highlighted in the picker.
  final Jalali selectedDate;

  /// Called when the user picks a year.
  final ValueChanged<Jalali> onChanged;

  @override
  _YearPickerState createState() => _YearPickerState();
}

class _YearPickerState extends State<_YearPicker> {
  ScrollController? scrollController;

  // The approximate number of years necessary to fill the available space.
  static const int minYears = 18;

  @override
  void initState() {
    super.initState();

    // Set the scroll position to approximately center the initial year.
    final int initialYearIndex = widget.selectedDate.year - widget.firstDate.year;
    final int initialYearRow = initialYearIndex ~/ _yearPickerColumnCount;
    // Move the offset down by 2 rows to approximately center it.
    final int centeredYearRow = initialYearRow - 2;
    final double scrollOffset = _itemCount < minYears ? 0 : centeredYearRow * _yearPickerRowHeight;
    scrollController = ScrollController(initialScrollOffset: scrollOffset);
  }

  Widget _buildYearItem(BuildContext context, int index) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Backfill the _YearPicker with disabled years if necessary.
    final int offset = _itemCount < minYears ? (minYears - _itemCount) ~/ 2 : 0;
    final int year = widget.firstDate.year + index - offset;
    final bool isSelected = year == widget.selectedDate.year;
    final bool isCurrentYear = year == widget.currentDate.year;
    final bool isDisabled = year < widget.firstDate.year || year > widget.lastDate.year;
    const double decorationHeight = 36.0;
    const double decorationWidth = 72.0;

    Color textColor;
    if (isSelected) {
      textColor = colorScheme.onPrimary;
    } else if (isDisabled) {
      textColor = colorScheme.onSurface.withOpacity(0.38);
    } else if (isCurrentYear) {
      textColor = colorScheme.primary;
    } else {
      textColor = colorScheme.onSurface.withOpacity(0.87);
    }
    final TextStyle? itemStyle = textTheme.bodyText1?.apply(color: textColor);

    BoxDecoration? decoration;
    if (isSelected) {
      decoration = BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(decorationHeight / 2),
        shape: BoxShape.rectangle,
      );
    } else if (isCurrentYear && !isDisabled) {
      decoration = BoxDecoration(
        border: Border.all(
          color: colorScheme.primary,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(decorationHeight / 2),
        shape: BoxShape.rectangle,
      );
    }

    Widget yearItem = Center(
      child: Container(
        decoration: decoration,
        height: decorationHeight,
        width: decorationWidth,
        child: Center(
          child: Semantics(
            selected: isSelected,
            child: Text(year.toString(), style: itemStyle),
          ),
        ),
      ),
    );

    if (isDisabled) {
      yearItem = ExcludeSemantics(
        child: yearItem,
      );
    } else {
      yearItem = InkWell(
        key: ValueKey<int>(year),
        onTap: () {
          widget.onChanged(
            Jalali(
              year,
              (widget.currentDisplayedDate).month,
              widget.currentDisplayedDate.day,
            ),
          );
        },
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
          child: GridView.builder(
            controller: scrollController,
            gridDelegate: _yearPickerGridDelegate,
            itemBuilder: _buildYearItem,
            itemCount: math.max(_itemCount, minYears),
            padding: const EdgeInsets.symmetric(horizontal: _yearPickerPadding),
          ),
        ),
        const Divider(),
      ],
    );
  }
}

class _MonthsSelecting extends StatelessWidget {
  const _MonthsSelecting(
      {required this.currentDate,
      this.currentDisplayedDate,
      required this.selectedDate,
      required this.onChanged,
      Key? key})
      : super(key: key);

  /// The current date.
  ///
  /// This date is subtly highlighted in the picker.
  final Jalali currentDate;

  /// The initial date to center the year display around.
  final Jalali? currentDisplayedDate;

  /// The currently selected date.
  ///
  /// This date is highlighted in the picker.
  final Jalali selectedDate;

  /// Called when the user picks a month.
  final ValueChanged<Jalali> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Divider(),
        Expanded(
          child: GridView.builder(
            gridDelegate: _yearPickerGridDelegate,
            itemBuilder: _buildMonthItem,
            itemCount: 12,
            padding: const EdgeInsets.symmetric(horizontal: _yearPickerPadding),
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildMonthItem(BuildContext context, int index) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final int month = index;
    final bool isSelected = month == (selectedDate.month - 1);
    final bool isCurrentMonth = month == (currentDate.month - 1);
    const double decorationHeight = 36.0;
    const double decorationWidth = 72.0;

    Color textColor;
    if (isSelected) {
      textColor = colorScheme.onPrimary;
    } else if (isCurrentMonth) {
      textColor = colorScheme.primary;
    } else {
      textColor = colorScheme.onSurface.withOpacity(0.87);
    }
    final TextStyle? itemStyle = textTheme.bodyText1?.apply(color: textColor);

    BoxDecoration? decoration;
    if (isSelected) {
      decoration = BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(decorationHeight / 2),
        shape: BoxShape.rectangle,
      );
    } else if (isCurrentMonth) {
      decoration = BoxDecoration(
        border: Border.all(
          color: colorScheme.primary,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(decorationHeight / 2),
        shape: BoxShape.rectangle,
      );
    }

    Widget monthItem = Center(
      child: Container(
        decoration: decoration,
        height: decorationHeight,
        width: decorationWidth,
        child: Center(
          child: Semantics(
            selected: isSelected,
            child: Text(JalaliDate.months[month].toString(), style: itemStyle),
          ),
        ),
      ),
    );

    monthItem = InkWell(
      key: ValueKey<int>(month),
      onTap: () {
        if (currentDisplayedDate != null) {
          onChanged(
            Jalali(
              currentDisplayedDate!.year,
              month + 1,
              currentDisplayedDate!.day,
            ),
          );
        }
      },
      child: monthItem,
    );

    return monthItem;
  }
}

class _YearPickerGridDelegate extends SliverGridDelegate {
  const _YearPickerGridDelegate();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final double tileWidth =
        (constraints.crossAxisExtent - (_yearPickerColumnCount - 1) * _yearPickerRowSpacing) / _yearPickerColumnCount;
    return SliverGridRegularTileLayout(
      childCrossAxisExtent: tileWidth,
      childMainAxisExtent: _yearPickerRowHeight,
      crossAxisCount: _yearPickerColumnCount,
      crossAxisStride: tileWidth + _yearPickerRowSpacing,
      mainAxisStride: _yearPickerRowHeight,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_YearPickerGridDelegate oldDelegate) => false;
}

const _YearPickerGridDelegate _yearPickerGridDelegate = _YearPickerGridDelegate();
