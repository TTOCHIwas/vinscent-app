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

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';

void main() {
  testWidgets('홈 본문에 day count를 중복 표시하지 않고 빈 스토리 상태를 보여준다', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      todaySummary: _emptyTodaySummary(coupleDate: _today),
    );

    expect(find.text('우리'), findsNothing);
    expect(find.text('D+2', findRichText: true), findsNothing);
    expect(find.text('오늘의 스토리'), findsOneWidget);
    expect(find.text('오늘 스토리 카드를 아직 아무도 올리지 않았어요.'), findsOneWidget);
    expect(find.text('사진, 그림, 글로 오늘의 카드를 만들어 보세요.'), findsOneWidget);
    expect(find.text('\uce74\ub4dc\u0020\uc791\uc131'), findsOneWidget);
    expect(find.text('보고싶어'), findsNothing);
    expect(find.text('고마워'), findsNothing);
    expect(find.text('우울해'), findsNothing);
    expect(find.text('힘내'), findsNothing);
    expect(
      find.byKey(CharacterRecordingControl.controlKey),
      findsOneWidget,
    );
    expect(find.byType(CoupleCharacterAvatar), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(find.text('녹음'), findsNothing);
    expect(find.text('보기'), findsNothing);
    expect(find.text('현재 재생할 녹음이 없어요.'), findsNothing);
    expect(find.text('길게 눌러 최대 15초까지 녹음할 수 있어요.'), findsNothing);
  });

  testWidgets('질문이 생성되면 질문 문구를 보여준다', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      todaySummary: sampleTodaySummary(
        coupleDate: _today,
        question: StoryLoopQuestionSummary(
          question: _dailyQuestion,
          myAnswerExists: false,
          partnerAnswerExists: false,
          answerCount: 0,
        ),
      ),
    );

    expect(find.text('오늘의 스토리'), findsOneWidget);
    expect(find.text(_dailyQuestion.questionText), findsOneWidget);
    expect(find.text('답변 남기기'), findsOneWidget);
  });

  testWidgets('today story summary loading 상태를 보여준다', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      storyLoopRepository: _PendingStoryLoopReadRepository(),
      settle: false,
    );

    expect(find.text('오늘의 스토리'), findsOneWidget);
    expect(find.text('오늘 스토리를 불러오고 있어요.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('today story summary error 상태를 보여준다', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      storyLoopRepository: _ThrowingStoryLoopReadRepository(),
    );

    expect(find.text('오늘 스토리를 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('커플 정보가 없으면 상태 메시지를 보여준다', (tester) async {
    await _pumpHome(tester, couple: null, today: _today);

    expect(find.text('커플 정보를 찾을 수 없어요.'), findsOneWidget);
    expect(find.text('오늘 스토리를 아직 확인할 수 없어요.'), findsOneWidget);
  });

  testWidgets('처음 만난 날이 없으면 시작일 안내를 보여준다', (tester) async {
    await _pumpHome(tester, couple: _activeCoupleWithoutDate, today: _today);

    expect(find.text('처음 만난 날을 먼저 입력해 주세요.'), findsOneWidget);
    expect(find.text('오늘 스토리를 아직 확인할 수 없어요.'), findsOneWidget);
  });

  testWidgets('내 카드만 있으면 상대 대기 상태를 보여준다', (tester) async {
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

    expect(find.text('내 스토리 카드가 올라갔어요.'), findsOneWidget);
    expect(find.text('상대 카드가 오면 오늘 질문이 생성돼요.'), findsOneWidget);
    expect(find.text('\uce74\ub4dc\u0020\uc218\uc815'), findsOneWidget);
    expect(find.text('09:00'), findsNothing);
  });

  testWidgets('상대 카드만 있으면 내 작성 대기 상태를 보여준다', (tester) async {
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

    expect(find.text('상대가 스토리 카드를 올렸어요.'), findsOneWidget);
    expect(find.text('내 카드를 올리면 오늘 질문이 생성돼요.'), findsOneWidget);
    expect(find.text('\uce74\ub4dc\u0020\uc791\uc131'), findsOneWidget);
  });

  testWidgets('두 카드가 있고 질문이 없으면 질문 생성 중 상태를 보여준다', (tester) async {
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
            authorUserId: _profile.id,
            submittedAt: DateTime.parse('2026-05-31T09:00:00Z'),
          ),
          samplePreviewCard(
            id: 'card-2',
            authorUserId: 'partner-id',
            previewPath: 'https://example.com/card-2.png',
            submittedAt: DateTime.parse('2026-05-31T09:10:00Z'),
          ),
        ],
      ),
    );

    expect(find.text('질문 생성 중'), findsOneWidget);
    expect(find.text('두 카드가 모두 도착했어요. 오늘 질문을 준비하고 있어요.'), findsOneWidget);
  });

  testWidgets('상대가 먼저 답변을 남기면 안내 문구를 보여준다', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      todaySummary: sampleTodaySummary(
        coupleDate: _today,
        question: StoryLoopQuestionSummary(
          question: _dailyQuestion,
          myAnswerExists: false,
          partnerAnswerExists: true,
          answerCount: 1,
        ),
      ),
    );

    expect(find.text('상대방은 답변을 남겼어요.'), findsOneWidget);
  });

  testWidgets('내가 답변을 남기면 상대 답변 대기 문구를 보여준다', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      todaySummary: sampleTodaySummary(
        coupleDate: _today,
        question: StoryLoopQuestionSummary(
          question: _dailyQuestion,
          myAnswerExists: true,
          partnerAnswerExists: false,
          answerCount: 1,
        ),
      ),
    );

    expect(find.text('상대방의 답변을 기다리고 있어요.'), findsOneWidget);
    expect(find.text('오늘 질문 보기'), findsOneWidget);
  });

  testWidgets('양쪽 답변이 모두 있으면 AI placeholder 문구를 보여준다', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      todaySummary: sampleTodaySummary(
        coupleDate: _today,
        loopStatus: StoryLoopStatus.completed,
        question: StoryLoopQuestionSummary(
          question: _dailyQuestion,
          myAnswerExists: true,
          partnerAnswerExists: true,
          answerCount: 2,
        ),
      ),
    );

    expect(find.text('AI 한 줄 평이 여기에 표시될 예정이에요.'), findsOneWidget);
  });
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
  displayName: '연인',
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
