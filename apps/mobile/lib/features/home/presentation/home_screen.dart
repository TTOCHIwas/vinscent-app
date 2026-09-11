import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/presentation/widgets/character_speech_message.dart';
import '../../../core/questions/daily_question.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../app/application/app_foreground_session_controller.dart';
import '../../ai/application/ai_learning_controller.dart';
import '../../ai/application/ai_proactive_suggestion_controller.dart';
import '../../ai/application/ai_question_feedback_provider.dart';
import '../../ai/data/ai_learning_dashboard.dart';
import '../../ai/presentation/widgets/ai_generated_content_indicator.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../../profile/application/profile_controller.dart';
import '../../questions/presentation/question_route_context.dart';
import '../../questions/application/daily_question_detail_provider.dart';
import '../../questions/data/daily_question_detail_snapshot.dart';
import '../../recordings/application/couple_recording_overview_controller.dart';
import '../../recordings/presentation/widgets/home_character_recording_control.dart';
import '../../recordings/presentation/widgets/home_recording_artwork_layer.dart';
import '../../safety/data/safety_report.dart';
import '../../safety/presentation/safety_report_sheet.dart';
import '../../story_loops/application/today_story_card_stacks_provider.dart';
import '../../story_loops/data/story_card_stack_preview.dart';
import '../../story_loops/data/story_card_scene.dart';
import '../../story_loops/data/today_story_card_stacks.dart';
import '../../story_loops/presentation/story_card_editor_route.dart';
import '../../story_loops/presentation/widgets/story_card_stack_overlay.dart';
import '../../story_loops/presentation/widgets/story_card_preview_surface.dart';
import '../application/home_guide.dart';
import 'widgets/home_foreground_portal.dart';
import 'widgets/home_hanging_story_cards.dart';
import 'widgets/home_guide_rotator.dart';
import 'widgets/persistent_home_proactive_suggestion_presenter.dart';
import 'widgets/transient_home_feedback_presenter.dart';

const _homeStatusLoadError =
    '\ucee4\ud50c \uc815\ubcf4\ub97c \ubd88\ub7ec\uc624\uc9c0 \ubabb\ud588\uc5b4\uc694.';
const _homeStatusMissingCouple =
    '\ucee4\ud50c \uc815\ubcf4\ub97c \ucc3e\uc744 \uc218 \uc5c6\uc5b4\uc694.';
const _homeStatusArchivedNoDate =
    '\uae30\ub85d \ubcf4\uad00 \uc911\uc774\uc5d0\uc694';
const _homeStatusMissingStartDate =
    '\ucc98\uc74c \ub9cc\ub09c \ub0a0\uc744 \uba3c\uc800 \uc785\ub825\ud574 \uc8fc\uc138\uc694.';
const _homeStatusArchivedHeadline = '\uae30\ub85d \ubcf4\uad00 \uc911';
const _homeStoryCreateTooltip = '\uce74\ub4dc \uc791\uc131';
const _homeStoryCardSemantics = '\uc2a4\ud1a0\ub9ac \uce74\ub4dc';
const _homeStoryRetryTooltip = '\ub2e4\uc2dc \uc2dc\ub3c4';
const _homeFeedbackProcessingPrompt = '둘이 남긴 답을 읽고 있어. 잠깐만 기다려줘!';
const _homeFeedbackProcessingDuration = Duration(seconds: 3);
const _homeCharacterSetupPrompt = '우리 둘 만의 캐릭터를 그려주세요!';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomNavigationClearance = MediaQuery.paddingOf(context).bottom;
    final currentUserId = ref.watch(
      profileControllerProvider.select(
        (state) =>
            state.maybeWhen(data: (profile) => profile?.id, orElse: () => null),
      ),
    );
    final cardStacks = ref.watch(
      todayStoryCardStacksProvider.select((state) => state.asData?.value),
    );
    final canCreateCard =
        currentUserId != null &&
        cardStacks?.accessMode != CoupleAccessMode.archivedReadOnly &&
        cardStacks?.canCreateCard == true;

    return _HomeCardCreationSwipeRegion(
      onSwipeRight: canCreateCard
          ? () => context.go(storyCardEditorSwipeRightLocation)
          : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          12 + bottomNavigationClearance,
        ),
        child: const Column(
          children: [
            _CoupleStatus(),
            Expanded(child: _HomeStageLayout()),
          ],
        ),
      ),
    );
  }
}

