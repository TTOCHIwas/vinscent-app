import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/characters/presentation/widgets/couple_character_avatar.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/home/presentation/home_screen.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/recordings/presentation/widgets/character_recording_control.dart';
import 'package:vinscent/features/story_loops/data/story_loop_card_preview.dart';
import 'package:vinscent/features/story_loops/data/story_loop_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_month_summary_day.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_summary.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';
import 'package:vinscent/features/story_loops/data/story_loop_status.dart';
import 'package:vinscent/features/story_loops/data/today_story_loop_summary.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_preview_surface.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';

const _storyAddButtonKey = Key('home-story-add-button');
const _questionBubbleKey = Key('home-question-speech-bubble');
const _storyLabel = '\uc624\ub298\uc758 \uc2a4\ud1a0\ub9ac';
const _storyCreateAction = '\uce74\ub4dc \uc791\uc131';
const _storyEditAction = '\uce74\ub4dc \uc218\uc815';
const _storyQuestionAction = '\uc624\ub298 \uc9c8\ubb38 \ubcf4\uae30';
const _storyAnswerAction = '\ub2f5\ubcc0 \ub0a8\uae30\uae30';
const _storyEmptyMessage =
    '\uc624\ub298 \uc2a4\ud1a0\ub9ac \uce74\ub4dc\ub97c \uc544\uc9c1 \uc544\ubb34\ub3c4 \uc62c\ub9ac\uc9c0 \uc54a\uc558\uc5b4\uc694.';
const _storyLoadingMessage =
    '\uc624\ub298 \uc2a4\ud1a0\ub9ac\ub97c \ubd88\ub7ec\uc624\uace0 \uc788\uc5b4\uc694.';
const _storyLoadError =
    '\uc624\ub298 \uc2a4\ud1a0\ub9ac\ub97c \ubd88\ub7ec\uc624\uc9c0 \ubabb\ud588\uc5b4\uc694.';
const _storyGenerating = '\uc9c8\ubb38 \uc0dd\uc131 \uc911';
const _storyPartnerAnswered =
    '\uc0c1\ub300\ubc29\uc740 \ub2f5\ubcc0\uc744 \ub0a8\uacbc\uc5b4\uc694.';
const _storyWaitingAnswer =
    '\uc0c1\ub300\ubc29\uc758 \ub2f5\ubcc0\uc744 \uae30\ub2e4\ub9ac\uace0 \uc788\uc5b4\uc694.';
const _storyAiPlaceholder =
    'AI \ud55c \uc904 \ud3c9\uc774 \uc5ec\uae30\uc5d0 \ud45c\uc2dc\ub420 \uc608\uc815\uc774\uc5d0\uc694.';

Key _storyThumbnailKey(String cardId) => Key('home-story-card-$cardId');

