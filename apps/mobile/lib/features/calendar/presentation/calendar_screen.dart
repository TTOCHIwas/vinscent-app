import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/application/couple_current_date_provider.dart';
import '../../expressions/application/couple_expression_summary_provider.dart';
import '../../story_loops/application/story_loop_detail_provider.dart';
import 'widgets/calendar_story_loop_detail.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _visibleMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final today = ref.read(coupleCurrentDateProvider);
    _visibleMonth = _monthOnly(today);

    ref.listenManual<DateTime>(coupleCurrentDateProvider, (previous, next) {
      final todayMonth = _monthOnly(next);
      if (!_visibleMonth.isAfter(todayMonth)) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _visibleMonth = todayMonth;
        _selectedDate = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(coupleCurrentDateProvider);
    final couple = ref.watch(coupleControllerProvider);

    return couple.when(
      loading: () => const _CenteredLoader(),
      error: (error, stackTrace) => const _CalendarStateMessage(
        title: '커플 정보를 불러오지 못했어요',
        message: '잠시 후 다시 시도해 주세요',
      ),
      data: (couple) {
        if (couple == null ||
            !couple.canReadSharedData ||
            !couple.hasRelationshipStartDate) {
          return const _CalendarStateMessage(
            title: '달력을 볼 수 없어요',
            message: '커플 연결과 시작일 설정을 먼저 완료해 주세요',
          );
        }

        final relationshipStartMonth = _monthOnly(
          couple.relationshipStartDate!,
        );
        final todayMonth = _monthOnly(today);
        final canGoPrevious = _canGoPrevious(relationshipStartMonth);
        final canGoNext = _canGoNext(todayMonth);

        return Column(
          children: [
            _CalendarMonthHeader(
              visibleMonth: _visibleMonth,
              canGoPrevious: canGoPrevious,
              canGoNext: canGoNext,
              onPreviousPressed: canGoPrevious
                  ? () => _showPreviousMonth(relationshipStartMonth)
                  : null,
              onNextPressed: canGoNext
                  ? () => _showNextMonth(todayMonth)
                  : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
                  child: Column(
                    children: [
                      _CalendarGrid(
                        visibleMonth: _visibleMonth,
                        today: today,
                        relationshipStartDate: couple.relationshipStartDate!,
                        selectedDate: _selectedDate,
                        onDatePressed: _handleDatePressed,
                      ),
                      const SizedBox(height: 48),
                      _CalendarDetail(selectedDate: _selectedDate),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _canGoPrevious(DateTime relationshipStartMonth) {
    return _visibleMonth.isAfter(relationshipStartMonth);
  }

  bool _canGoNext(DateTime todayMonth) {
    return _visibleMonth.isBefore(todayMonth);
  }

  void _showPreviousMonth(DateTime relationshipStartMonth) {
    final previousMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    if (previousMonth.isBefore(relationshipStartMonth)) {
      return;
    }

    setState(() {
      _visibleMonth = previousMonth;
      _selectedDate = null;
    });
  }

  void _showNextMonth(DateTime todayMonth) {
    final nextMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    if (nextMonth.isAfter(todayMonth)) {
      return;
    }

    setState(() {
      _visibleMonth = nextMonth;
      _selectedDate = null;
    });
  }

  void _handleDatePressed(DateTime date) {
    setState(() {
      _selectedDate = calendarDateOnly(date);
    });
  }
}

class _CalendarMonthHeader extends StatelessWidget {
  const _CalendarMonthHeader({
    required this.visibleMonth,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPreviousPressed,
    required this.onNextPressed,
  });

  final DateTime visibleMonth;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onNextPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: _MonthIconButton(
              icon: Icons.chevron_left,
              semanticLabel: '이전 달',
              onPressed: canGoPrevious ? onPreviousPressed : null,
            ),
          ),
          Text(
            _formatMonth(visibleMonth),
            style: AppTextStyles.shellTitle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: _MonthIconButton(
              icon: Icons.chevron_right,
              semanticLabel: '다음 달',
              onPressed: canGoNext ? onNextPressed : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthIconButton extends StatelessWidget {
  const _MonthIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox.square(
          dimension: 40,
          child: Icon(
            icon,
            size: 24,
            color: enabled ? AppColors.textPrimary : AppColors.textPlaceholder,
          ),
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.visibleMonth,
    required this.today,
    required this.relationshipStartDate,
    required this.selectedDate,
    required this.onDatePressed,
  });

  static const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];
  static const _gridHeight = 308.0;
  static const _gridGap = 10.0;

  final DateTime visibleMonth;
  final DateTime today;
  final DateTime relationshipStartDate;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDatePressed;

  @override
  Widget build(BuildContext context) {
    final days = _calendarDays(visibleMonth);
    final cells = <Widget>[
      for (final label in _weekdayLabels) _WeekdayCell(label: label),
      for (final date in days)
        _DateCell(
          date: date,
          isCurrentMonth: _isSameMonth(date, visibleMonth),
          isEnabled: _isEnabled(date),
          isSelected: selectedDate != null && _isSameDate(date, selectedDate!),
          onPressed: () => onDatePressed(date),
        ),
    ];

    return SizedBox(
      height: _gridHeight,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cells.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          crossAxisSpacing: _gridGap,
          mainAxisSpacing: _gridGap,
          mainAxisExtent: (_gridHeight - (_gridGap * 6)) / 7,
        ),
        itemBuilder: (context, index) => cells[index],
      ),
    );
  }

  bool _isEnabled(DateTime date) {
    if (!_isSameMonth(date, visibleMonth)) {
      return false;
    }

    final normalizedDate = calendarDateOnly(date);
    return !normalizedDate.isBefore(calendarDateOnly(relationshipStartDate)) &&
        !normalizedDate.isAfter(calendarDateOnly(today));
  }
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: AppTextStyles.homeCharacterLabel.copyWith(
          color: const Color(0xFF8C8C8C),
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isEnabled,
    required this.isSelected,
    required this.onPressed,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isEnabled;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: isEnabled,
      selected: isSelected,
      label: '${date.day}일',
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.actionPrimary : AppColors.background,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            '${date.day}',
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: _textColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Color get _textColor {
    if (isSelected) {
      return AppColors.textInverse;
    }

    if (!isCurrentMonth || !isEnabled) {
      return const Color(0xFFC7C7C7);
    }

    return const Color(0xFF171717);
  }
}

class _CalendarDetail extends ConsumerWidget {
  const _CalendarDetail({required this.selectedDate});

  final DateTime? selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = selectedDate;
    if (selected == null) {
      return const _CalendarStateMessage(
        title: '날짜를 선택해 주세요',
        message: '지금 질문과 답변 기록을 확인할 수 있어요',
      );
    }

    final detail = ref.watch(storyLoopDetailProvider(selected));
    final expressionSummary = ref.watch(
      coupleExpressionSummaryProvider(selected),
    );

    return detail.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: _CenteredLoader(),
      ),
      error: (error, stackTrace) => _CalendarHistoryErrorDetail(
        onRetry: () {
          ref.invalidate(storyLoopDetailProvider(selected));
          ref.invalidate(coupleExpressionSummaryProvider(selected));
        },
      ),
      data: (storyLoopState) {
        return expressionSummary.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: _CenteredLoader(),
          ),
          error: (error, stackTrace) => _CalendarHistoryErrorDetail(
            onRetry: () {
              ref.invalidate(storyLoopDetailProvider(selected));
              ref.invalidate(coupleExpressionSummaryProvider(selected));
            },
          ),
          data: (summaries) => CalendarStoryLoopDetail(
            storyLoopState: storyLoopState,
            expressionSummaries: summaries,
          ),
        );
      },
    );
  }
}

class _CalendarHistoryErrorDetail extends StatelessWidget {
  const _CalendarHistoryErrorDetail({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _CalendarStateMessage(
          title: '기록을 불러오지 못했어요',
          message: '잠시 후 다시 시도해 주세요',
        ),
        const SizedBox(height: 16),
        AppActionButton(
          label: '다시 시도',
          enabled: true,
          onPressed: onRetry,
          isSecondary: true,
        ),
      ],
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _CalendarStateMessage extends StatelessWidget {
  const _CalendarStateMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeBodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _monthOnly(DateTime date) {
  return DateTime(date.year, date.month);
}

List<DateTime> _calendarDays(DateTime visibleMonth) {
  final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
  final sundayOffset = firstDay.weekday % DateTime.daysPerWeek;
  final startDate = firstDay.subtract(Duration(days: sundayOffset));

  return [
    for (var index = 0; index < 42; index++)
      startDate.add(Duration(days: index)),
  ];
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}

String _formatMonth(DateTime date) {
  return '${date.year}년 ${_twoDigits(date.month)}월';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