class _HomeCardCreationSwipeRegion extends StatefulWidget {
  const _HomeCardCreationSwipeRegion({
    required this.onSwipeRight,
    required this.child,
  });

  final VoidCallback? onSwipeRight;
  final Widget child;

  @override
  State<_HomeCardCreationSwipeRegion> createState() =>
      _HomeCardCreationSwipeRegionState();
}

class _HomeCardCreationSwipeRegionState
    extends State<_HomeCardCreationSwipeRegion> {
  static const _minimumDragDistance = 72.0;
  static const _minimumFlingDistance = 24.0;
  static const _minimumFlingVelocity = 650.0;

  var _horizontalDragDistance = 0.0;

  void _resetDrag() {
    _horizontalDragDistance = 0;
  }

  void _handleDragEnd(DragEndDetails details) {
    final distance = _horizontalDragDistance;
    final velocity = details.primaryVelocity ?? 0;
    _resetDrag();

    final isDeliberateDrag = distance >= _minimumDragDistance;
    final isRightFling =
        distance >= _minimumFlingDistance && velocity >= _minimumFlingVelocity;
    if (isDeliberateDrag || isRightFling) {
      widget.onSwipeRight?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onSwipeRight != null;
    return GestureDetector(
      key: const Key('home-card-creation-swipe-region'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: isEnabled ? (_) => _resetDrag() : null,
      onHorizontalDragUpdate: isEnabled
          ? (details) {
              _horizontalDragDistance += details.primaryDelta ?? 0;
            }
          : null,
      onHorizontalDragEnd: isEnabled ? _handleDragEnd : null,
      onHorizontalDragCancel: isEnabled ? _resetDrag : null,
      child: widget.child,
    );
  }
}

class _HomeStageLayout extends StatelessWidget {
  const _HomeStageLayout();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final halfHeight = constraints.maxHeight / 2;
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : HomeCharacterRecordingControl.preferredControlSize;
        final controlSize = math.min(
          HomeCharacterRecordingControl.preferredControlSize,
          math.min(availableWidth, halfHeight),
        );
        final characterOffset = (halfHeight - controlSize) / 2;
        final mainStageHeight = halfHeight + characterOffset;
        return Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: mainStageHeight,
                  child: const _HomeMainStage(),
                ),
                const Expanded(child: HomeCharacterRecordingControl()),
              ],
            ),
            const Positioned.fill(child: HomeRecordingArtworkLayer()),
          ],
        );
      },
    );
  }
}

class _CoupleStatus extends ConsumerWidget {
  const _CoupleStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(coupleControllerProvider);
    Widget padded(Widget child) => SizedBox(
      width: double.infinity,
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );

