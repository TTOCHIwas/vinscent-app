import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/calendar_adjacent_month_prefetch_provider.dart';
import '../../data/calendar_cell_preview_mode.dart';

class CalendarAdjacentMonthPrefetch extends ConsumerWidget {
  const CalendarAdjacentMonthPrefetch({
    super.key,
    required this.visibleMonth,
    required this.relationshipStartDate,
    required this.previewMode,
  });

  final DateTime visibleMonth;
  final DateTime relationshipStartDate;
  final CalendarCellPreviewMode previewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      calendarAdjacentMonthPrefetchProvider((
        visibleMonth: visibleMonth,
        relationshipStartDate: relationshipStartDate,
        previewMode: previewMode,
      )),
    );
    return const SizedBox.shrink();
  }
}
