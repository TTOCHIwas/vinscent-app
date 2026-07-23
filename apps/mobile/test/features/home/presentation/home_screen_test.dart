import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/ai/application/ai_learning_controller.dart';
import 'package:vinscent/features/ai/application/ai_question_feedback_provider.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/characters/presentation/widgets/couple_character_avatar.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/home/application/home_guide.dart';
import 'package:vinscent/features/home/data/home_feedback_impression_store.dart';
import 'package:vinscent/features/home/presentation/home_screen.dart';
import 'package:vinscent/features/home/presentation/widgets/home_guide_rotator.dart';
import 'package:vinscent/features/home/presentation/widgets/transient_home_feedback_presenter.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/recordings/application/couple_recording_overview_controller.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
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
import '../../../support/text_finders.dart';

const _storyAddButtonKey = Key('home-story-add-button');
const _storyAddForegroundKey = Key('home-story-add-foreground');
const _questionBubbleKey = Key('home-question-speech-bubble');
const _questionActionKey = Key('home-question-action');
const _questionForegroundKey = Key('home-question-foreground');
const _storyLineKey = Key('home-story-line');
const _storyClotheslineKey = Key('home-story-clothesline');
const _storyDetailOverlayKey = Key('story-card-detail-overlay');
const _storyDetailCloseButtonKey = Key('story-card-detail-close');
const _aiFeedbackText = 'AI feedback for both answers';
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
const _characterSetupPrompt = '우리 둘 만의 캐릭터를 그려주세요!';
const _aiProcessingPrompt = '둘이 남긴 답을 읽고 있어. 잠깐만 기다려줘!';
const _questionPreparingPrompt = '둘에게 어울릴 질문을 고르고 있어!';

