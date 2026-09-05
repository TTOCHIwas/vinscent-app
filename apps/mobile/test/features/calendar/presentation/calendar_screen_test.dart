import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vinscent/core/presentation/widgets/app_horizontal_page_transition.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/core/theme/app_theme.dart';
import 'package:vinscent/features/calendar/application/couple_default_calendar_event_resolver.dart';
import 'package:vinscent/features/calendar/data/calendar_cell_preview_mode.dart';
import 'package:vinscent/features/calendar/data/couple_member_birthday.dart';
import 'package:vinscent/features/calendar/presentation/calendar_month_layout_metrics.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_detail_date_header.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_month_card_preview.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_month_event_indicator.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_month_story_cell.dart';
import 'package:vinscent/features/story_loops/data/story_loop_month_summary_day.dart';
import 'package:vinscent/features/story_loops/data/story_loop_status.dart';

import '../../../support/story_loop_fixtures.dart';
import 'calendar_screen_test_support.dart';

void main() {
  testWidgets('keeps the date label inside its marker when text is enlarged', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ko')],
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Center(
          child: SizedBox(
            width: 52,
            height: 72,
            child: CalendarMonthStoryCell(
              date: DateTime(2026, 5, 10),
              textColor: AppColors.textPrimary,
              isSelected: true,
              summary: null,
            ),
          ),
        ),
      ),
    );

    final textFinder = find.text('10');
    final text = tester.widget<Text>(textFinder);
    final context = tester.element(textFinder);
    final style = DefaultTextStyle.of(context).style.merge(text.style);
    final painter = TextPainter(
      text: TextSpan(text: '10', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    addTearDown(painter.dispose);

    expect(text.style?.height, 1);
    expect(text.style?.fontSize, 12);
    final marker = tester.widget<DecoratedBox>(
      find.ancestor(of: textFinder, matching: find.byType(DecoratedBox)).first,
    );
    expect((marker.decoration as BoxDecoration).color, AppColors.actionPrimary);
    expect(text.style?.color, AppColors.textInverse);
    expect(painter.height, lessThanOrEqualTo(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects today and loads its detail on entry', (tester) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 10): todayPendingDetail},
    );
    await pumpCalendar(tester, repository: repository);

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('날짜를 선택해 주세요'), findsNothing);
    expect(find.text('today history question'), findsOneWidget);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
    expect(
      circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-10'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );
  });

  testWidgets('selects the date supplied by the route on entry', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 9): todayPendingDetail},
    );
    await pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 1),
      initialDate: DateTime(2026, 5, 9),
    );

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 9)]);
    expect(
      circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-09'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );
  });

  testWidgets('opens the weekly detail state when a date is tapped', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    final router = await pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 1),
    );
    final scrollFinder = find.byKey(const Key('calendar-scroll-view'));
    final scrollView = tester.widget<CustomScrollView>(scrollFinder);
    final metrics = CalendarMonthLayoutMetrics.forViewport(
      tester.getSize(scrollFinder).height,
    );

    expect(
      scrollView.controller!.offset,
      closeTo(metrics.standardScrollOffset, 0.5),
    );

    await tester.tap(find.text('9').first);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/calendar?date=2026-05-09',
    );
    expect(repository.requestedDetailDates, contains(DateTime(2026, 5, 9)));
    expect(find.text('5월 9일'), findsOneWidget);
    expect(
      scrollView.controller!.offset,
      closeTo(metrics.weeklyScrollOffset, 0.5),
    );
  });

  testWidgets('resets the viewport when the routed date changes', (
    tester,
  ) async {
    final routeDate = ValueNotifier<DateTime?>(DateTime(2026, 5, 9));
    addTearDown(routeDate.dispose);
    final repository = FakeStoryLoopReadRepository();
    await pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 1),
      routeDate: routeDate,
    );

    final scrollFinder = find.byKey(const Key('calendar-scroll-view'));
    final scrollView = tester.widget<CustomScrollView>(scrollFinder);
    final metrics = CalendarMonthLayoutMetrics.forViewport(
      tester.getSize(scrollFinder).height,
    );

    await tester.drag(scrollFinder, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(scrollView.controller!.offset, closeTo(0, 0.5));

    routeDate.value = DateTime(2026, 5, 8);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, contains(DateTime(2026, 5, 8)));
    expect(
      scrollView.controller!.offset,
      closeTo(metrics.standardScrollOffset, 0.5),
    );
  });

  testWidgets('reopens a routed date after browsing away inside calendar', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    final router = await pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 1),
    );

    await tester.tap(find.text('9').first);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/calendar?date=2026-05-09',
    );

    router.go('/calendar?date=2026-05-10');
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
      DateTime(2026, 5, 10),
    ]);
    expect(
      circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-10'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );
  });

  testWidgets('fills and left aligns the selected date header', (tester) async {
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      relationshipStartDate: DateTime(2026, 5, 1),
    );

    final scrollView = find.byKey(const Key('calendar-scroll-view'));
    final header = find.byType(CalendarDetailDateHeader);
    final dateText = find.descendant(of: header, matching: find.text('5월 10일'));
    final metadataText = find.descendant(
      of: header,
      matching: find.text('2026 · 일요일'),
    );

    expect(tester.getSize(header).width, tester.getSize(scrollView).width);
    expect(
      tester.getTopLeft(dateText).dx,
      closeTo(tester.getTopLeft(scrollView).dx + 20, 0.5),
    );
    final headerRect = tester.getRect(header);
    final topGap = tester.getRect(dateText).top - headerRect.top;
    final bottomGap = headerRect.bottom - tester.getRect(metadataText).bottom;
    expect(topGap, closeTo(bottomGap, 0.5));
  });

  testWidgets('shows default anniversaries in the selected date header', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      relationshipStartDate: DateTime(2026, 5, 1),
    );

    final header = find.byType(CalendarDetailDateHeader);
    final anniversaryLabel = find.descendant(
      of: header,
      matching: find.text('10일'),
    );

    expect(anniversaryLabel, findsOneWidget);
    expect(
      find.descendant(
        of: header,
        matching: find.byIcon(LucideIcons.calendarHeart),
      ),
      findsOneWidget,
    );
    expect(tester.widget<Text>(anniversaryLabel).style?.fontSize, 20);
    expect(
      find.byKey(const Key('calendar-detail-default-event-labels')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('calendar-event-detail-list')), findsNothing);
  });

  testWidgets('shows a member birthday as a default calendar event', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      relationshipStartDate: DateTime(2026, 5, 2),
      memberBirthdays: [
        CoupleMemberBirthday(
          role: CoupleMemberRole.self,
          displayName: '또치',
          birthDate: DateTime(1990, 5, 10),
        ),
      ],
    );

    final header = find.byType(CalendarDetailDateHeader);
    expect(
      find.descendant(of: header, matching: find.text('내 생일')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.byIcon(LucideIcons.cakeSlice)),
      findsOneWidget,
    );
    expect(find.byKey(const Key('calendar-event-detail-list')), findsNothing);
  });

  testWidgets('stacks default anniversaries on a narrow enlarged-text header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final events = [
                CoupleDefaultCalendarEventOccurrence(
                  kind: CoupleDefaultCalendarEventKind.relationshipAnniversary,
                  label: '1주년',
                  date: DateTime(2026, 5, 10),
                ),
                CoupleDefaultCalendarEventOccurrence(
                  kind: CoupleDefaultCalendarEventKind.relationshipAnniversary,
                  label: '400일',
                  date: DateTime(2026, 5, 10),
                ),
              ];
              return CalendarDetailDateHeader(
                date: DateTime(2026, 5, 10),
                defaultEvents: events,
                height: CalendarDetailDateHeader.resolveExtent(
                  context,
                  defaultEvents: events,
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('1주년'), findsOneWidget);
    expect(find.text('400일'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the calendar readable on a narrow enlarged-text screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      textScaleFactor: 1.3,
      calendarEvents: [
        calendarEvent(
          id: 'long-event',
          title: '함께 오래 기억하고 싶은 아주 긴 일정 제목',
          date: DateTime(2026, 5, 10),
        ),
      ],
    );

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipes the selected-day detail one day at a time', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 9),
    );
    final swipeRegion = find.byKey(
      const Key('calendar-detail-date-swipe-region'),
    );

    await tester.fling(swipeRegion, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
    ]);
    expect(
      circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-09'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );

    await tester.fling(swipeRegion, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
    ]);

    await tester.fling(swipeRegion, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
      DateTime(2026, 5, 10),
    ]);
    expect(
      circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-10'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );

    await tester.fling(swipeRegion, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
      DateTime(2026, 5, 10),
    ]);
    expect(
      circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-11'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );
  });

  testWidgets('ignores a short fast date flick', (tester) async {
    final repository = FakeStoryLoopReadRepository();
    await pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 9),
    );

    await tester.fling(
      find.byKey(const Key('calendar-detail-date-swipe-region')),
      const Offset(64, 0),
      2000,
    );
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets('updates the visible month when a date swipe crosses a month', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await pumpCalendar(
      tester,
      repository: repository,
      today: DateTime(2026, 6, 1),
    );

    await tester.fling(
      find.byKey(const Key('calendar-detail-date-swipe-region')),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(repository.requestedMonths, [DateTime(2026, 6), DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [
      DateTime(2026, 6, 1),
      DateTime(2026, 5, 31),
    ]);
  });

  testWidgets(
    'moves the standard calendar one month while preserving the day',
    (tester) async {
      final repository = FakeStoryLoopReadRepository();
      await pumpCalendar(
        tester,
        repository: repository,
        today: DateTime(2026, 6, 2),
      );

      await tester.fling(
        find.byKey(const Key('calendar-month-swipe-region')),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('2026년 05월'), findsOneWidget);
      expect(repository.requestedMonths, [
        DateTime(2026, 6),
        DateTime(2026, 5),
      ]);
      expect(repository.requestedDetailDates, [
        DateTime(2026, 6, 2),
        DateTime(2026, 5, 2),
      ]);
    },
  );

  testWidgets(
    'slides horizontal calendar changes while keeping weekdays fixed',
    (tester) async {
      await pumpCalendar(tester, repository: FakeStoryLoopReadRepository());
      final swipeRegion = find.byKey(const Key('calendar-month-swipe-region'));

      await tester.fling(swipeRegion, const Offset(-300, 0), 1000);
      await tester.pump();

      expect(find.text('2026년 06월'), findsOneWidget);
      expect(find.byType(AppHorizontalPageTransition), findsWidgets);
      expect(find.byType(CalendarDetailDateHeader), findsNWidgets(2));
      expect(find.text('월'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CalendarDetailDateHeader), findsOneWidget);
      expect(find.text('2026년 06월'), findsOneWidget);
    },
  );

  testWidgets('moves the weekly calendar by seven days', (tester) async {
    final repository = FakeStoryLoopReadRepository();
    await pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 1),
    );
    final scrollView = tester.widget<CustomScrollView>(
      find.byKey(const Key('calendar-scroll-view')),
    );
    final metrics = CalendarMonthLayoutMetrics.forViewport(
      tester.getSize(find.byKey(const Key('calendar-scroll-view'))).height,
    );

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(
      scrollView.controller!.offset,
      closeTo(metrics.weeklyScrollOffset, 0.5),
    );

    await tester.fling(
      find.byKey(const Key('calendar-month-swipe-region')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('5월 17일'), findsOneWidget);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets('does not move before relationship start month', (tester) async {
    final repository = FakeStoryLoopReadRepository();

    await pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 04월'), findsNothing);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets('balances the filter and add actions around month navigation', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      relationshipStartDate: DateTime(2026, 5, 1),
    );

    final titleCenter = tester.getCenter(find.text('2026년 05월')).dx;
    final previousCenter = tester
        .getCenter(find.byKey(const Key('calendar-previous-month')))
        .dx;
    final nextCenter = tester
        .getCenter(find.byKey(const Key('calendar-next-month')))
        .dx;
    final addCenter = tester
        .getCenter(find.byKey(const Key('calendar-add-event')))
        .dx;
    final filterCenter = tester
        .getCenter(find.byKey(const Key('calendar-cell-preview-filter')))
        .dx;

    expect((previousCenter + nextCenter) / 2, closeTo(titleCenter, 0.5));
    expect(
      titleCenter,
      closeTo(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
        0.5,
      ),
    );
    expect(addCenter, greaterThan(nextCenter));
    expect(
      filterCenter + addCenter,
      closeTo(
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
        0.5,
      ),
    );
  });

  testWidgets('selects a calendar cell preview mode from the header sheet', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      relationshipStartDate: DateTime(2026, 5, 1),
    );

    await tester.tap(find.byKey(const Key('calendar-cell-preview-filter')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-cell-preview-filter-sheet')),
      findsOneWidget,
    );
    expect(find.text('캘린더에 표시'), findsOneWidget);
    expect(find.text('모두'), findsOneWidget);
    expect(find.text('카드만'), findsOneWidget);
    expect(find.text('일정만'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-cell-preview-thumbnail-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-cell-preview-thumbnail-cards_only')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-cell-preview-thumbnail-events_only')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-cell-preview-smiling-doodle')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.sentiment_satisfied_outlined), findsNothing);
    final allThumbnailCenter = tester.getCenter(
      find.byKey(const ValueKey('calendar-cell-preview-thumbnail-all')),
    );
    final cardsThumbnailCenter = tester.getCenter(
      find.byKey(const ValueKey('calendar-cell-preview-thumbnail-cards_only')),
    );
    final eventsThumbnailCenter = tester.getCenter(
      find.byKey(const ValueKey('calendar-cell-preview-thumbnail-events_only')),
    );

    expect(allThumbnailCenter.dy, closeTo(cardsThumbnailCenter.dy, 0.5));
    expect(cardsThumbnailCenter.dy, closeTo(eventsThumbnailCenter.dy, 0.5));
    expect(allThumbnailCenter.dx, lessThan(cardsThumbnailCenter.dx));
    expect(cardsThumbnailCenter.dx, lessThan(eventsThumbnailCenter.dx));

    await tester.tap(
      find.byKey(const ValueKey('calendar-cell-preview-mode-cards_only')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-cell-preview-filter-sheet')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('calendar-cell-preview-filter')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-cell-preview-selected-cards_only')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-cell-preview-selected-all')),
      findsNothing,
    );
    final selectedMode = find.byKey(
      const ValueKey('calendar-cell-preview-selected-cards_only'),
    );
    final selectedContainer = tester.widget<Container>(selectedMode);
    final selectedDecoration = selectedContainer.decoration! as BoxDecoration;
    final selectedLabel = tester.widget<Text>(
      find.descendant(of: selectedMode, matching: find.text('카드만')),
    );

    expect(selectedDecoration.color, AppColors.selection);
    expect(selectedLabel.style?.color, AppColors.onSelection);
  });

  testWidgets(
    'cards-only filters event previews but keeps selected-day events',
    (tester) async {
      final date = DateTime(2026, 5, 10);
      final repository = FakeStoryLoopReadRepository(
        monthSummaries: {
          DateTime(2026, 5): [
            StoryLoopMonthSummaryDay(
              coupleDate: date,
              loopStatus: StoryLoopStatus.waitingPartnerCard,
              cardCount: 1,
              cards: [samplePreviewCard(previewPath: '')],
            ),
          ],
        },
      );
      final eventRequests = <CalendarEventDateRange>[];

      await pumpCalendar(
        tester,
        repository: repository,
        previewMode: CalendarCellPreviewMode.cardsOnly,
        calendarEvents: [
          calendarEvent(id: 'event-1', title: '함께 걷기', date: date),
        ],
        calendarEventRequests: eventRequests,
      );

      final cell = find.byKey(
        const ValueKey('calendar-month-story-cell-single-2026-05-10'),
      );
      expect(
        find.descendant(
          of: cell,
          matching: find.byType(CalendarMonthCardPreview),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cell,
          matching: find.byType(CalendarMonthEventIndicator),
        ),
        findsNothing,
      );
      expect(find.text('함께 걷기'), findsOneWidget);
      expect(repository.requestedMonths, [DateTime(2026, 5)]);
      expect(eventRequests, [
        (startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 31)),
      ]);
    },
  );

  testWidgets(
    'all mode reuses month events for the selected-day detail',
    (tester) async {
      final date = DateTime(2026, 5, 10);
      final eventRequests = <CalendarEventDateRange>[];

      await pumpCalendar(
        tester,
        repository: FakeStoryLoopReadRepository(),
        previewMode: CalendarCellPreviewMode.all,
        calendarEvents: [
          calendarEvent(id: 'event-1', title: '함께 걷기', date: date),
        ],
        calendarEventRequests: eventRequests,
      );

      expect(eventRequests, [
        (startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 31)),
      ]);
      expect(find.text('함께 걷기'), findsOneWidget);
    },
  );

  testWidgets(
    'events-only skips card month previews and keeps event previews',
    (tester) async {
      final date = DateTime(2026, 5, 10);
      final repository = FakeStoryLoopReadRepository(
        monthSummaries: {
          DateTime(2026, 5): [
            StoryLoopMonthSummaryDay(
              coupleDate: date,
              loopStatus: StoryLoopStatus.waitingPartnerCard,
              cardCount: 1,
              cards: [samplePreviewCard(previewPath: '')],
            ),
          ],
        },
      );
      final eventRequests = <CalendarEventDateRange>[];

      await pumpCalendar(
        tester,
        repository: repository,
        previewMode: CalendarCellPreviewMode.eventsOnly,
        calendarEvents: [
          calendarEvent(id: 'event-1', title: '함께 걷기', date: date),
        ],
        calendarEventRequests: eventRequests,
      );

      final cell = find.byKey(
        const ValueKey('calendar-month-story-cell-empty-2026-05-10'),
      );
      expect(
        find.descendant(
          of: cell,
          matching: find.byType(CalendarMonthCardPreview),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: cell,
          matching: find.byType(CalendarMonthEventIndicator),
        ),
        findsOneWidget,
      );
      expect(repository.requestedMonths, isEmpty);
      expect(eventRequests, [
        (startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 31)),
      ]);
    },
  );

  testWidgets(
    'waits for the preview preference before loading month previews',
    (tester) async {
      final previewMode = Completer<CalendarCellPreviewMode>();
      final repository = FakeStoryLoopReadRepository();
      final eventRequests = <CalendarEventDateRange>[];

      await pumpCalendar(
        tester,
        repository: repository,
        relationshipStartDate: DateTime(2026, 5, 1),
        previewModeResult: previewMode.future,
        calendarEventRequests: eventRequests,
      );

      expect(repository.requestedMonths, isEmpty);
      expect(eventRequests, [
        (startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 31)),
      ]);
      await tester.tap(find.byKey(const Key('calendar-cell-preview-filter')));
      await tester.pump();
      expect(
        find.byKey(const Key('calendar-cell-preview-filter-sheet')),
        findsNothing,
      );

      previewMode.complete(CalendarCellPreviewMode.cardsOnly);
      await tester.pumpAndSettle();

      expect(repository.requestedMonths, [DateTime(2026, 5)]);
      expect(eventRequests, [
        (startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 31)),
      ]);
    },
  );

  testWidgets('moves to previous month after relationship start month', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();

    await pumpCalendar(
      tester,
      repository: repository,
      today: DateTime(2026, 6, 2),
    );

    expect(find.text('2026년 06월'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(repository.requestedMonths, [DateTime(2026, 6), DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [
      DateTime(2026, 6, 2),
      DateTime(2026, 5, 2),
    ]);
  });

  testWidgets('moves to a future month for shared schedules', (tester) async {
    final repository = FakeStoryLoopReadRepository();

    await pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2026년 06월'), findsOneWidget);
    expect(find.text('2026년 05월'), findsNothing);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets('does not add detail scrolling when empty content fits', (
    tester,
  ) async {
    await pumpCalendar(tester, repository: FakeStoryLoopReadRepository());
    final scrollFinder = find.byKey(const Key('calendar-scroll-view'));
    final scrollView = tester.widget<CustomScrollView>(scrollFinder);
    final metrics = CalendarMonthLayoutMetrics.forViewport(
      tester.getSize(scrollFinder).height,
    );

    expect(
      scrollView.controller!.position.maxScrollExtent,
      closeTo(metrics.weeklyScrollOffset, 0.5),
    );
  });

  testWidgets('does not add detail scrolling when cards and answers fit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(
        details: {DateTime(2026, 5, 5): completedDetail},
      ),
      initialDate: DateTime(2026, 5, 5),
    );
    final scrollFinder = find.byKey(const Key('calendar-scroll-view'));
    final scrollView = tester.widget<CustomScrollView>(scrollFinder);
    final metrics = CalendarMonthLayoutMetrics.forViewport(
      tester.getSize(scrollFinder).height,
    );

    expect(
      scrollView.controller!.position.maxScrollExtent,
      closeTo(metrics.weeklyScrollOffset, 0.5),
    );
  });

  testWidgets('uses thresholds and moves only one calendar state per gesture', (
    tester,
  ) async {
    await pumpCalendar(tester, repository: FakeStoryLoopReadRepository());
    final scrollView = tester.widget<CustomScrollView>(
      find.byKey(const Key('calendar-scroll-view')),
    );
    final controller = scrollView.controller!;
    final metrics = CalendarMonthLayoutMetrics.forViewport(
      tester.getSize(find.byKey(const Key('calendar-scroll-view'))).height,
    );

    expect(controller.offset, closeTo(metrics.standardScrollOffset, 0.5));

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, 40),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(metrics.standardScrollOffset, 0.5));

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 0.5));

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(metrics.standardScrollOffset, 0.5));

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(metrics.weeklyScrollOffset, 0.5));
  });

  testWidgets('resists small drags before snapping the calendar state', (
    tester,
  ) async {
    await pumpCalendar(tester, repository: FakeStoryLoopReadRepository());
    final scrollFinder = find.byKey(const Key('calendar-scroll-view'));
    final scrollView = tester.widget<CustomScrollView>(scrollFinder);
    final controller = scrollView.controller!;
    final startOffset = controller.offset;

    final gesture = await tester.startGesture(tester.getCenter(scrollFinder));
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    final recognizedStartOffset = controller.offset;

    await gesture.moveBy(const Offset(0, -16));
    await tester.pump();

    expect(controller.offset, closeTo(recognizedStartOffset, 0.5));

    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();

    expect(controller.offset - recognizedStartOffset, inInclusiveRange(5, 8));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(startOffset, 0.5));
  });

  testWidgets('does not rebuild the full screen while snapping states', (
    tester,
  ) async {
    await pumpCalendar(tester, repository: FakeStoryLoopReadRepository());
    final rebuildMessages = <String>[];
    final previousDebugPrint = debugPrint;
    final previousDebugPrintRebuildDirtyWidgets = debugPrintRebuildDirtyWidgets;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        rebuildMessages.add(message);
      }
    };
    debugPrintRebuildDirtyWidgets = true;

    try {
      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();
    } finally {
      debugPrint = previousDebugPrint;
      debugPrintRebuildDirtyWidgets = previousDebugPrintRebuildDirtyWidgets;
    }

    expect(
      rebuildMessages.where((message) => message.contains('CalendarScreen')),
      isEmpty,
    );
  });

  testWidgets(
    'keeps the date header pinned and hands detail scrolling off at its top',
    (tester) async {
      final repository = FakeStoryLoopReadRepository(
        details: {DateTime(2026, 5, 5): completedDetail},
      );
      await pumpCalendar(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 5, 5),
      );
      final scrollFinder = find.byKey(const Key('calendar-scroll-view'));
      final scrollView = tester.widget<CustomScrollView>(scrollFinder);
      final controller = scrollView.controller!;
      final metrics = CalendarMonthLayoutMetrics.forViewport(
        tester.getSize(scrollFinder).height,
      );

      await tester.drag(scrollFinder, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(metrics.weeklyScrollOffset, 0.5));

      final headerTop = tester.getTopLeft(find.text('5월 5일')).dy;
      await tester.drag(scrollFinder, const Offset(0, -320));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(metrics.weeklyScrollOffset));
      expect(tester.getTopLeft(find.text('5월 5일')).dy, closeTo(headerTop, 0.5));

      await tester.drag(scrollFinder, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(metrics.weeklyScrollOffset, 0.5));

      await tester.drag(scrollFinder, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(metrics.standardScrollOffset, 0.5));
    },
  );

  testWidgets('opens the shared event editor with the selected date', (
    tester,
  ) async {
    await pumpCalendar(tester, repository: FakeStoryLoopReadRepository());

    await tester.tap(find.byKey(const Key('calendar-add-event')));
    await tester.pumpAndSettle();

    expect(find.text('calendar event date 2026-05-10'), findsOneWidget);
  });
}
