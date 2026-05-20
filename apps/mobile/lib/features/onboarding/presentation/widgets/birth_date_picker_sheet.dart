import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'onboarding_action_button.dart';

class BirthDatePickerSheet extends StatefulWidget {
  const BirthDatePickerSheet({
    super.key,
    required this.initialDate,
    required this.maxDate,
  });

  final DateTime initialDate;
  final DateTime maxDate;

  @override
  State<BirthDatePickerSheet> createState() => _BirthDatePickerSheetState();
}

class _BirthDatePickerSheetState extends State<BirthDatePickerSheet> {
  static const _minYear = 1900;

  late int _year;
  late int _month;
  late int _day;
  late final FixedExtentScrollController _yearController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _dayController;

  @override
  void initState() {
    super.initState();
    final initialDate = _clampDate(widget.initialDate);
    _year = initialDate.year;
    _month = initialDate.month;
    _day = initialDate.day;

    _yearController = FixedExtentScrollController(
      initialItem: _year - _minYear,
    );
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxMonth = _maxMonthFor(_year);
    final maxDay = _maxDayFor(_year, _month);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.actionDisabled,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 22),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('생일 선택', style: AppTextStyles.onboardingTitle),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 216,
                child: Row(
                  children: [
                    Expanded(
                      child: _PickerColumn(
                        controller: _yearController,
                        count: widget.maxDate.year - _minYear + 1,
                        labelBuilder: (index) => '${_minYear + index}년',
                        onSelectedItemChanged: (index) {
                          _changeDate(year: _minYear + index);
                        },
                      ),
                    ),
                    Expanded(
                      child: _PickerColumn(
                        key: ValueKey(maxMonth),
                        controller: _monthController,
                        count: maxMonth,
                        labelBuilder: (index) => '${index + 1}월',
                        onSelectedItemChanged: (index) {
                          _changeDate(month: index + 1);
                        },
                      ),
                    ),
                    Expanded(
                      child: _PickerColumn(
                        key: ValueKey('$_year-$_month-$maxDay'),
                        controller: _dayController,
                        count: maxDay,
                        labelBuilder: (index) => '${index + 1}일',
                        onSelectedItemChanged: (index) {
                          _changeDate(day: index + 1);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OnboardingActionButton(
                label: '완료',
                enabled: true,
                onPressed: () {
                  Navigator.of(context).pop(DateTime(_year, _month, _day));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeDate({int? year, int? month, int? day}) {
    final nextYear = year ?? _year;
    final nextMonth = math.min(month ?? _month, _maxMonthFor(nextYear));
    final nextDay = math.min(day ?? _day, _maxDayFor(nextYear, nextMonth));

    setState(() {
      _year = nextYear;
      _month = nextMonth;
      _day = nextDay;
    });

    if (_monthController.selectedItem != nextMonth - 1) {
      _monthController.jumpToItem(nextMonth - 1);
    }
    if (_dayController.selectedItem != nextDay - 1) {
      _dayController.jumpToItem(nextDay - 1);
    }
  }

  DateTime _clampDate(DateTime date) {
    final minDate = DateTime(_minYear);
    final maxDate = _dateOnly(widget.maxDate);
    final selected = _dateOnly(date);

    if (selected.isBefore(minDate)) {
      return minDate;
    }
    if (selected.isAfter(maxDate)) {
      return maxDate;
    }

    return selected;
  }

  int _maxMonthFor(int year) {
    return year == widget.maxDate.year ? widget.maxDate.month : 12;
  }

  int _maxDayFor(int year, int month) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    if (year == widget.maxDate.year && month == widget.maxDate.month) {
      return math.min(lastDayOfMonth, widget.maxDate.day);
    }

    return lastDayOfMonth;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

class _PickerColumn extends StatelessWidget {
  const _PickerColumn({
    super.key,
    required this.controller,
    required this.count,
    required this.labelBuilder,
    required this.onSelectedItemChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: 42,
      diameterRatio: 1.25,
      selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
        background: Color(0x0F000000),
      ),
      childCount: count,
      onSelectedItemChanged: onSelectedItemChanged,
      itemBuilder: (context, index) {
        return Center(
          child: Text(
            labelBuilder(index),
            style: AppTextStyles.onboardingInput,
          ),
        );
      },
    );
  }
}