Key _storyThumbnailKey(String cardId) => Key('home-story-card-$cardId');
Key _storyDetailCardKey(String cardId) => Key('story-card-detail-$cardId');

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
      expect(find.byKey(_storyLineKey), findsOneWidget);
      expect(find.byKey(_storyClotheslineKey), findsOneWidget);
      expect(find.byKey(_storyAddButtonKey), findsOneWidget);
      expect(find.byKey(_storyAddForegroundKey), findsOneWidget);
      expect(
        tester.getSize(find.byKey(_storyAddButtonKey)),
        const Size.square(56),
      );
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(_storyAddButtonKey)).dx,
        lessThan(tester.getCenter(find.byType(HomeScreen)).dx),
      );
      expect(find.text(_storyLabel), findsNothing);
      expect(find.text(_storyEmptyMessage), findsNothing);
      expect(find.text(_storyCreateAction), findsNothing);
      expect(
        findTextIgnoringWordJoiners(HomeGuide.card.message),
        findsOneWidget,
      );
      expect(find.byType(CoupleCharacterAvatar), findsOneWidget);
      expect(
        tester.getSize(find.byKey(CharacterRecordingControl.controlKey)),
        const Size.square(250),
      );
    },
  );

  testWidgets('카드 안내 말풍선을 누르면 카드 작성 화면을 연다', (tester) async {
    final router = await _pumpRoutedHome(
      tester,
      todaySummary: _emptyTodaySummary(coupleDate: _today),
      recordingOverview: _emptyRecordingOverview,
    );

    await tester.tap(findTextIgnoringWordJoiners(HomeGuide.card.message));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home/story');
  });

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

  testWidgets('기본 캐릭터를 누르면 캐릭터 설정 화면을 연다', (tester) async {
    final router = await _pumpRoutedHome(
      tester,
      couple: activeCouple(
        currentDate: _today,
        characterSetupStatus: CoupleCharacterSetupStatus.defaultCharacter,
      ),
      todaySummary: _emptyTodaySummary(coupleDate: _today),
      recordingOverview: _emptyRecordingOverview,
    );

    expect(findTextIgnoringWordJoiners(_characterSetupPrompt), findsOneWidget);
    final characterControl = tester.widget<CharacterRecordingControl>(
      find.byType(CharacterRecordingControl),
    );
    expect(characterControl.onPrimaryTap, isNotNull);
    expect(characterControl.isLoading, isFalse);
    expect(characterControl.isPlaybackBusy, isFalse);
    expect(find.bySemanticsLabel('캐릭터 설정'), findsOneWidget);

    await tester.tap(find.byKey(CharacterRecordingControl.controlKey));
    await tester.pumpAndSettle();

    expect(find.text('character settings route'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('내 카드를 작성했고 녹음이 없으면 첫 녹음을 안내한다', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      todaySummary: _todaySummaryWithMyCard(),
      recordingOverview: _emptyRecordingOverview,
    );

    expect(
      tester.widget<HomeGuideRotator>(find.byType(HomeGuideRotator)).guides,
      contains(HomeGuide.recording),
    );
    expect(
      findTextIgnoringWordJoiners(HomeGuide.recording.message),
      findsOneWidget,
    );
    expect(find.byKey(_questionBubbleKey), findsOneWidget);
  });

  testWidgets('현재 녹음이 있으면 보관함 사용을 안내하고 이동한다', (tester) async {
    final router = await _pumpRoutedHome(
      tester,
      todaySummary: _todaySummaryWithMyCard(),
      recordingOverview: _recordingOverviewWithCurrentAudio(),
    );

    expect(
      findTextIgnoringWordJoiners(HomeGuide.recording.message),
      findsNothing,
    );
    expect(
      findTextIgnoringWordJoiners(HomeGuide.recordingLibrary.message),
      findsOneWidget,
    );

    await tester.tap(
      findTextIgnoringWordJoiners(HomeGuide.recordingLibrary.message),
    );
    await tester.pumpAndSettle();

    expect(find.text('recording library route'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('AI 동의 안내를 누르면 AI 탭으로 이동한다', (tester) async {
    final router = await _pumpRoutedHome(
      tester,
      todaySummary: _todaySummaryWithMyCard(),
      recordingOverview: _recordingOverviewWithSavedSlot(),
      aiDashboard: _aiDashboard(myConsent: AiConsentStatus.revoked),
    );

    expect(
      findTextIgnoringWordJoiners(HomeGuide.aiConsent.message),
      findsOneWidget,
    );

    await tester.tap(findTextIgnoringWordJoiners(HomeGuide.aiConsent.message));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/ai');
  });

  testWidgets(
    '\uc9c8\ubb38\uc774 \uc0dd\uc131\ub418\uba74 \uc9c8\ubb38 \uc704\uc5d0 \ud655\ub300\ub41c \uce74\ub4dc \ubbf8\ub9ac\ubcf4\uae30\ub97c \ubcf4\uc5ec\uc900\ub2e4',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 592));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpHome(
        tester,
        couple: _activeCouple,
        today: _today,
        recordingOverview: _emptyRecordingOverview,
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

      expect(
        findTextIgnoringWordJoiners(_dailyQuestion.questionText),
        findsOneWidget,
      );
      expect(
        findTextIgnoringWordJoiners(HomeGuide.recording.message),
        findsNothing,
      );
      final questionBubble = find.byKey(_questionBubbleKey);
      final questionAction = find.byKey(_questionActionKey);
      final characterControl = find.byKey(CharacterRecordingControl.controlKey);
      expect(questionBubble, findsOneWidget);
      expect(questionAction, findsOneWidget);
      expect(find.byKey(_questionForegroundKey), findsOneWidget);
      expect(
        find.descendant(of: questionBubble, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
      expect(tester.getSize(questionAction), tester.getSize(questionBubble));
      expect(
        tester.getTopLeft(characterControl).dy -
            tester.getBottomLeft(questionBubble).dy,
        closeTo(8, 0.1),
      );
      final questionText = tester.widget<Text>(
        findTextIgnoringWordJoiners(_dailyQuestion.questionText),
      );
      expect(questionText.style?.fontSize, 16);
      final myCard = find.byKey(_storyThumbnailKey('card-1'));
      final partnerCard = find.byKey(_storyThumbnailKey('card-2'));
      expect(find.byKey(_storyLineKey), findsOneWidget);
      expect(find.byKey(_storyClotheslineKey), findsOneWidget);
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
        lessThan(
          tester
              .getTopLeft(
                findTextIgnoringWordJoiners(_dailyQuestion.questionText),
              )
              .dy,
        ),
      );
      final cardToBubbleGap =
          tester.getTopLeft(questionBubble).dy -
          tester.getBottomLeft(myCard).dy;
      final bubbleToCharacterGap =
          tester.getTopLeft(characterControl).dy -
          tester.getBottomLeft(questionBubble).dy;
      expect(bubbleToCharacterGap, lessThan(cardToBubbleGap));
      expect(find.byKey(_storyAddButtonKey), findsNothing);
      expect(find.text(_storyLabel), findsNothing);
      expect(find.text(_storyAnswerAction), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '\uc9c8\ubb38 \uc0dd\uc131 \uc804 \ub0b4 \uce74\ub4dc\ub294 \uc218\uc815 \ud654\uba74\uc744 \uc5f0\ub2e4',
    (tester) async {
      final router = await _pumpRoutedHome(
        tester,
        todaySummary: _summaryWithoutQuestion(
          coupleDate: _today,
          loopStatus: StoryLoopStatus.waitingPartnerCard,
          cardCount: 1,
          storyEditLocked: false,
          canEditStory: true,
          canAnswerQuestion: false,
          cards: [samplePreviewCard(authorUserId: _profile.id)],
        ),
      );

      await tester.tap(find.byKey(_storyThumbnailKey('card-1')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/home/story');
      expect(find.text('story editor route'), findsOneWidget);
    },
  );

  testWidgets(
    '\uc9c8\ubb38 \uc0dd\uc131 \uc804 \uc0c1\ub300 \uce74\ub4dc\ub294 \uc0c1\uc138 \uc624\ubc84\ub808\uc774\ub97c \uc5f0\ub2e4',
    (tester) async {
      final router = await _pumpRoutedHome(
        tester,
        todaySummary: _summaryWithoutQuestion(
          coupleDate: _today,
          loopStatus: StoryLoopStatus.waitingPartnerCard,
          cardCount: 1,
          storyEditLocked: false,
          canEditStory: true,
          canAnswerQuestion: false,
          cards: [samplePreviewCard(authorUserId: 'partner-id')],
        ),
      );

      await tester.tap(find.byKey(_storyThumbnailKey('card-1')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.byKey(_storyDetailOverlayKey), findsOneWidget);
      expect(find.byKey(_storyDetailCardKey('card-1')), findsOneWidget);
    },
  );

  testWidgets(
    '\uc9c8\ubb38 \uc0dd\uc131 \ud6c4 \uce74\ub4dc\uc640 \uc9c8\ubb38\uc758 \uc120\ud0dd \ub3d9\uc791\uc744 \ubd84\ub9ac\ud55c\ub2e4',
    (tester) async {
      final router = await _pumpRoutedHome(
        tester,
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
            myAnswerExists: false,
            partnerAnswerExists: false,
            answerCount: 0,
          ),
        ),
      );

      await tester.tap(find.byKey(_storyThumbnailKey('card-1')));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.byKey(_storyDetailOverlayKey), findsOneWidget);

      await tester.tap(find.byKey(_storyDetailCloseButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(
        findTextIgnoringWordJoiners(_dailyQuestion.questionText),
      );
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/home/question/edit',
      );
      expect(find.text('question edit route'), findsOneWidget);
    },
  );

  testWidgets(
    '\uc591\ucabd \ub2f5\ubcc0\uc774 \uc644\ub8cc\ub418\uba74 \uce74\ub4dc\ub97c \ucd95\uc18c\ud574 \uc904\uc5d0 \uac78\uc5b4 \ubcf4\uc5ec\uc900\ub2e4',
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
            samplePreviewCard(authorUserId: _profile.id),
            samplePreviewCard(
              id: 'card-2',
              authorUserId: 'partner-id',
              previewPath: 'previews/card-2.png',
            ),
          ],
          question: StoryLoopQuestionSummary(
            question: _dailyQuestion,
            myAnswerExists: true,
            partnerAnswerExists: true,
            answerCount: 2,
          ),
        ),
      );

      final myCard = find.byKey(_storyThumbnailKey('card-1'));
      final partnerCard = find.byKey(_storyThumbnailKey('card-2'));
      expect(find.byKey(_storyLineKey), findsOneWidget);
      expect(find.byKey(_storyClotheslineKey), findsOneWidget);
      expect(tester.getSize(myCard).width, closeTo(80, 0.1));
      expect(tester.getSize(partnerCard).width, closeTo(80, 0.1));
      expect(
        tester.getSize(find.byKey(_storyLineKey)).height,
        closeTo(148, 0.1),
      );
      expect(
        tester.getCenter(myCard).dx,
        lessThan(tester.getCenter(partnerCard).dx),
      );
      expect(
        findTextIgnoringWordJoiners(_dailyQuestion.questionText),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows published AI feedback after both answers on home', (
    tester,
  ) async {
    final router = await _pumpRoutedHome(
      tester,
      todaySummary: _completedTodaySummary(),
      aiFeedbacks: {
        _dailyQuestion.dailyQuestionId: AiQuestionFeedback(
          dailyQuestionId: _dailyQuestion.dailyQuestionId,
          feedbackText: _aiFeedbackText,
          publishedAt: DateTime.utc(2026, 5, 31, 12),
        ),
      },
    );

    expect(
      findTextIgnoringWordJoiners(_dailyQuestion.questionText),
      findsNothing,
    );
    expect(find.text(_aiFeedbackText), findsOneWidget);
    expect(find.byKey(_questionBubbleKey), findsOneWidget);

    await tester.tap(find.text(_aiFeedbackText));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home/question');
  });

  testWidgets('briefly announces that completed answers are being read', (
    tester,
  ) async {
    final impressionStore = _FakeHomeFeedbackImpressionStore();
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      todaySummary: _completedTodaySummary(),
      processingAiFeedbackIds: {_dailyQuestion.dailyQuestionId},
      feedbackImpressionStore: impressionStore,
      settle: false,
    );
    await tester.pump();

    expect(findTextIgnoringWordJoiners(_aiProcessingPrompt), findsOneWidget);
    expect(
      impressionStore.lastShownByUser[_profile.id],
      '${_dailyQuestion.dailyQuestionId}:processing',
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(TransientHomeFeedbackPresenter.fadeDuration);

    expect(findTextIgnoringWordJoiners(_aiProcessingPrompt), findsNothing);
  });

  testWidgets('removes published feedback after its temporary display', (
    tester,
  ) async {
    final impressionStore = _FakeHomeFeedbackImpressionStore();
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      todaySummary: _completedTodaySummary(),
      feedbackImpressionStore: impressionStore,
      aiFeedbacks: {
        _dailyQuestion.dailyQuestionId: AiQuestionFeedback(
          dailyQuestionId: _dailyQuestion.dailyQuestionId,
          feedbackText: _aiFeedbackText,
          publishedAt: DateTime.utc(2026, 5, 31, 12),
        ),
      },
    );

    expect(find.text(_aiFeedbackText), findsOneWidget);
    expect(
      impressionStore.lastShownByUser[_profile.id],
      _dailyQuestion.dailyQuestionId,
    );

    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.text(_aiFeedbackText), findsNothing);
    expect(find.byKey(_questionBubbleKey), findsNothing);
  });

  testWidgets('does not repeat feedback already shown to the user', (
    tester,
  ) async {
    final impressionStore = _FakeHomeFeedbackImpressionStore(
      lastShownByUser: {_profile.id: _dailyQuestion.dailyQuestionId},
    );

    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      todaySummary: _completedTodaySummary(),
      feedbackImpressionStore: impressionStore,
      aiFeedbacks: {
        _dailyQuestion.dailyQuestionId: AiQuestionFeedback(
          dailyQuestionId: _dailyQuestion.dailyQuestionId,
          feedbackText: _aiFeedbackText,
          publishedAt: DateTime.utc(2026, 5, 31, 12),
        ),
      },
    );

    expect(find.text(_aiFeedbackText), findsNothing);
    expect(find.byKey(_questionBubbleKey), findsNothing);
  });

  testWidgets('does not show AI feedback before both answers exist', (
    tester,
  ) async {
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
          myAnswerExists: true,
          partnerAnswerExists: false,
          answerCount: 1,
        ),
      ),
      aiFeedbacks: {
        _dailyQuestion.dailyQuestionId: AiQuestionFeedback(
          dailyQuestionId: _dailyQuestion.dailyQuestionId,
          feedbackText: _aiFeedbackText,
          publishedAt: DateTime.utc(2026, 5, 31, 12),
        ),
      },
    );

    expect(find.text(_aiFeedbackText), findsNothing);
  });

  testWidgets(
    '\ube48 \uc0c1\ud0dc\uc640 \ub2f5\ubcc0 \uc804\ud6c4\uc5d0 \uac19\uc740 \uc704\uce58\uc758 \uc904\uc744 \uc0ac\uc6a9\ud55c\ub2e4',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 592));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<double> lineTopFor(TodayStoryLoopSummary summary) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await _pumpHome(
          tester,
          couple: _activeCouple,
          today: _today,
          todaySummary: summary,
        );
        return tester.getTopLeft(find.byKey(_storyClotheslineKey)).dy;
      }

      final emptyLineTop = await lineTopFor(
        _emptyTodaySummary(coupleDate: _today),
      );
      final unansweredLineTop = await lineTopFor(
        sampleTodaySummary(
          coupleDate: _today,
          question: StoryLoopQuestionSummary(
            question: _dailyQuestion,
            myAnswerExists: false,
            partnerAnswerExists: false,
            answerCount: 0,
          ),
        ),
      );
      final completedLineTop = await lineTopFor(
        sampleTodaySummary(
          coupleDate: _today,
          question: StoryLoopQuestionSummary(
            question: _dailyQuestion,
            myAnswerExists: true,
            partnerAnswerExists: true,
            answerCount: 2,
          ),
        ),
      );

      expect(unansweredLineTop, closeTo(emptyLineTop, 0.1));
      expect(completedLineTop, closeTo(emptyLineTop, 0.1));
    },
  );

  testWidgets(
    '\uce74\ub4dc \uc0c1\uc138\ub294 \uc911\uc559\uc5d0 \ud45c\uc2dc\ub418\uba70 \uce74\ub4dc \uc678\ubd80\uc640 \ub2eb\uae30 \ubc84\ud2bc\uc73c\ub85c \ub2eb\ud78c\ub2e4',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = await _pumpRoutedHome(
        tester,
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

      final thumbnail = find.byKey(_storyThumbnailKey('card-1'));
      await tester.tap(thumbnail);
      await tester.pumpAndSettle();

      final detailCard = find.byKey(_storyDetailCardKey('card-1'));
      expect(find.byKey(_storyDetailOverlayKey), findsOneWidget);
      expect(tester.getSize(detailCard).width, greaterThanOrEqualTo(320));
      expect(tester.getCenter(detailCard).dx, closeTo(180, 0.5));

      await tester.tap(detailCard);
      await tester.pumpAndSettle();
      expect(find.byKey(_storyDetailOverlayKey), findsOneWidget);

      await tester.tapAt(const Offset(4, 320));
      await tester.pumpAndSettle();
      expect(find.byKey(_storyDetailOverlayKey), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/home');

      await tester.tap(thumbnail);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_storyDetailCloseButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(_storyDetailOverlayKey), findsNothing);
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
      expect(find.byKey(_storyLineKey), findsOneWidget);
      expect(find.byKey(_storyClotheslineKey), findsOneWidget);
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
      expect(find.byKey(_storyLineKey), findsOneWidget);
      expect(find.byKey(_storyClotheslineKey), findsOneWidget);
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
      expect(find.byKey(_storyLineKey), findsOneWidget);
      expect(find.byKey(_storyClotheslineKey), findsOneWidget);
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

  testWidgets('AI 질문을 준비하는 동안 탭할 수 없는 안내를 보여준다', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      todaySummary: _summaryWithoutQuestion(
        coupleDate: _today,
        loopStatus: StoryLoopStatus.questionPreparing,
        cardCount: 2,
        storyEditLocked: true,
        canEditStory: false,
        canAnswerQuestion: false,
        cards: [
          samplePreviewCard(authorUserId: _profile.id),
          samplePreviewCard(
            id: 'card-2',
            authorUserId: 'partner-id',
            previewPath: 'previews/card-2.png',
          ),
        ],
      ),
    );

    expect(
      findTextIgnoringWordJoiners(_questionPreparingPrompt),
      findsOneWidget,
    );
    expect(
      tester.widget<InkWell>(find.byKey(_questionActionKey)).onTap,
      isNull,
    );
    expect(find.byType(HomeGuideRotator), findsOneWidget);
    expect(
      tester.widget<HomeGuideRotator>(find.byType(HomeGuideRotator)).guides,
      isEmpty,
    );
  });

  testWidgets('집중 질문 중 완성된 카드 날짜에는 질문 안내를 만들지 않는다', (tester) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: _today,
      todaySummary: _summaryWithoutQuestion(
        coupleDate: _today,
        loopStatus: StoryLoopStatus.cardOnlyCompleted,
        cardCount: 2,
        storyEditLocked: true,
        canEditStory: false,
        canAnswerQuestion: false,
        cards: [
          samplePreviewCard(authorUserId: _profile.id),
          samplePreviewCard(
            id: 'card-2',
            authorUserId: 'partner-id',
            previewPath: 'previews/card-2.png',
          ),
        ],
      ),
    );

    expect(findTextIgnoringWordJoiners(_questionPreparingPrompt), findsNothing);
    expect(find.byKey(_questionActionKey), findsNothing);
    expect(find.byKey(_storyAddButtonKey), findsNothing);
  });

  for (final scenario
      in <
        ({
          String name,
          bool myAnswerExists,
          bool partnerAnswerExists,
          bool showsQuestion,
          String removedMessage,
        })
      >[
        (
          name: '\uc0c1\ub300\ub9cc \ub2f5\ubcc0\ud55c \uc0c1\ud0dc',
          myAnswerExists: false,
          partnerAnswerExists: true,
          showsQuestion: true,
          removedMessage: _storyPartnerAnswered,
        ),
        (
          name: '\ub098\ub9cc \ub2f5\ubcc0\ud55c \uc0c1\ud0dc',
          myAnswerExists: true,
          partnerAnswerExists: false,
          showsQuestion: false,
          removedMessage: _storyWaitingAnswer,
        ),
        (
          name: '\ub458 \ub2e4 \ub2f5\ubcc0\ud55c \uc0c1\ud0dc',
          myAnswerExists: true,
          partnerAnswerExists: true,
          showsQuestion: false,
          removedMessage: _storyAiPlaceholder,
        ),
      ]) {
    testWidgets(
      '${scenario.name}\uc758 \ub0b4 \ub2f5\ubcc0 \uc0c1\ud0dc\uc5d0 \ub9de\ucdb0 \uc9c8\ubb38 \ubb38\uad6c\ub97c \ub178\ucd9c\ud55c\ub2e4',
      (tester) async {
        await _pumpHome(
          tester,
          couple: _activeCouple,
          today: _today,
          recordingOverview: _emptyRecordingOverview,
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

        expect(
          findTextIgnoringWordJoiners(_dailyQuestion.questionText),
          scenario.showsQuestion ? findsOneWidget : findsNothing,
        );
        expect(find.text(scenario.removedMessage), findsNothing);
        expect(find.text(_storyQuestionAction), findsNothing);
        expect(find.text(_storyAnswerAction), findsNothing);
        expect(
          findTextIgnoringWordJoiners(HomeGuide.recording.message),
          findsNothing,
        );
      },
    );
  }
}