    return couple.when(
      loading: () => padded(
        const Align(
          alignment: Alignment.centerRight,
          child: SizedBox.square(
            dimension: 20,
            child: AppLoadingIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stackTrace) =>
          padded(const _CoupleStatusMessage(_homeStatusLoadError)),
      data: (couple) {
        if (couple == null) {
          return padded(const _CoupleStatusMessage(_homeStatusMissingCouple));
        }

        if (!couple.hasRelationshipStartDate) {
          return padded(
            Text(
              couple.isArchivedReadOnly
                  ? _homeStatusArchivedNoDate
                  : _homeStatusMissingStartDate,
              textAlign: TextAlign.end,
              style: AppTextStyles.homeBody.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          );
        }

        if (couple.isArchivedReadOnly) {
          return padded(
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                _homeStatusArchivedHeadline,
                style: AppTextStyles.homeBody,
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _CoupleStatusMessage extends StatelessWidget {
  const _CoupleStatusMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        message,
        textAlign: TextAlign.end,
        style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}

class _HomeMainStage extends StatelessWidget {
  const _HomeMainStage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: _HomeStoryLoopPreview(),
    );
  }
}

class _HomeStoryLoopPreview extends ConsumerWidget {
  const _HomeStoryLoopPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      profileControllerProvider.select(
        (state) => state.maybeWhen(data: (value) => value, orElse: () => null),
      ),
    );
    final cardsAsync = ref.watch(todayStoryCardStacksProvider);
    final questionAsync = ref.watch(todayDailyQuestionProvider);
    final cards = cardsAsync.asData?.value;
    final question = questionAsync.asData?.value;

    if (cardsAsync.isLoading && questionAsync.isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 24,
          child: AppLoadingIndicator(strokeWidth: 2),
        ),
      );
    }
    if (cardsAsync.hasError && questionAsync.hasError) {
      return Center(
        child: IconButton(
          onPressed: () {
            ref.invalidate(todayStoryCardStacksProvider);
            ref.invalidate(todayDailyQuestionProvider);
          },
          tooltip: _homeStoryRetryTooltip,
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    }
    if (cards == null && question == null) {
      return const SizedBox.shrink();
    }

    return _ResolvedHomeStoryLoopPreview(
      cards: cards,
      question: question,
      currentUserId: profile?.id,
    );
  }
}

class _ResolvedHomeStoryLoopPreview extends ConsumerWidget {
  const _ResolvedHomeStoryLoopPreview({
    required this.cards,
    required this.question,
    required this.currentUserId,
  });

  final TodayStoryCardStacks? cards;
  final DailyQuestionDetailSnapshot? question;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyQuestion = question;
    final presentation = _HomeStoryLoopPresentation.fromSummary(
      cards: cards,
      question: dailyQuestion,
      currentUserId: currentUserId,
    );
    _HomeAiMessage? aiMessage;
    if (dailyQuestion != null &&
        dailyQuestion.answerState.hasMyAnswer &&
        dailyQuestion.answerState.partnerAnswerExists) {
      final feedbackState = ref
          .watch(
            aiQuestionFeedbackProvider(dailyQuestion.question.dailyQuestionId),
          )
          .maybeWhen(data: (state) => state, orElse: () => null);
      aiMessage = _HomeAiMessage.fromState(
        dailyQuestionId: dailyQuestion.question.dailyQuestionId,
        state: feedbackState,
      );
    }
    final characterPromptState = ref.watch(
      coupleControllerProvider.select(
        (state) => state.maybeWhen(
          data: (couple) => (
            needsSetup: couple?.needsCharacterSetupPrompt ?? false,
            canGuideRecording:
                couple?.isActive == true && couple?.hasCustomCharacter == true,
          ),
          orElse: () => (needsSetup: false, canGuideRecording: false),
        ),
      ),
    );
    final recordingGuideState = ref.watch(
      coupleRecordingOverviewControllerProvider.select(
        (state) => state.maybeWhen(
          data: (overview) => (
            isReady: overview != null,
            hasCurrentRecording: overview?.currentRecording != null,
            hasSavedRecordingSlot: overview?.savedSlots.isNotEmpty ?? false,
          ),
          orElse: () => (
            isReady: false,
            hasCurrentRecording: false,
            hasSavedRecordingSlot: false,
          ),
        ),
      ),
    );
    final aiLearningState = ref.watch(
      aiLearningControllerProvider.select(
        (state) => state.maybeWhen(
          data: (dashboard) => (
            needsConsent:
                dashboard.progress.myConsent == AiConsentStatus.revoked,
            personalizationReady: dashboard.progress.personalizationEnabled,
          ),
          orElse: () => (needsConsent: false, personalizationReady: false),
        ),
      ),
    );
    final characterGuideText = characterPromptState.needsSetup
        ? _homeCharacterSetupPrompt
        : null;
    final questionTargetLocation = characterGuideText == null
        ? presentation.questionTargetLocation
        : null;
    final visibleAiMessage = characterGuideText == null ? aiMessage : null;
    final featureGuides =
        characterGuideText == null &&
            visibleAiMessage == null &&
            presentation.questionText == null
        ? selectEligibleHomeGuides(
            canCreateCard:
                presentation.canAddCard && presentation.myStack == null,
            canRecord:
                characterPromptState.canGuideRecording &&
                dailyQuestion == null &&
                recordingGuideState.isReady,
            hasCurrentRecording: recordingGuideState.hasCurrentRecording,
            hasSavedRecordingSlot: recordingGuideState.hasSavedRecordingSlot,
            needsAiConsent: aiLearningState.needsConsent,
          )
        : const <HomeGuide>[];
    final foregroundSessionId = ref.watch(
      appForegroundSessionControllerProvider,
    );
    final proactiveRequest =
        currentUserId != null &&
            aiLearningState.personalizationReady &&
            characterGuideText == null &&
            presentation.questionText == null
        ? AiProactiveSuggestionRequest(
            userId: currentUserId!,
            sessionId: foregroundSessionId,
            contextDate: _dateKey(
              cards?.coupleDate ?? dailyQuestion?.coupleDate ?? DateTime.now(),
            ),
            hasCardToday: presentation.myStack != null,
          )
        : null;
    final proactiveSuggestion = proactiveRequest == null
        ? null
        : ref
              .watch(aiProactiveSuggestionProvider(proactiveRequest))
              .asData
              ?.value;

    return TransientHomeFeedbackPresenter(
      userId: currentUserId,
      dailyQuestionId: visibleAiMessage?.impressionId,
      feedbackText: visibleAiMessage?.text,
      visibleDuration:
          visibleAiMessage?.duration ??
          TransientHomeFeedbackPresenter.displayDuration,
      builder: (visibleFeedbackText, feedbackOpacity) {
        return HomeGuideRotator(
          guides: featureGuides,
          onGuideTap: (guide) => _openHomeGuide(context, guide),
          builder: (guide, guideOpacity, onGuideTap) {
            final canShowProactive =
                guide == null &&
                characterGuideText == null &&
                visibleFeedbackText == null &&
                presentation.questionText == null;
            final proactivePresentationId =
                proactiveSuggestion == null || proactiveRequest == null
                ? null
                : '${proactiveSuggestion.id}:'
                      '${proactiveRequest.contextDate}:'
                      '${proactiveRequest.sessionId}';
            return PersistentHomeProactiveSuggestionPresenter(
              presentationId: proactivePresentationId,
              suggestionText: proactiveSuggestion?.text,
              enabled: canShowProactive,
              beforeShow:
                  proactiveSuggestion == null || proactiveRequest == null
                  ? null
                  : () => ref
                        .read(aiProactiveSuggestionCoordinatorProvider)
                        .claimShown(proactiveRequest, proactiveSuggestion),
              onDismissed:
                  proactiveSuggestion == null || proactiveRequest == null
                  ? null
                  : () => ref
                        .read(aiProactiveSuggestionCoordinatorProvider)
                        .dismiss(proactiveRequest, proactiveSuggestion),
              builder: (visibleSuggestionText, dismissSuggestion) {
                final questionText =
                    characterGuideText ??
                    visibleFeedbackText ??
                    presentation.questionText ??
                    guide?.message ??
                    visibleSuggestionText;
                final bool questionIsAiGenerated;
                final SafetyReportTarget? questionReportTarget;
                if (characterGuideText != null) {
                  questionIsAiGenerated = false;
                  questionReportTarget = null;
                } else if (visibleFeedbackText != null) {
                  questionIsAiGenerated =
                      visibleAiMessage?.isGenerated ?? false;
                  questionReportTarget = visibleAiMessage?.reportTarget;
                } else if (presentation.questionText != null) {
                  questionIsAiGenerated = presentation.questionIsAiGenerated;
                  questionReportTarget = presentation.questionReportTarget;
                } else if (guide != null) {
                  questionIsAiGenerated = false;
                  questionReportTarget = null;
                } else {
                  questionIsAiGenerated = visibleSuggestionText != null;
                  questionReportTarget =
                      visibleSuggestionText == null ||
                          proactiveSuggestion == null
                      ? null
                      : SafetyReportTarget(
                          type: SafetyReportTargetType.aiProactiveSuggestion,
                          id: proactiveSuggestion.id,
                          contentSnapshot: visibleSuggestionText,
                        );
                }
                final questionOpacity = visibleFeedbackText != null
                    ? feedbackOpacity
                    : guide != null
                    ? guideOpacity
                    : 1.0;
                final onQuestionTap = visibleSuggestionText != null
                    ? null
                    : onGuideTap ??
                          (questionTargetLocation == null
                              ? null
                              : () => context.go(questionTargetLocation));
                final questionDismissibleKey =
                    visibleSuggestionText == null ||
                        proactivePresentationId == null
                    ? null
                    : ValueKey('home-proactive-$proactivePresentationId');

                return _HomeStoryLoopContent(
                  myStack: presentation.myStack,
                  partnerStack: presentation.partnerStack,
                  questionText: questionText,
                  questionIsAiGenerated: questionIsAiGenerated,
                  questionReportTarget: questionReportTarget,
                  questionOpacity: questionOpacity,
                  hasBothCardStacks: presentation.hasBothCardStacks,
                  canAddCard: presentation.canAddCard,
                  onAddCard: presentation.canAddCard
                      ? () => context.go(storyCardEditorLocation)
                      : null,
                  onQuestionTap: onQuestionTap,
                  questionDismissibleKey: questionDismissibleKey,
                  onQuestionDismissed: dismissSuggestion,
                  onCardTap: (stack) {
                    showStoryCardStackOverlay(
                      context: context,
                      date: cards!.coupleDate,
                      stack: stack,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _openHomeGuide(BuildContext context, HomeGuide guide) {
    switch (guide.action) {
      case HomeGuideAction.none:
        return;
      case HomeGuideAction.openStoryEditor:
        context.go(storyCardEditorLocation);
      case HomeGuideAction.openRecordingLibrary:
        context.push('/home/recordings');
      case HomeGuideAction.openAi:
        context.go('/ai');
    }
  }
}

class _HomeAiMessage {
  const _HomeAiMessage({
    required this.impressionId,
    required this.text,
    required this.duration,
    required this.isGenerated,
    required this.reportTarget,
  });

  factory _HomeAiMessage.processing(String dailyQuestionId) {
    return _HomeAiMessage(
      impressionId: '$dailyQuestionId:processing',
      text: _homeFeedbackProcessingPrompt,
      duration: _homeFeedbackProcessingDuration,
      isGenerated: false,
      reportTarget: null,
    );
  }

  static _HomeAiMessage? fromState({
    required String dailyQuestionId,
    required AiQuestionFeedbackState? state,
  }) {
    return switch (state) {
      AiQuestionFeedbackProcessing() => _HomeAiMessage.processing(
        dailyQuestionId,
      ),
      AiQuestionFeedbackDelayed() => null,
      AiQuestionFeedbackFailed() => null,
      AiQuestionFeedbackPublished(feedback: final feedback) => _published(
        dailyQuestionId,
        feedback.feedbackText,
      ),
      AiQuestionFeedbackDisabled() || null => null,
    };
  }

  static _HomeAiMessage? _published(
    String dailyQuestionId,
    String feedbackText,
  ) {
    final normalizedText = feedbackText.trim();
    if (normalizedText.isEmpty) {
      return null;
    }

    return _HomeAiMessage(
      impressionId: dailyQuestionId,
      text: normalizedText,
      duration: TransientHomeFeedbackPresenter.displayDuration,
      isGenerated: true,
      reportTarget: SafetyReportTarget(
        type: SafetyReportTargetType.aiFeedback,
        id: dailyQuestionId,
      ),
    );
  }

  final String impressionId;
  final String text;
  final Duration duration;
  final bool isGenerated;
  final SafetyReportTarget? reportTarget;
}

class _HomeStoryLoopContent extends StatelessWidget {
  const _HomeStoryLoopContent({
    required this.myStack,
    required this.partnerStack,
    required this.questionText,
    required this.questionIsAiGenerated,
    required this.questionReportTarget,
    required this.questionOpacity,
    required this.hasBothCardStacks,
    required this.canAddCard,
    required this.onAddCard,
    required this.onQuestionTap,
    required this.questionDismissibleKey,
    required this.onQuestionDismissed,
    required this.onCardTap,
  });

  final StoryCardStackPreview? myStack;
  final StoryCardStackPreview? partnerStack;
  final String? questionText;
  final bool questionIsAiGenerated;
  final SafetyReportTarget? questionReportTarget;
  final double questionOpacity;
  final bool hasBothCardStacks;
  final bool canAddCard;
  final VoidCallback? onAddCard;
  final VoidCallback? onQuestionTap;
  final Key? questionDismissibleKey;
  final VoidCallback? onQuestionDismissed;
  final ValueChanged<StoryCardStackPreview> onCardTap;

  static const _entryGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final storyEntry = _HomeStoryEntry(
      myStack: myStack,
      partnerStack: partnerStack,
      canAddCard: canAddCard,
      onAddCard: onAddCard,
      hasBothCardStacks: hasBothCardStacks,
      onCardTap: onCardTap,
    );
    final questionText = this.questionText;
    final hasStoryEntry = myStack != null || partnerStack != null || canAddCard;
    final maximumCardHeight = hasBothCardStacks
        ? HomeHangingStoryCards.maximumCompactHeight
        : HomeHangingStoryCards.maximumStandardHeight;

    if (questionText == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final cardHeight = constraints.hasBoundedHeight
              ? math.min(maximumCardHeight, constraints.maxHeight)
              : maximumCardHeight;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(height: cardHeight, child: storyEntry),
          );
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: hasStoryEntry
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final cardHeight = constraints.hasBoundedHeight
                        ? math.min(maximumCardHeight, constraints.maxHeight)
                        : maximumCardHeight;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOutCubic,
                        height: cardHeight,
                        alignment: Alignment.topCenter,
                        child: storyEntry,
                      ),
                    );
                  },
                )
              : const SizedBox.shrink(),
        ),
        if (hasStoryEntry) const SizedBox(height: _entryGap),
        _HomeQuestionAction(
          questionText: questionText,
          isAiGenerated: questionIsAiGenerated,
          reportTarget: questionReportTarget,
          opacity: questionOpacity,
          onTap: onQuestionTap,
          dismissibleKey: questionDismissibleKey,
          onDismissed: onQuestionDismissed,
        ),
      ],
    );
  }
}

class _HomeStoryEntry extends StatelessWidget {
  const _HomeStoryEntry({
    required this.myStack,
    required this.partnerStack,
    required this.canAddCard,
    required this.onAddCard,
    required this.hasBothCardStacks,
    required this.onCardTap,
  });

  final StoryCardStackPreview? myStack;
  final StoryCardStackPreview? partnerStack;
  final bool canAddCard;
  final VoidCallback? onAddCard;
  final bool hasBothCardStacks;
  final ValueChanged<StoryCardStackPreview> onCardTap;

  @override
  Widget build(BuildContext context) {
    final myStack = this.myStack;
    final partnerStack = this.partnerStack;
    if (myStack == null && partnerStack == null && !canAddCard) {
      return const SizedBox.shrink();
    }

    final size = hasBothCardStacks
        ? HomeHangingStoryCardSize.compact
        : HomeHangingStoryCardSize.standard;
    final content = HomeHangingStoryCards(
      key: const Key('home-story-line'),
      size: size,
      leadingBuilder: canAddCard && myStack == null
          ? (context, cardWidth) => _HomeStoryAddButton(onPressed: onAddCard)
          : null,
      leftCardBuilder: myStack == null
          ? null
          : (context, cardWidth) => _HomeStoryCardStackThumbnail(
              stack: myStack,
              width: cardWidth,
              onTap: () => onCardTap(myStack),
              onAddCard: canAddCard ? onAddCard : null,
            ),
      rightCardBuilder: partnerStack == null
          ? null
          : (context, cardWidth) => _HomeStoryCardStackThumbnail(
              stack: partnerStack,
              width: cardWidth,
              onTap: () => onCardTap(partnerStack),
            ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}

class _HomeStoryAddButton extends StatelessWidget {
  const _HomeStoryAddButton({
    required this.onPressed,
    this.overCardStack = false,
  });

  final VoidCallback? onPressed;
  final bool overCardStack;

  @override
  Widget build(BuildContext context) {
    final size = overCardStack ? 40.0 : 56.0;
    final button = IconButton(
      key: const Key('home-story-add-button'),
      onPressed: onPressed,
      tooltip: _homeStoryCreateTooltip,
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        padding: EdgeInsets.zero,
        backgroundColor: AppColors.actionPrimary,
        foregroundColor: AppColors.textInverse,
        shape: const CircleBorder(),
      ),
      icon: Icon(Icons.add_rounded, size: overCardStack ? 24 : 28),
    );

    return HomeForegroundPortal(
      portalKey: const Key('home-story-add-foreground'),
      layoutKey: overCardStack,
      placeholder: SizedBox.square(dimension: size),
      child: overCardStack
          ? DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: button,
            )
          : button,
    );
  }
}

class _HomeQuestionAction extends StatelessWidget {
  const _HomeQuestionAction({
    required this.questionText,
    required this.isAiGenerated,
    required this.reportTarget,
    required this.opacity,
    required this.onTap,
    required this.dismissibleKey,
    required this.onDismissed,
  });

  final String questionText;
  final bool isAiGenerated;
  final SafetyReportTarget? reportTarget;
  final double opacity;
  final VoidCallback? onTap;
  final Key? dismissibleKey;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final message = AnimatedOpacity(
      key: const Key('home-question-opacity'),
      opacity: opacity,
      duration: TransientHomeFeedbackPresenter.fadeDuration,
      curve: Curves.easeOut,
      child: _HomeQuestionMessage(
        questionText: questionText,
        isAiGenerated: isAiGenerated,
        reportTarget: reportTarget,
        onTap: onTap,
        actionKey: const Key('home-question-action'),
        messageKey: const Key('home-question-speech-bubble'),
      ),
    );
    final dismissibleKey = this.dismissibleKey;
    final onDismissed = this.onDismissed;

    return HomeForegroundPortal(
      portalKey: const Key('home-question-foreground'),
      layoutKey: (questionText, isAiGenerated),
      placeholder: IgnorePointer(
        child: Opacity(
          opacity: 0,
          child: _HomeQuestionMessage(
            questionText: questionText,
            isAiGenerated: isAiGenerated,
            reportTarget: reportTarget,
          ),
        ),
      ),
      child: dismissibleKey == null || onDismissed == null
          ? message
          : Dismissible(
              key: dismissibleKey,
              direction: DismissDirection.horizontal,
              dismissThresholds: const {
                DismissDirection.startToEnd: 0.3,
                DismissDirection.endToStart: 0.3,
              },
              movementDuration: const Duration(milliseconds: 180),
              resizeDuration: null,
              onDismissed: (_) => onDismissed(),
              child: message,
            ),
    );
  }
}

class _HomeQuestionMessage extends StatelessWidget {
  const _HomeQuestionMessage({
    required this.questionText,
    this.isAiGenerated = false,
    this.reportTarget,
    this.onTap,
    this.actionKey,
    this.messageKey,
  });

  final String questionText;
  final bool isAiGenerated;
  final SafetyReportTarget? reportTarget;
  final VoidCallback? onTap;
  final Key? actionKey;
  final Key? messageKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: CharacterSpeechMessage(
          key: messageKey,
          speechText: questionText,
          maxWidth: 320,
          textStyle: AppTextStyles.homeQuestionBubble,
          trailing: !isAiGenerated
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(start: 2),
                  child: AiGeneratedContentIndicator(
                    onReportPressed: reportTarget == null
                        ? null
                        : () => showSafetyReportSheet(
                            context: context,
                            target: reportTarget!,
                          ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _HomeStoryCardStackThumbnail extends StatelessWidget {
  const _HomeStoryCardStackThumbnail({
    required this.stack,
    required this.width,
    required this.onTap,
    this.onAddCard,
  });

  final StoryCardStackPreview stack;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onAddCard;

  static const _backLayerStyles = [
    _HomeStoryCardBackLayerStyle(offset: Offset(-2.5, 1.5), angle: -0.026),
    _HomeStoryCardBackLayerStyle(offset: Offset(4, -1), angle: 0.035),
  ];

  @override
  Widget build(BuildContext context) {
    final card = stack.latestCard;
    final layerCount = stack.cardCount.clamp(1, 3);
    final previewWidth = math.max(0.0, width - 5);
    return Padding(
      padding: const EdgeInsets.only(top: 5, right: 5),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var depth = layerCount - 1; depth > 0; depth--)
            Transform.translate(
              offset: _backLayerStyles[depth - 1].offset,
              child: Transform.rotate(
                key: Key('home-story-card-${card.id}-stack-layer-$depth'),
                angle: _backLayerStyles[depth - 1].angle,
                child: Container(
                  width: previewWidth,
                  height: previewWidth / storyCardCanvasAspectRatio,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          StoryCardPreviewSurface(
            surfaceKey: Key('home-story-card-${card.id}'),
            previewUrl: card.previewUrl,
            width: previewWidth,
            cornerRadius: 0,
            onTap: onTap,
            semanticsLabel: '$_homeStoryCardSemantics, ${stack.cardCount}장',
          ),
          if (onAddCard != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: _HomeStoryAddButton(
                onPressed: onAddCard,
                overCardStack: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeStoryCardBackLayerStyle {
  const _HomeStoryCardBackLayerStyle({
    required this.offset,
    required this.angle,
  });

  final Offset offset;
  final double angle;
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class _HomeStoryLoopPresentation {
  const _HomeStoryLoopPresentation({
    required this.myStack,
    required this.partnerStack,
    required this.questionText,
    required this.questionIsAiGenerated,
    required this.questionReportTarget,
    required this.hasBothCardStacks,
    required this.canAddCard,
    required this.questionTargetLocation,
  });

  final StoryCardStackPreview? myStack;
  final StoryCardStackPreview? partnerStack;
  final String? questionText;
  final bool questionIsAiGenerated;
  final SafetyReportTarget? questionReportTarget;
  final bool hasBothCardStacks;
  final bool canAddCard;
  final String? questionTargetLocation;

  factory _HomeStoryLoopPresentation.fromSummary({
    required TodayStoryCardStacks? cards,
    required DailyQuestionDetailSnapshot? question,
    required String? currentUserId,
  }) {
    final myStack = cards?.myStack;
    final partnerStack = cards?.partnerStack;
    final isArchived =
        (cards?.accessMode ?? question?.accessMode) ==
        CoupleAccessMode.archivedReadOnly;
    final canAddCard =
        !isArchived && currentUserId != null && cards?.canCreateCard == true;
    final answerState = question?.answerState;
    final questionText = answerState?.hasMyAnswer == true
        ? null
        : question?.question.questionText;

    return _HomeStoryLoopPresentation(
      myStack: myStack,
      partnerStack: partnerStack,
      questionText: questionText,
      questionIsAiGenerated:
          questionText != null &&
          question != null &&
          !question.answerState.hasMyAnswer &&
          question.question.questionSource == QuestionSource.ai,
      questionReportTarget:
          questionText != null &&
              question != null &&
              !question.answerState.hasMyAnswer &&
              question.question.questionSource == QuestionSource.ai
          ? SafetyReportTarget(
              type: SafetyReportTargetType.aiQuestion,
              id: question.question.dailyQuestionId,
            )
          : null,
      hasBothCardStacks: myStack != null && partnerStack != null,
      canAddCard: canAddCard,
      questionTargetLocation: question == null
          ? null
          : _questionTargetLocation(question, isArchived: isArchived),
    );
  }

  static String _questionTargetLocation(
    DailyQuestionDetailSnapshot question, {
    required bool isArchived,
  }) {
    final routeContext = const QuestionRouteContext(
      source: QuestionRouteSource.home,
    );
    return isArchived || question.answerState.hasMyAnswer
        ? routeContext.buildQuestionLocation()
        : routeContext.buildEditLocation();
  }
}