void main() {
  testWidgets(
    '\ube48 \uc2a4\ud1a0\ub9ac\ub294 \uc124\uba85 \ub300\uc2e0 \uc791\uc740 \ucd94\uac00 \ubc84\ud2bc\uc744 \ubcf4\uc5ec\uc900\ub2e4',
    (tester) async {
      await _pumpHome(
        tester,
        couple: _activeCouple,
        today: _today,
        todaySummary: _emptyTodaySummary(coupleDate: _today),
      );

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byKey(_storyAddButtonKey), findsOneWidget);
      expect(
        tester.getSize(find.byKey(_storyAddButtonKey)),
        const Size.square(56),
      );
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.text(_storyLabel), findsNothing);
      expect(find.text(_storyEmptyMessage), findsNothing);
      expect(find.text(_storyCreateAction), findsNothing);
      expect(find.byType(CoupleCharacterAvatar), findsOneWidget);
      expect(
        tester.getSize(find.byKey(CharacterRecordingControl.controlKey)),
        const Size.square(272),
      );
    },
  );

  testWidgets(
    '\uc9e7\uc740 \ud654\uba74\uc5d0\uc11c\ub3c4 \uc138\ub85c \uc2a4\ud06c\ub864\uacfc \uc624\ubc84\ud50c\ub85c\uc6b0\uac00 \uc5c6\ub2e4',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 520));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpHome(
        tester,
        couple: _activeCouple,
        today: _today,
        todaySummary: _emptyTodaySummary(coupleDate: _today),
      );

      expect(find.byType(Scrollable), findsNothing);
      expect(find.byKey(_storyAddButtonKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '\uc9c8\ubb38\uc774 \uc0dd\uc131\ub418\uba74 \uc9c8\ubb38 \uc704\uc5d0 \ud655\ub300\ub41c \uce74\ub4dc \ubbf8\ub9ac\ubcf4\uae30\ub97c \ubcf4\uc5ec\uc900\ub2e4',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 592));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpHome(
        tester,
        couple: _activeCouple,
        today: _today,
        todaySummary: sampleTodaySummary(
          coupleDate: _today,
          cards: [
            samplePreviewCard(
              id: 'card-2',
              authorUserId: 'partner-id',
              previewPath: 'previews/card-2.png',
              submittedAt: DateTime.parse('2026-05-31T09:00:00Z'),
            ),
            samplePreviewCard(
              authorUserId: _profile.id,
              submittedAt: DateTime.parse('2026-05-31T09:10:00Z'),
            ),
          ],
          question: StoryLoopQuestionSummary(
            question: _dailyQuestion,
            myAnswerExists: false,
            partnerAnswerExists: false,
            answerCount: 0,
          ),
        ),
      );

      expect(find.text(_dailyQuestion.questionText), findsOneWidget);
      final questionBubble = find.byKey(_questionBubbleKey);
      final characterControl = find.byKey(CharacterRecordingControl.controlKey);
      expect(questionBubble, findsOneWidget);
      expect(
        find.descendant(of: questionBubble, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(questionBubble).dy,
        lessThan(tester.getTopLeft(characterControl).dy),
      );
      final myCard = find.byKey(_storyThumbnailKey('card-1'));
      final partnerCard = find.byKey(_storyThumbnailKey('card-2'));
      expect(myCard, findsOneWidget);
      expect(partnerCard, findsOneWidget);
      expect(tester.getSize(myCard), const Size(160, 200));
      expect(tester.getSize(partnerCard), const Size(160, 200));
      expect(
        tester.getTopLeft(myCard).dx,
        lessThan(tester.getTopLeft(partnerCard).dx),
      );
      expect(
        tester.getTopLeft(partnerCard).dx - tester.getTopRight(myCard).dx,
        16,
      );
      expect(tester.getTopLeft(myCard).dy, tester.getTopLeft(partnerCard).dy);
      expect(
        tester.getBottomLeft(myCard).dy,
        lessThan(tester.getTopLeft(find.text(_dailyQuestion.questionText)).dy),
      );
      expect(find.byKey(_storyAddButtonKey), findsNothing);
      expect(find.text(_storyLabel), findsNothing);
      expect(find.text(_storyAnswerAction), findsNothing);
    },
  );

  testWidgets(
    '\ub85c\ub529 \uc0c1\ud0dc\ub294 \ubb38\uad6c \uc5c6\uc774 \uc791\uc740 \uc9c4\ud589 \ud45c\uc2dc\ub85c \ubcf4\uc5ec\uc900\ub2e4',
    (tester) async {
      await _pumpHome(
        tester,
        couple: _activeCouple,
        today: _today,
        storyLoopRepository: _PendingStoryLoopReadRepository(),
        settle: false,
      );

      expect(find.text(_storyLabel), findsNothing);
      expect(find.text(_storyLoadingMessage), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    '\ub85c\ub4dc \uc2e4\ud328\ub294 \ubb38\uad6c \ub300\uc2e0 \uc7ac\uc2dc\ub3c4 \uc544\uc774\ucf58\uc744 \ubcf4\uc5ec\uc900\ub2e4',
    (tester) async {
      await _pumpHome(
        tester,
        couple: _activeCouple,
        today: _today,
        storyLoopRepository: _ThrowingStoryLoopReadRepository(),
      );

      expect(find.text(_storyLoadError), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    },
  );

  testWidgets(
    '\ucee4\ud50c \uc815\ubcf4\uac00 \uc5c6\uc73c\uba74 \ubcf5\uad6c\uc5d0 \ud544\uc694\ud55c \uc0c1\ud0dc \ubb38\uad6c\ub9cc \ubcf4\uc5ec\uc900\ub2e4',
    (tester) async {
      await _pumpHome(tester, couple: null, today: _today);

      expect(
        find.text(
          '\ucee4\ud50c \uc815\ubcf4\ub97c \ucc3e\uc744 \uc218 \uc5c6\uc5b4\uc694.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(_storyAddButtonKey), findsNothing);
      expect(
        find.text(
          '\uc624\ub298 \uc2a4\ud1a0\ub9ac\ub97c \uc544\uc9c1 \ud655\uc778\ud560 \uc218 \uc5c6\uc5b4\uc694.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    '\uc2dc\uc791\uc77c\uc774 \uc5c6\uc73c\uba74 \ubcf5\uad6c\uc5d0 \ud544\uc694\ud55c \uc0c1\ud0dc \ubb38\uad6c\ub9cc \ubcf4\uc5ec\uc900\ub2e4',
    (tester) async {
      await _pumpHome(tester, couple: _activeCoupleWithoutDate, today: _today);

      expect(
        find.text(
          '\ucc98\uc74c \ub9cc\ub09c \ub0a0\uc744 \uba3c\uc800 \uc785\ub825\ud574 \uc8fc\uc138\uc694.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(_storyAddButtonKey), findsNothing);
    },
  );

  testWidgets(
    '\ub0b4 \uce74\ub4dc\ub9cc \uc788\uc73c\uba74 \uc67c\ucabd \ubbf8\ub9ac\ubcf4\uae30\ub85c \uc218\uc815 \uc9c4\uc785\uc810\uc744 \ubcf4\uc5ec\uc900\ub2e4',
    (tester) async {
      await _pumpHome(
        tester,
        couple: _activeCouple,
        today: _today,
        todaySummary: _summaryWithoutQuestion(
          coupleDate: _today,
          loopStatus: StoryLoopStatus.waitingPartnerCard,
          cardCount: 1,
          canEditStory: true,
          canAnswerQuestion: false,
          storyEditLocked: false,
          cards: [
            samplePreviewCard(
              authorUserId: _profile.id,
              submittedAt: DateTime.parse('2026-05-31T09:00:00Z'),
            ),
          ],
        ),
      );

      final thumbnail = find.byKey(_storyThumbnailKey('card-1'));
      expect(thumbnail, findsOneWidget);
      expect(tester.widget<InkWell>(thumbnail).onTap, isNotNull);
      expect(
        tester.getCenter(thumbnail).dx,
        lessThan(tester.getSize(find.byType(HomeScreen)).width / 2),
      );
      expect(find.byKey(_storyAddButtonKey), findsNothing);
      expect(find.text(_storyEditAction), findsNothing);
    },
  );

  testWidgets(
    '\uc0c1\ub300 \uce74\ub4dc\ub9cc \uc788\uc73c\uba74 \uc378\ub124\uc77c \uc606\uc5d0 \ub0b4 \uce74\ub4dc \ucd94\uac00 \ubc84\ud2bc\uc744 \ubcf4\uc5ec\uc900\ub2e4',
    (tester) async {
      await _pumpHome(
        tester,
        couple: _activeCouple,
        today: _today,
        todaySummary: _summaryWithoutQuestion(
          coupleDate: _today,
          loopStatus: StoryLoopStatus.waitingPartnerCard,
          cardCount: 1,
          canEditStory: true,
          canAnswerQuestion: false,
          storyEditLocked: false,
          cards: [
            samplePreviewCard(
              authorUserId: 'partner-id',
              submittedAt: DateTime.parse('2026-05-31T09:00:00Z'),
            ),
          ],
        ),
      );

      final partnerCard = find.byKey(_storyThumbnailKey('card-1'));
      final addButton = find.byKey(_storyAddButtonKey);
      final homeCenterX = tester.getCenter(find.byType(HomeScreen)).dx;
      expect(partnerCard, findsOneWidget);
      expect(addButton, findsOneWidget);
      expect(tester.getCenter(addButton).dx, lessThan(homeCenterX));
      expect(tester.getCenter(partnerCard).dx, greaterThan(homeCenterX));
      expect(find.text(_storyCreateAction), findsNothing);
    },
  );

  testWidgets(
    '\ub450 \uce74\ub4dc\uac00 \ubaa8\uc774\uba74 \ub0b4 \uce74\ub4dc\uc640 \uc0c1\ub300 \uce74\ub4dc\ub97c \uc67c\ucabd\uacfc \uc624\ub978\ucabd\uc5d0 \ubcf4\uc5ec\uc900\ub2e4',
    (tester) async {
      await _pumpHome(
        tester,
        couple: _activeCouple,
        today: _today,
        todaySummary: _summaryWithoutQuestion(
          coupleDate: _today,
          loopStatus: null,
          cardCount: 2,
          storyEditLocked: false,
          canEditStory: false,
          canAnswerQuestion: false,
          cards: [
            samplePreviewCard(
              id: 'card-2',
              authorUserId: 'partner-id',
              previewPath: 'previews/card-2.png',
            ),
            samplePreviewCard(authorUserId: _profile.id),
          ],
        ),
      );

      final myCard = find.byKey(_storyThumbnailKey('card-1'));
      final partnerCard = find.byKey(_storyThumbnailKey('card-2'));
      expect(myCard, findsOneWidget);
      expect(partnerCard, findsOneWidget);
      expect(find.byType(StoryCardPreviewSurface), findsNWidgets(2));
      expect(
        tester.getCenter(myCard).dx,
        lessThan(tester.getCenter(partnerCard).dx),
      );
      expect(
        tester.getCenter(myCard).dy,
        lessThan(tester.getCenter(find.byType(HomeScreen)).dy),
      );
      expect(find.byKey(_storyAddButtonKey), findsNothing);
      expect(find.text(_storyGenerating), findsNothing);
    },
  );

  for (final scenario
      in <
        ({
          String name,
          bool myAnswerExists,
          bool partnerAnswerExists,
          String removedMessage,
        })
      >[
        (
          name: '\uc0c1\ub300\ub9cc \ub2f5\ubcc0\ud55c \uc0c1\ud0dc',
          myAnswerExists: false,
          partnerAnswerExists: true,
          removedMessage: _storyPartnerAnswered,
        ),
        (
          name: '\ub098\ub9cc \ub2f5\ubcc0\ud55c \uc0c1\ud0dc',
          myAnswerExists: true,
          partnerAnswerExists: false,
          removedMessage: _storyWaitingAnswer,
        ),
        (
          name: '\ub458 \ub2e4 \ub2f5\ubcc0\ud55c \uc0c1\ud0dc',
          myAnswerExists: true,
          partnerAnswerExists: true,
          removedMessage: _storyAiPlaceholder,
        ),
      ]) {
    testWidgets(
      '${scenario.name}\uc5d0\uc11c\ub3c4 \uc9c8\ubb38 \ubb38\uad6c\ub97c \uacc4\uc18d \ubcf4\uc5ec\uc900\ub2e4',
      (tester) async {
        await _pumpHome(
          tester,
          couple: _activeCouple,
          today: _today,
          todaySummary: sampleTodaySummary(
            coupleDate: _today,
            cards: [
              samplePreviewCard(authorUserId: _profile.id),
              samplePreviewCard(
                id: 'card-2',
                authorUserId: 'partner-id',
                previewPath: 'previews/card-2.png',
              ),
            ],
            question: StoryLoopQuestionSummary(
              question: _dailyQuestion,
              myAnswerExists: scenario.myAnswerExists,
              partnerAnswerExists: scenario.partnerAnswerExists,
              answerCount:
                  (scenario.myAnswerExists ? 1 : 0) +
                  (scenario.partnerAnswerExists ? 1 : 0),
            ),
          ),
        );

        expect(find.text(_dailyQuestion.questionText), findsOneWidget);
        expect(find.text(scenario.removedMessage), findsNothing);
        expect(find.text(_storyQuestionAction), findsNothing);
        expect(find.text(_storyAnswerAction), findsNothing);
      },
    );
  }
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required Couple? couple,
  required DateTime today,
  TodayStoryLoopSummary? todaySummary,
  StoryLoopReadRepository? storyLoopRepository,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => couple,
        ),
        todayControllerProvider.overrideWithBuild((ref, notifier) => today),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        storyLoopReadRepositoryProvider.overrideWithValue(
          storyLoopRepository ??
              FakeStoryLoopReadRepository(todaySummary: todaySummary),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _PendingStoryLoopReadRepository implements StoryLoopReadRepository {
  @override
  Future<TodayStoryLoopSummary?> fetchTodaySummary() {
    return Completer<TodayStoryLoopSummary?>().future;
  }

  @override
  Future<StoryLoopDetail?> fetchDetail(DateTime date) async {
    return null;
  }

  @override
  Future<List<StoryLoopMonthSummaryDay>> fetchMonthSummary(
    DateTime month,
  ) async {
    return const [];
  }
}

class _ThrowingStoryLoopReadRepository implements StoryLoopReadRepository {
  @override
  Future<TodayStoryLoopSummary?> fetchTodaySummary() async {
    throw Exception('story summary failed');
  }

  @override
  Future<StoryLoopDetail?> fetchDetail(DateTime date) async {
    return null;
  }

  @override
  Future<List<StoryLoopMonthSummaryDay>> fetchMonthSummary(
    DateTime month,
  ) async {
    return const [];
  }
}

final _today = DateTime(2026, 5, 31);

final _activeCouple = activeCouple(currentDate: _today);

final _activeCoupleWithoutDate = activeCoupleWithoutDate(currentDate: _today);

final _profile = UserProfile(
  id: 'user-id',
  displayName: '\uc5f0\uc778',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _dailyQuestion = sampleDailyQuestion(assignedDate: _today);

TodayStoryLoopSummary _emptyTodaySummary({required DateTime coupleDate}) {
  return TodayStoryLoopSummary(
    coupleId: 'couple-id',
    coupleDate: coupleDate,
    accessMode: CoupleAccessMode.active,
    loopId: null,
    loopStatus: null,
    storyEditLocked: false,
    canEditStory: true,
    canAnswerQuestion: false,
    cardCount: 0,
    cards: const [],
    question: null,
  );
}

TodayStoryLoopSummary _summaryWithoutQuestion({
  required DateTime coupleDate,
  required StoryLoopStatus? loopStatus,
  required int cardCount,
  required bool storyEditLocked,
  required bool canEditStory,
  required bool canAnswerQuestion,
  required List<StoryLoopCardPreview> cards,
}) {
  return TodayStoryLoopSummary(
    coupleId: 'couple-id',
    coupleDate: coupleDate,
    accessMode: CoupleAccessMode.active,
    loopId: 'loop-id',
    loopStatus: loopStatus,
    storyEditLocked: storyEditLocked,
    canEditStory: canEditStory,
    canAnswerQuestion: canAnswerQuestion,
    cardCount: cardCount,
    cards: cards,
    question: null,
  );
}