Future<GoRouter> _pumpRoutedHome(
  WidgetTester tester, {
  required TodayStoryLoopSummary todaySummary,
  Couple? couple,
  CoupleRecordingOverview? recordingOverview,
  Map<String, AiQuestionFeedback> aiFeedbacks = const {},
  Set<String> processingAiFeedbackIds = const {},
  HomeFeedbackImpressionStore? feedbackImpressionStore,
  AiLearningDashboard? aiDashboard,
}) async {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: HomeScreen()),
      ),
      GoRoute(
        path: '/home/story',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('story editor route'))),
      ),
      GoRoute(
        path: '/home/question',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('question detail route'))),
      ),
      GoRoute(
        path: '/home/question/edit',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('question edit route'))),
      ),
      GoRoute(
        path: '/settings/character',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('character settings route')),
        ),
      ),
      GoRoute(
        path: '/home/recordings',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('recording library route')),
        ),
      ),
      GoRoute(
        path: '/ai',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('AI route'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => couple ?? _activeCouple,
        ),
        todayControllerProvider.overrideWithBuild((ref, notifier) => _today),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        aiLearningControllerProvider.overrideWithBuild(
          (ref, notifier) async => aiDashboard ?? _aiDashboard(),
        ),
        storyLoopReadRepositoryProvider.overrideWithValue(
          FakeStoryLoopReadRepository(todaySummary: todaySummary),
        ),
        aiQuestionFeedbackProvider.overrideWith(
          (ref, dailyQuestionId) => Stream.value(
            _aiFeedbackState(
              dailyQuestionId,
              aiFeedbacks: aiFeedbacks,
              processingIds: processingAiFeedbackIds,
            ),
          ),
        ),
        homeFeedbackImpressionStoreProvider.overrideWithValue(
          feedbackImpressionStore ?? _FakeHomeFeedbackImpressionStore(),
        ),
        if (recordingOverview != null)
          coupleRecordingOverviewControllerProvider.overrideWithBuild(
            (ref, notifier) => recordingOverview,
          ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required Couple? couple,
  required DateTime today,
  TodayStoryLoopSummary? todaySummary,
  StoryLoopReadRepository? storyLoopRepository,
  CoupleRecordingOverview? recordingOverview,
  Map<String, AiQuestionFeedback> aiFeedbacks = const {},
  Set<String> processingAiFeedbackIds = const {},
  HomeFeedbackImpressionStore? feedbackImpressionStore,
  AiLearningDashboard? aiDashboard,
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
        aiLearningControllerProvider.overrideWithBuild(
          (ref, notifier) async => aiDashboard ?? _aiDashboard(),
        ),
        storyLoopReadRepositoryProvider.overrideWithValue(
          storyLoopRepository ??
              FakeStoryLoopReadRepository(todaySummary: todaySummary),
        ),
        aiQuestionFeedbackProvider.overrideWith(
          (ref, dailyQuestionId) => Stream.value(
            _aiFeedbackState(
              dailyQuestionId,
              aiFeedbacks: aiFeedbacks,
              processingIds: processingAiFeedbackIds,
            ),
          ),
        ),
        homeFeedbackImpressionStoreProvider.overrideWithValue(
          feedbackImpressionStore ?? _FakeHomeFeedbackImpressionStore(),
        ),
        if (recordingOverview != null)
          coupleRecordingOverviewControllerProvider.overrideWithBuild(
            (ref, notifier) => recordingOverview,
          ),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var pumpCount = 0; pumpCount < 5; pumpCount++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }
}

