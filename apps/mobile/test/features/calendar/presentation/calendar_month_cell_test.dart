import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/public_holiday.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_month_story_cell.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';

import '../../../support/story_loop_fixtures.dart';
import 'calendar_screen_test_support.dart';

void main() {
  testWidgets('늦게 도착한 일정 미리보기를 셀 안에서 부드럽게 표시한다', (tester) async {
    final date = DateTime(2026, 5, 10);
    var events = const <CoupleCalendarEvent>[];
    late StateSetter updateCell;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 52,
            height: 72,
            child: StatefulBuilder(
              builder: (context, setState) {
                updateCell = setState;
                return CalendarMonthStoryCell(
                  date: date,
                  textColor: AppColors.textPrimary,
                  isSelected: false,
                  summary: null,
                  events: events,
                );
              },
            ),
          ),
        ),
      ),
    );

    updateCell(() {
      events = [calendarEvent(id: 'event-1', title: '함께 산책', date: date)];
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    final transition = find.byKey(
      const Key('calendar-cell-content-transition-2026-05-10'),
    );
    expect(transition, findsOneWidget);
    final fades = tester.widgetList<FadeTransition>(
      find.descendant(of: transition, matching: find.byType(FadeTransition)),
    );
    expect(fades.length, 2);
    expect(
      fades.any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
      isTrue,
    );

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-event-indicator-event-1')),
      findsOneWidget,
    );
  });

  testWidgets('일요일과 공휴일을 휴일 색상으로 표시한다', (tester) async {
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      publicHolidays: [
        PublicHoliday(
          region: PublicHolidayRegion.southKorea,
          date: DateTime(2026, 5, 5),
          names: const ['어린이날'],
        ),
      ],
    );

    final sundayHeader = tester.widget<Text>(find.text('일').first);
    final sundayCell = find.byKey(
      const ValueKey('calendar-month-story-cell-empty-2026-05-03'),
    );
    final holidayCell = find.byKey(
      const ValueKey('calendar-month-story-cell-empty-2026-05-05'),
    );
    final sundayDate = tester.widget<Text>(
      find.descendant(of: sundayCell, matching: find.text('3')),
    );
    final holidayDate = tester.widget<Text>(
      find.descendant(of: holidayCell, matching: find.text('5')),
    );

    expect(sundayHeader.style?.color, AppColors.calendarHoliday);
    expect(sundayDate.style?.color, AppColors.calendarHoliday);
    expect(holidayDate.style?.color, AppColors.calendarHoliday);
  });

  testWidgets('shows a shared event in its cell and selected day detail', (
    tester,
  ) async {
    final event = calendarEvent(
      id: 'event-1',
      title: '함께 여행',
      date: DateTime(2026, 5, 5),
    );
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      calendarEvents: [event],
    );

    expect(
      find.byKey(const ValueKey('calendar-event-indicator-event-1')),
      findsOneWidget,
    );
    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('함께 여행'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-event-menu-event-1')),
      findsOneWidget,
    );
  });

  testWidgets(
    'keeps cardless event artwork readable across expanded and weekly states',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final events = [
        calendarEvent(
          id: 'event-without-art',
          title: '라 그림 없는 일정',
          date: DateTime(2026, 5, 10),
        ),
        calendarEvent(
          id: 'event-with-art',
          title: '가 그림 일정',
          date: DateTime(2026, 5, 10),
          artwork: const CoupleCalendarEventArtwork(
            previewPath: 'event.webp',
            drawingDataPath: 'event.json.gz',
          ),
        ),
        calendarEvent(
          id: 'event-with-second-art',
          title: '나 그림 일정',
          date: DateTime(2026, 5, 10),
          artwork: const CoupleCalendarEventArtwork(
            previewPath: 'event-2.webp',
            drawingDataPath: 'event-2.json.gz',
          ),
        ),
        calendarEvent(
          id: 'event-with-third-art',
          title: '다 그림 일정',
          date: DateTime(2026, 5, 10),
          artwork: const CoupleCalendarEventArtwork(
            previewPath: 'event-3.webp',
            drawingDataPath: 'event-3.json.gz',
          ),
        ),
      ];
      await pumpCalendar(
        tester,
        repository: FakeStoryLoopReadRepository(),
        calendarEvents: events,
      );

      expect(
        find.byKey(const ValueKey('calendar-event-indicator-event-with-art')),
        findsOneWidget,
      );
      final firstArtwork = find.byKey(
        const ValueKey('calendar-event-indicator-event-with-art'),
      );
      final standardArtworkSize = tester.getSize(firstArtwork);
      expect(standardArtworkSize.width, greaterThan(18));
      expect(standardArtworkSize.height, greaterThan(18));
      expect(
        find.byKey(
          const ValueKey('calendar-event-indicator-event-with-second-art'),
        ),
        findsNothing,
      );
      expect(find.text('+3'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();

      final secondArtwork = find.byKey(
        const ValueKey('calendar-event-indicator-event-with-second-art'),
      );
      final thirdArtwork = find.byKey(
        const ValueKey('calendar-event-indicator-event-with-third-art'),
      );
      expect(secondArtwork, findsOneWidget);
      expect(thirdArtwork, findsOneWidget);
      final expandedArtworkSize = tester.getSize(firstArtwork);
      expect(expandedArtworkSize.width, greaterThan(18));
      expect(expandedArtworkSize.height, greaterThan(18));
      expect(tester.getSize(secondArtwork), expandedArtworkSize);
      expect(tester.getSize(thirdArtwork), expandedArtworkSize);
      expect(
        tester.getCenter(secondArtwork).dy,
        greaterThan(tester.getCenter(firstArtwork).dy),
      );
      expect(
        tester.getCenter(thirdArtwork).dy,
        greaterThan(tester.getCenter(secondArtwork).dy),
      );
      final artworkCell = find.byKey(
        const ValueKey('calendar-month-story-cell-empty-2026-05-10'),
      );
      expect(
        tester.getRect(thirdArtwork).bottom - tester.getRect(firstArtwork).top,
        greaterThan(tester.getSize(artworkCell).height * 0.55),
      );
      expect(find.text('+1'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('calendar-event-indicator-event-with-second-art'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('calendar-event-indicator-event-with-third-art'),
        ),
        findsNothing,
      );
      final weeklyArtworkSize = tester.getSize(firstArtwork);
      expect(weeklyArtworkSize.width, greaterThan(18));
      expect(weeklyArtworkSize.height, greaterThan(18));
      expect(find.text('+3'), findsOneWidget);
    },
  );

  testWidgets('moves event artwork into the expanded cell behind the card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeStoryLoopReadRepository(
      monthSummaries: {
        DateTime(2026, 5): [
          sampleMonthSummaryDay(
            coupleDate: DateTime(2026, 5, 5),
            cardCount: 1,
            cards: [
              samplePreviewCard(
                id: 'event-day-card',
                submittedAt: DateTime(2026, 5, 5, 9),
              ),
            ],
          ),
          sampleMonthSummaryDay(
            coupleDate: DateTime(2026, 5, 6),
            cardCount: 1,
            cards: [
              samplePreviewCard(
                id: 'card-only-day-card',
                submittedAt: DateTime(2026, 5, 6, 9),
              ),
            ],
          ),
        ],
      },
    );
    final events = [
      calendarEvent(
        id: 'event-day-art-1',
        title: '가 일정',
        date: DateTime(2026, 5, 5),
        artwork: const CoupleCalendarEventArtwork(
          previewPath: 'event-1.webp',
          drawingDataPath: 'event-1.json.gz',
        ),
      ),
      calendarEvent(
        id: 'event-day-art-2',
        title: '나 일정',
        date: DateTime(2026, 5, 5),
        artwork: const CoupleCalendarEventArtwork(
          previewPath: 'event-2.webp',
          drawingDataPath: 'event-2.json.gz',
        ),
      ),
      calendarEvent(
        id: 'event-day-art-3',
        title: '다 일정',
        date: DateTime(2026, 5, 5),
        artwork: const CoupleCalendarEventArtwork(
          previewPath: 'event-3.webp',
          drawingDataPath: 'event-3.json.gz',
        ),
      ),
      calendarEvent(
        id: 'event-only-art',
        title: '라 일정',
        date: DateTime(2026, 5, 7),
        artwork: const CoupleCalendarEventArtwork(
          previewPath: 'event-only.webp',
          drawingDataPath: 'event-only.json.gz',
        ),
      ),
    ];

    await pumpCalendar(tester, repository: repository, calendarEvents: events);

    final firstArtwork = find.byKey(
      const ValueKey('calendar-event-indicator-event-day-art-1'),
    );
    final card = find.byKey(
      const ValueKey('calendar-month-story-card-event-day-card'),
    );
    final cardOnly = find.byKey(
      const ValueKey('calendar-month-story-card-card-only-day-card'),
    );
    final eventOnlyArtwork = find.byKey(
      const ValueKey('calendar-event-indicator-event-only-art'),
    );
    final mixedCell = find.byKey(
      const ValueKey('calendar-month-story-cell-single-2026-05-05'),
    );
    final dateLabel = find.descendant(of: mixedCell, matching: find.text('5'));
    final overflowBadge = find.byKey(
      const ValueKey('calendar-event-overflow-2026-05-05'),
    );
    final compactOverflowBadgeHeight = tester.getSize(overflowBadge).height;
    expect(tester.getSize(firstArtwork), const Size.square(18));
    expect(
      tester.getSize(eventOnlyArtwork).width,
      greaterThan(tester.getSize(firstArtwork).width),
    );
    expect(
      tester.getSize(card).width,
      closeTo(tester.getSize(cardOnly).width, 0.1),
    );
    expect(
      tester.getSize(card).height,
      closeTo(tester.getSize(cardOnly).height, 0.1),
    );
    expect(
      tester.getCenter(firstArtwork).dy,
      closeTo(tester.getCenter(dateLabel).dy, 0.5),
    );
    expect(
      tester.getRect(firstArtwork).bottom,
      lessThanOrEqualTo(tester.getRect(card).top),
    );

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();

    final secondArtwork = find.byKey(
      const ValueKey('calendar-event-indicator-event-day-art-2'),
    );
    final thirdArtwork = find.byKey(
      const ValueKey('calendar-event-indicator-event-day-art-3'),
    );
    expect(secondArtwork, findsOneWidget);
    expect(thirdArtwork, findsNothing);
    expect(tester.getSize(firstArtwork).width, greaterThan(18));
    expect(
      tester.getSize(card).width,
      lessThanOrEqualTo(tester.getSize(cardOnly).width),
    );
    expect(
      tester.getCenter(firstArtwork).dy,
      greaterThan(tester.getCenter(dateLabel).dy + 10),
    );
    expect(
      tester.getRect(secondArtwork).overlaps(tester.getRect(firstArtwork)),
      false,
    );
    expect(
      tester.getCenter(secondArtwork).dx,
      greaterThan(tester.getCenter(firstArtwork).dx),
    );
    expect(
      math.max(
        tester.getRect(firstArtwork).bottom,
        tester.getRect(secondArtwork).bottom,
      ),
      lessThanOrEqualTo(tester.getRect(card).top),
    );
    expect(
      tester.getSize(overflowBadge).height,
      closeTo(compactOverflowBadgeHeight, 0.1),
    );
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('keeps preview cache keys stable across calendar states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeStoryLoopReadRepository(
      monthSummaries: {
        DateTime(2026, 5): [
          sampleMonthSummaryDay(
            coupleDate: DateTime(2026, 5, 5),
            cardCount: 1,
            cards: [
              samplePreviewCard(
                id: 'stable-preview-card',
                submittedAt: DateTime(2026, 5, 5, 9),
              ).copyWith(previewUrl: 'https://example.com/stable-card.png'),
            ],
          ),
        ],
      },
    );
    final event = calendarEvent(
      id: 'stable-preview-artwork',
      title: '그림 일정',
      date: DateTime(2026, 5, 5),
      artwork: const CoupleCalendarEventArtwork(
        previewPath: 'stable-event.webp',
        drawingDataPath: 'stable-event.json.gz',
        previewUrl: 'https://example.com/stable-event.webp',
      ),
    );

    await pumpCalendar(tester, repository: repository, calendarEvents: [event]);

    final card = find.byKey(
      const ValueKey('calendar-month-story-card-stable-preview-card'),
    );
    final artwork = find.byKey(
      const ValueKey('calendar-event-indicator-stable-preview-artwork'),
    );
    final compactCardSize = tester.getSize(card);
    final compactArtworkSize = tester.getSize(artwork);
    final compactCardKey = await _imageProviderKey(tester, card);
    final compactArtworkKey = await _imageProviderKey(tester, artwork);
    expect(_imageWidget(tester, card).gaplessPlayback, true);
    expect(_imageWidget(tester, artwork).gaplessPlayback, true);

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(card).width, greaterThan(compactCardSize.width));
    expect(
      tester.getSize(artwork).width,
      greaterThan(compactArtworkSize.width),
    );
    expect(await _imageProviderKey(tester, card), compactCardKey);
    expect(await _imageProviderKey(tester, artwork), compactArtworkKey);

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();

    expect(await _imageProviderKey(tester, card), compactCardKey);
    expect(await _imageProviderKey(tester, artwork), compactArtworkKey);
  });

  testWidgets('prioritizes the default anniversary label in a mixed cell', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      monthSummaries: {
        DateTime(2026, 5): [
          sampleMonthSummaryDay(
            coupleDate: DateTime(2026, 5, 10),
            cardCount: 1,
            cards: [
              samplePreviewCard(
                id: 'anniversary-day-card',
                submittedAt: DateTime(2026, 5, 10, 9),
              ),
            ],
          ),
        ],
      },
    );
    final event = calendarEvent(
      id: 'anniversary-day-event',
      title: '기념일 일정',
      date: DateTime(2026, 5, 10),
      artwork: const CoupleCalendarEventArtwork(
        previewPath: 'anniversary-event.webp',
        drawingDataPath: 'anniversary-event.json.gz',
      ),
    );

    await pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 1),
      calendarEvents: [event],
    );

    final cell = find.byKey(
      const ValueKey('calendar-month-story-cell-single-2026-05-10'),
    );
    expect(find.descendant(of: cell, matching: find.text('10일')), findsOne);
    expect(
      find.byKey(
        const ValueKey('calendar-event-indicator-anniversary-day-event'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('calendar-month-story-card-anniversary-day-card'),
      ),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();

    final artwork = find.byKey(
      const ValueKey('calendar-event-indicator-anniversary-day-event'),
    );
    final card = find.byKey(
      const ValueKey('calendar-month-story-card-anniversary-day-card'),
    );
    expect(artwork, findsOneWidget);
    expect(
      tester.getRect(artwork).bottom,
      lessThanOrEqualTo(tester.getRect(card).top),
    );
  });

  testWidgets('shows inclusive default anniversaries without stored events', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      relationshipStartDate: DateTime(2026, 5, 1),
    );

    expect(find.text('10일'), findsNWidgets(2));
  });

  testWidgets('selects a future date without requesting story history', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    final futureCell = find.byKey(
      const ValueKey('calendar-month-story-cell-empty-2026-06-02'),
    );
    await tester.tap(
      find.ancestor(of: futureCell, matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();

    expect(find.text('6월 2일'), findsOneWidget);
    expect(find.text('아직 일정이 없어요'), findsOneWidget);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets('deletes a shared event and refreshes the calendar immediately', (
    tester,
  ) async {
    final event = calendarEvent(
      id: 'event-to-delete',
      title: '삭제할 일정',
      date: DateTime(2026, 5, 5),
    );
    await pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      calendarEvents: [event],
    );

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();
    await scrollCalendarUp(tester);
    await tester.tap(
      find.byKey(const ValueKey('calendar-event-menu-event-to-delete')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-confirmation-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('일정을 삭제했어요'), findsOneWidget);
    expect(find.text('삭제할 일정'), findsNothing);
    expect(
      find.byKey(const ValueKey('calendar-event-indicator-event-to-delete')),
      findsNothing,
    );
  });

  testWidgets(
    'renders month summary cells for empty single and stacked cards',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = FakeStoryLoopReadRepository(
        monthSummaries: {
          DateTime(2026, 5): [
            sampleMonthSummaryDay(
              coupleDate: DateTime(2026, 5, 5),
              cardCount: 1,
              cards: [
                samplePreviewCard(
                  id: 'month-card-1',
                  submittedAt: DateTime(2026, 5, 5, 9, 0),
                ),
              ],
            ),
            sampleMonthSummaryDay(
              coupleDate: DateTime(2026, 5, 6),
              cardCount: 2,
              cards: [
                samplePreviewCard(
                  id: 'month-card-2',
                  submittedAt: DateTime(2026, 5, 6, 9, 20),
                ),
                samplePreviewCard(
                  id: 'month-card-3',
                  authorUserId: 'user-b',
                  previewPath: 'previews/card-3.png',
                  submittedAt: DateTime(2026, 5, 6, 9, 0),
                ),
              ],
            ),
          ],
        },
      );

      await pumpCalendar(
        tester,
        repository: repository,
        calendarEvents: [
          calendarEvent(
            id: 'stacked-day-event-without-artwork',
            title: 'plain event',
            date: DateTime(2026, 5, 6),
          ),
        ],
      );

      expect(
        find.byKey(
          const ValueKey('calendar-month-story-cell-single-2026-05-05'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('calendar-month-story-cell-stacked-2026-05-06'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-07'),
        ),
        findsOneWidget,
      );
      expect(find.byType(CalendarMonthStoryCell), findsWidgets);

      final singleCardCell = find.byKey(
        const ValueKey('calendar-month-story-cell-single-2026-05-05'),
      );
      final stackedCardCell = find.byKey(
        const ValueKey('calendar-month-story-cell-stacked-2026-05-06'),
      );
      expect(tester.getSize(singleCardCell).width, greaterThanOrEqualTo(36));
      expect(tester.getSize(singleCardCell).height, greaterThanOrEqualTo(48));

      final singleCard = find.byKey(
        const ValueKey('calendar-month-story-card-month-card-1'),
      );
      final firstStackedCard = find.byKey(
        const ValueKey('calendar-month-story-card-month-card-2'),
      );
      final secondStackedCard = find.byKey(
        const ValueKey('calendar-month-story-card-month-card-3'),
      );
      expect(singleCard, findsOneWidget);
      expect(firstStackedCard, findsOneWidget);
      expect(secondStackedCard, findsOneWidget);
      final cardSize = tester.getSize(singleCard);
      expect(tester.getSize(firstStackedCard), cardSize);
      expect(tester.getSize(secondStackedCard), cardSize);
      expect(
        tester.getCenter(firstStackedCard).dy,
        closeTo(tester.getCenter(secondStackedCard).dy, 0.5),
      );
      expect(
        cardSize.width / cardSize.height,
        closeTo(storyCardCanvasAspectRatio, 0.001),
      );

      final dateInkWell = find.ancestor(
        of: singleCardCell,
        matching: find.byType(InkWell),
      );
      expect(dateInkWell, findsOneWidget);
      expect(
        tester.widget<InkWell>(dateInkWell).child,
        isA<CalendarMonthStoryCell>(),
      );
      final singleCardDecorations = framedDecorations(tester, singleCardCell);
      final stackedCardDecorations = framedDecorations(tester, stackedCardCell);
      expect(singleCardDecorations, hasLength(1));
      expect(stackedCardDecorations, hasLength(2));
      for (final decoration in [
        ...singleCardDecorations,
        ...stackedCardDecorations,
      ]) {
        expect(decoration.border, isNull);
        expect(decoration.boxShadow, hasLength(1));
      }

      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();

      final expandedSingleSize = tester.getSize(singleCard);
      final expandedStackedSize = tester.getSize(firstStackedCard);
      expect(expandedSingleSize.width, greaterThan(cardSize.width));
      expect(
        expandedSingleSize.width,
        lessThanOrEqualTo(tester.getSize(singleCardCell).width),
      );
      expect(expandedStackedSize.width, greaterThan(cardSize.width));
      expect(tester.getSize(secondStackedCard), expandedStackedSize);
      final expandedStackCenterGap =
          tester.getCenter(firstStackedCard).dy -
          tester.getCenter(secondStackedCard).dy;
      expect(
        expandedStackCenterGap,
        greaterThan(expandedStackedSize.height * 0.55),
      );
      expect(
        expandedStackedSize.height + expandedStackCenterGap,
        greaterThan(tester.getSize(stackedCardCell).height * 0.5),
      );
      expect(
        tester.getCenter(singleCard).dx,
        closeTo(tester.getCenter(singleCardCell).dx, 0.5),
      );
    },
  );

  testWidgets('spreads two mixed cards below event artwork', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeStoryLoopReadRepository(
      monthSummaries: {
        DateTime(2026, 5): [
          sampleMonthSummaryDay(
            coupleDate: DateTime(2026, 5, 6),
            cardCount: 2,
            cards: [
              samplePreviewCard(
                id: 'artwork-day-back-card',
                submittedAt: DateTime(2026, 5, 6, 9),
              ),
              samplePreviewCard(
                id: 'artwork-day-front-card',
                authorUserId: 'user-b',
                submittedAt: DateTime(2026, 5, 6, 9, 20),
              ),
            ],
          ),
        ],
      },
    );

    await pumpCalendar(
      tester,
      repository: repository,
      calendarEvents: [
        calendarEvent(
          id: 'stacked-day-event-with-artwork',
          title: 'artwork event',
          date: DateTime(2026, 5, 6),
          artwork: const CoupleCalendarEventArtwork(
            previewPath: 'event.webp',
            drawingDataPath: 'event.json.gz',
          ),
        ),
      ],
    );
    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();

    final backCard = find.byKey(
      const ValueKey('calendar-month-story-card-artwork-day-back-card'),
    );
    final frontCard = find.byKey(
      const ValueKey('calendar-month-story-card-artwork-day-front-card'),
    );
    final artwork = find.byKey(
      const ValueKey('calendar-event-indicator-stacked-day-event-with-artwork'),
    );
    final mixedCell = find.byKey(
      const ValueKey('calendar-month-story-cell-stacked-2026-05-06'),
    );
    final cardCenterGap =
        tester.getCenter(frontCard).dy - tester.getCenter(backCard).dy;
    final cardHorizontalCenterGap =
        tester.getCenter(frontCard).dx - tester.getCenter(backCard).dx;
    expect(cardCenterGap, greaterThan(tester.getSize(backCard).height * 0.55));
    expect(
      cardHorizontalCenterGap,
      greaterThan(tester.getSize(backCard).width * 0.3),
    );
    expect(
      tester.getRect(artwork).bottom,
      lessThanOrEqualTo(
        math.min(tester.getRect(backCard).top, tester.getRect(frontCard).top),
      ),
    );
    expect(
      math.max(
        tester.getRect(backCard).bottom,
        tester.getRect(frontCard).bottom,
      ),
      greaterThan(tester.getCenter(mixedCell).dy),
    );
  });

  testWidgets('scales expanded calendar cards with a tablet cell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeStoryLoopReadRepository(
      monthSummaries: {
        DateTime(2026, 5): [
          sampleMonthSummaryDay(
            coupleDate: DateTime(2026, 5, 5),
            cardCount: 1,
            cards: [
              samplePreviewCard(
                id: 'tablet-card',
                submittedAt: DateTime(2026, 5, 5, 9),
              ),
            ],
          ),
          sampleMonthSummaryDay(
            coupleDate: DateTime(2026, 5, 6),
            cardCount: 2,
            cards: [
              samplePreviewCard(
                id: 'tablet-back-card',
                submittedAt: DateTime(2026, 5, 6, 9),
              ),
              samplePreviewCard(
                id: 'tablet-front-card',
                authorUserId: 'user-b',
                submittedAt: DateTime(2026, 5, 6, 9, 20),
              ),
            ],
          ),
        ],
      },
    );

    await pumpCalendar(tester, repository: repository);
    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(
      const ValueKey('calendar-month-story-card-tablet-card'),
    );
    final cell = find.byKey(
      const ValueKey('calendar-month-story-cell-single-2026-05-05'),
    );
    final backCard = find.byKey(
      const ValueKey('calendar-month-story-card-tablet-back-card'),
    );
    final frontCard = find.byKey(
      const ValueKey('calendar-month-story-card-tablet-front-card'),
    );
    expect(tester.getSize(card).width, greaterThan(48));
    expect(
      tester.getSize(card).width,
      lessThanOrEqualTo(tester.getSize(cell).width),
    );
    expect(tester.getCenter(card).dx, closeTo(tester.getCenter(cell).dx, 0.5));
    expect(tester.getSize(backCard).width, greaterThan(48));
    expect(
      tester.getSize(backCard).width,
      lessThanOrEqualTo(tester.getSize(cell).width),
    );
    expect(tester.getSize(frontCard), tester.getSize(backCard));
    expect(
      tester.getCenter(frontCard).dy - tester.getCenter(backCard).dy,
      greaterThan(tester.getSize(backCard).height * 0.55),
    );
  });
}

Image _imageWidget(WidgetTester tester, Finder surface) {
  final image = find.descendant(of: surface, matching: find.byType(Image));
  expect(image, findsOneWidget);
  return tester.widget<Image>(image);
}

Future<Object> _imageProviderKey(WidgetTester tester, Finder surface) {
  return _imageWidget(
    tester,
    surface,
  ).image.obtainKey(const ImageConfiguration());
}
