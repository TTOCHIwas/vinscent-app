import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'app_action_button.dart';

Future<DateTime?> showAppDatePickerSheet({
  required BuildContext context,
  required String title,
  required DateTime initialDate,
  required DateTime minDate,
  required DateTime maxDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AppDatePickerSheet(
      title: title,
      initialDate: initialDate,
      minDate: minDate,
      maxDate: maxDate,
    ),
  );
}

class AppDatePickerSheet extends StatefulWidget {
  const AppDatePickerSheet({
    super.key,
    required this.title,
    required this.initialDate,
    required this.minDate,
    required this.maxDate,
  });

  final String title;
  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDate;

  @override
  State<AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

class _AppDatePickerSheetState extends State<AppDatePickerSheet> {
  late final DateTime _minDate;
  late final DateTime _maxDate;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _minDate = _dateOnly(widget.minDate);
    _maxDate = _dateOnly(widget.maxDate);
    assert(!_minDate.isAfter(_maxDate));
    _selectedDate = _clampDate(widget.initialDate);
  }

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var year = _minDate.year; year <= _maxDate.year; year++) year,
    ];
    final months = _monthsFor(_selectedDate.year);
    final days = _daysFor(_selectedDate.year, _selectedDate.month);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          key: const Key('app-date-picker-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _SheetHandle()),
              const SizedBox(height: 20),
              Text(widget.title, style: AppTextStyles.sectionTitle),
              const SizedBox(height: 16),
              SizedBox(
                height: 216,
                child: Row(
                  children: [
                    Expanded(
                      child: _PickerColumn(
                        key: const Key('app-date-picker-year'),
                        values: years,
                        selectedValue: _selectedDate.year,
                        labelBuilder: (value) => '$value년',
                        onSelected: (value) => _changeDate(year: value),
                      ),
                    ),
                    Expanded(
                      child: _PickerColumn(
                        key: const Key('app-date-picker-month'),
                        values: months,
                        selectedValue: _selectedDate.month,
                        labelBuilder: (value) => '$value월',
                        onSelected: (value) => _changeDate(month: value),
                      ),
                    ),
                    Expanded(
                      child: _PickerColumn(
                        key: const Key('app-date-picker-day'),
                        values: days,
                        selectedValue: _selectedDate.day,
                        labelBuilder: (value) => '$value일',
                        onSelected: (value) => _changeDate(day: value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppActionButton(
                label: '완료',
                enabled: true,
                onPressed: () => Navigator.of(context).pop(_selectedDate),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeDate({int? year, int? month, int? day}) {
    final nextYear = year ?? _selectedDate.year;
    final allowedMonths = _monthsFor(nextYear);
    final nextMonth = (month ?? _selectedDate.month).clamp(
      allowedMonths.first,
      allowedMonths.last,
    );
    final allowedDays = _daysFor(nextYear, nextMonth);
    final nextDay = (day ?? _selectedDate.day).clamp(
      allowedDays.first,
      allowedDays.last,
    );

    setState(() {
      _selectedDate = DateTime(nextYear, nextMonth, nextDay);
    });
  }

  List<int> _monthsFor(int year) {
    final firstMonth = year == _minDate.year ? _minDate.month : 1;
    final lastMonth = year == _maxDate.year ? _maxDate.month : 12;
    return [for (var month = firstMonth; month <= lastMonth; month++) month];
  }

  List<int> _daysFor(int year, int month) {
    final firstDay = year == _minDate.year && month == _minDate.month
        ? _minDate.day
        : 1;
    final monthLastDay = DateTime(year, month + 1, 0).day;
    final lastDay = year == _maxDate.year && month == _maxDate.month
        ? math.min(monthLastDay, _maxDate.day)
        : monthLastDay;
    return [for (var day = firstDay; day <= lastDay; day++) day];
  }

  DateTime _clampDate(DateTime date) {
    final normalized = _dateOnly(date);
    if (normalized.isBefore(_minDate)) {
      return _minDate;
    }
    if (normalized.isAfter(_maxDate)) {
      return _maxDate;
    }
    return normalized;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

class _PickerColumn extends StatefulWidget {
  const _PickerColumn({
    super.key,
    required this.values,
    required this.selectedValue,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<int> values;
  final int selectedValue;
  final String Function(int value) labelBuilder;
  final ValueChanged<int> onSelected;

  @override
  State<_PickerColumn> createState() => _PickerColumnState();
}

class _PickerColumnState extends State<_PickerColumn> {
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: _selectedIndex(widget),
    );
  }

  @override
  void didUpdateWidget(covariant _PickerColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _selectedIndex(widget);
    if (!_controller.hasClients || _controller.selectedItem == nextIndex) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        _controller.jumpToItem(nextIndex);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker.builder(
      scrollController: _controller,
      itemExtent: 42,
      diameterRatio: 1.25,
      selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
        background: Color(0x0F000000),
      ),
      childCount: widget.values.length,
      onSelectedItemChanged: (index) {
        widget.onSelected(widget.values[index]);
      },
      itemBuilder: (context, index) {
        return Center(
          child: Text(
            widget.labelBuilder(widget.values[index]),
            style: AppTextStyles.onboardingInput,
          ),
        );
      },
    );
  }

  int _selectedIndex(_PickerColumn widget) {
    final index = widget.values.indexOf(widget.selectedValue);
    return index < 0 ? 0 : index;
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.settingsDivider,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const SizedBox(width: 36, height: 4),
    );
  }
}