AiQuestionFeedbackState _aiFeedbackState(
  String dailyQuestionId, {
  required Map<String, AiQuestionFeedback> aiFeedbacks,
  required Set<String> processingIds,
}) {
  final feedback = aiFeedbacks[dailyQuestionId];
  if (feedback != null) {
    return AiQuestionFeedbackPublished(feedback);
  }

  if (processingIds.contains(dailyQuestionId)) {
    return const AiQuestionFeedbackProcessing();
  }

  return const AiQuestionFeedbackDisabled();
}

class _FakeHomeFeedbackImpressionStore implements HomeFeedbackImpressionStore {
  _FakeHomeFeedbackImpressionStore({Map<String, String>? lastShownByUser})
    : lastShownByUser = {...?lastShownByUser};

  final Map<String, String> lastShownByUser;

  @override
  Future<bool> hasShown({
    required String userId,
    required String dailyQuestionId,
  }) async {
    return lastShownByUser[userId] == dailyQuestionId;
  }

  @override
  Future<void> markShown({
    required String userId,
    required String dailyQuestionId,
  }) async {
    lastShownByUser[userId] = dailyQuestionId;
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

TodayStoryLoopSummary _completedTodaySummary() {
  return sampleTodaySummary(
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
      myAnswerExists: true,
      partnerAnswerExists: true,
      answerCount: 2,
    ),
  );
}

TodayStoryLoopSummary _todaySummaryWithMyCard() {
  return _summaryWithoutQuestion(
    coupleDate: _today,
    loopStatus: StoryLoopStatus.waitingPartnerCard,
    cardCount: 1,
    storyEditLocked: false,
    canEditStory: true,
    canAnswerQuestion: false,
    cards: [samplePreviewCard(authorUserId: _profile.id)],
  );
}

AiLearningDashboard _aiDashboard({
  AiConsentStatus myConsent = AiConsentStatus.granted,
  AiConsentStatus partnerConsent = AiConsentStatus.granted,
}) {
  return AiLearningDashboard(
    progress: AiLearningProgress(
      curriculumVersion: 1,
      completedCount: 0,
      totalCount: 24,
      stage: AiLearningStage.collecting,
      domainProgress: const {},
      myConsent: myConsent,
      partnerConsent: partnerConsent,
      isEnabled:
          myConsent == AiConsentStatus.granted &&
          partnerConsent == AiConsentStatus.granted,
      foundationComplete: false,
      memoryProcessingComplete: false,
      personalizationStatus: AiPersonalizationStatus.collecting,
      personalizationEnabled: false,
      myPendingReviewCount: 0,
      partnerPendingReviewCount: 0,
    ),
    memories: const [],
  );
}

const _emptyRecordingOverview = CoupleRecordingOverview(
  slotLimit: 5,
  currentRecording: null,
  savedSlots: [],
);

CoupleRecordingOverview _recordingOverviewWithCurrentAudio() {
  final recordedAt = DateTime.utc(2026, 5, 31, 9);
  return CoupleRecordingOverview(
    slotLimit: 5,
    currentRecording: CurrentCoupleRecording(
      recordingId: 'recording-id',
      senderUserId: _profile.id,
      durationMs: 1200,
      recordedAt: recordedAt,
      revision: 1,
      updatedAt: recordedAt,
      audioUrl: 'https://example.com/current.m4a',
    ),
    savedSlots: const [],
  );
}

CoupleRecordingOverview _recordingOverviewWithSavedSlot() {
  final overview = _recordingOverviewWithCurrentAudio();
  final recordedAt = DateTime.utc(2026, 5, 31, 9);
  return CoupleRecordingOverview(
    slotLimit: overview.slotLimit,
    currentRecording: overview.currentRecording,
    savedSlots: [
      CoupleRecordingSlot(
        slotId: 'slot-id',
        slotIndex: 1,
        title: '첫 녹음',
        recordingId: 'saved-recording-id',
        senderUserId: _profile.id,
        durationMs: 1200,
        recordedAt: recordedAt,
        slotRevision: 1,
        createdByUserId: _profile.id,
        updatedByUserId: _profile.id,
        createdAt: recordedAt,
        updatedAt: recordedAt,
        audioUrl: 'https://example.com/saved.m4a',
      ),
    ],
  );
}

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
