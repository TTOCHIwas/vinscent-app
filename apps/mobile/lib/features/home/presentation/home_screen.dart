import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../ai/application/ai_learning_controller.dart';
import '../../ai/application/ai_question_feedback_provider.dart';
import '../../ai/data/ai_learning_dashboard.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../../profile/application/profile_controller.dart';
import '../../questions/presentation/question_route_context.dart';
import '../../../core/presentation/widgets/character_speech_bubble.dart';
import '../../recordings/application/couple_recording_overview_controller.dart';
import '../../recordings/presentation/widgets/home_character_recording_control.dart';
import '../../recordings/presentation/widgets/home_recording_artwork_layer.dart';
import '../../story_loops/application/today_story_loop_summary_provider.dart';
import '../../story_loops/data/story_loop_card_preview.dart';
import '../../story_loops/data/story_loop_question_summary.dart';
import '../../story_loops/data/story_loop_status.dart';
import '../../story_loops/data/today_story_loop_summary.dart';
import '../../story_loops/data/today_story_loop_summary_state.dart';
import '../../story_loops/presentation/widgets/story_card_detail_overlay.dart';
import '../../story_loops/presentation/widgets/story_card_preview_surface.dart';
import '../application/home_guide.dart';
import 'widgets/home_hanging_story_cards.dart';
import 'widgets/home_guide_rotator.dart';
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
const _homeQuestionPreparingPrompt = '둘에게 어울릴 질문을 고르고 있어!';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomNavigationClearance = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomNavigationClearance),
      child: const Column(
        children: [
          _CoupleStatus(),
          Expanded(child: _HomeStageLayout()),
        ],
      ),
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
            child: CircularProgressIndicator(strokeWidth: 2),
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
    final summaryAsync = ref.watch(todayStoryLoopSummaryProvider);

    return summaryAsync.when(
      loading: () => const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) => Center(
        child: IconButton(
          onPressed: () => ref.invalidate(todayStoryLoopSummaryProvider),
          tooltip: _homeStoryRetryTooltip,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ),
      data: (state) {
        return switch (state) {
          LoadedTodayStoryLoopSummaryState(summary: final summary) =>
            _ResolvedHomeStoryLoopPreview(
              summary: summary,
              currentUserId: profile?.id,
            ),
          EmptyTodayStoryLoopSummaryState(summary: final summary) =>
            _ResolvedHomeStoryLoopPreview(
              summary: summary,
              currentUserId: profile?.id,
            ),
          UnavailableTodayStoryLoopSummaryState() => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _ResolvedHomeStoryLoopPreview extends ConsumerWidget {
  const _ResolvedHomeStoryLoopPreview({
    required this.summary,
    required this.currentUserId,
  });

  final TodayStoryLoopSummary summary;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentation = _HomeStoryLoopPresentation.fromSummary(
      summary: summary,
      currentUserId: currentUserId,
    );
    final question = summary.question;
    _HomeAiMessage? aiMessage;
    if (question != null &&
        question.myAnswerExists &&
        question.partnerAnswerExists) {
      final feedbackState = ref
          .watch(aiQuestionFeedbackProvider(question.question.dailyQuestionId))
          .maybeWhen(data: (state) => state, orElse: () => null);
      aiMessage = _HomeAiMessage.fromState(
        dailyQuestionId: question.question.dailyQuestionId,
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
    final needsAiConsent = ref.watch(
      aiLearningControllerProvider.select(
        (state) => state.maybeWhen(
          data: (dashboard) =>
              dashboard.progress.myConsent == AiConsentStatus.revoked,
          orElse: () => false,
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
            canCreateCard: presentation.canAddCard,
            canRecord:
                characterPromptState.canGuideRecording &&
                question == null &&
                recordingGuideState.isReady,
            hasCurrentRecording: recordingGuideState.hasCurrentRecording,
            hasSavedRecordingSlot: recordingGuideState.hasSavedRecordingSlot,
            needsAiConsent: needsAiConsent,
          )
        : const <HomeGuide>[];

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
            final questionText =
                characterGuideText ??
                visibleFeedbackText ??
                presentation.questionText ??
                guide?.message;
            final questionOpacity = visibleFeedbackText != null
                ? feedbackOpacity
                : guide != null
                ? guideOpacity
                : 1.0;
            final onQuestionTap =
                onGuideTap ??
                (questionTargetLocation == null
                    ? null
                    : () => context.go(questionTargetLocation));

            return _HomeStoryLoopContent(
              myCard: presentation.myCard,
              partnerCard: presentation.partnerCard,
              questionText: questionText,
              questionOpacity: questionOpacity,
              cardsAreCompleted: presentation.cardsAreCompleted,
              canAddCard: presentation.canAddCard,
              onAddCard: presentation.canAddCard
                  ? () => context.go('/home/story')
                  : null,
              onQuestionTap: onQuestionTap,
              onCardTap: (card) {
                final editTargetLocation = presentation
                    .editTargetLocationForCard(card);
                if (editTargetLocation != null) {
                  context.go(editTargetLocation);
                  return;
                }
                showStoryCardDetailOverlay(
                  context: context,
                  cardId: card.id,
                  previewUrl: card.previewUrl,
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
        context.go('/home/story');
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
  });

  factory _HomeAiMessage.processing(String dailyQuestionId) {
    return _HomeAiMessage(
      impressionId: '$dailyQuestionId:processing',
      text: _homeFeedbackProcessingPrompt,
      duration: _homeFeedbackProcessingDuration,
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
    );
  }

  final String impressionId;
  final String text;
  final Duration duration;
}

class _HomeStoryLoopContent extends StatelessWidget {
  const _HomeStoryLoopContent({
    required this.myCard,
    required this.partnerCard,
    required this.questionText,
    required this.questionOpacity,
    required this.cardsAreCompleted,
    required this.canAddCard,
    required this.onAddCard,
    required this.onQuestionTap,
    required this.onCardTap,
  });

  final StoryLoopCardPreview? myCard;
  final StoryLoopCardPreview? partnerCard;
  final String? questionText;
  final double questionOpacity;
  final bool cardsAreCompleted;
  final bool canAddCard;
  final VoidCallback? onAddCard;
  final VoidCallback? onQuestionTap;
  final ValueChanged<StoryLoopCardPreview> onCardTap;

  static const _entryGap = 8.0;
  static const _minimumQuestionHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final storyEntry = _HomeStoryEntry(
      myCard: myCard,
      partnerCard: partnerCard,
      canAddCard: canAddCard,
      onAddCard: onAddCard,
      cardsAreCompleted: cardsAreCompleted,
      onCardTap: onCardTap,
    );
    final questionText = this.questionText;
    final hasStoryEntry = myCard != null || partnerCard != null || canAddCard;
    final maximumCardHeight = cardsAreCompleted
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableCardHeight = constraints.hasBoundedHeight
            ? math.max(
                0.0,
                constraints.maxHeight - _minimumQuestionHeight - _entryGap,
              )
            : maximumCardHeight;
        final cardHeight = hasStoryEntry
            ? math.min(maximumCardHeight, availableCardHeight)
            : 0.0;
        final entryGap = cardHeight > 0 ? _entryGap : 0.0;

        return Column(
          children: [
            if (cardHeight > 0)
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                height: cardHeight,
                alignment: Alignment.topCenter,
                child: storyEntry,
              ),
            if (entryGap > 0) SizedBox(height: entryGap),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _HomeQuestionAction(
                  questionText: questionText,
                  opacity: questionOpacity,
                  onTap: onQuestionTap,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeStoryEntry extends StatelessWidget {
  const _HomeStoryEntry({
    required this.myCard,
    required this.partnerCard,
    required this.canAddCard,
    required this.onAddCard,
    required this.cardsAreCompleted,
    required this.onCardTap,
  });

  final StoryLoopCardPreview? myCard;
  final StoryLoopCardPreview? partnerCard;
  final bool canAddCard;
  final VoidCallback? onAddCard;
  final bool cardsAreCompleted;
  final ValueChanged<StoryLoopCardPreview> onCardTap;

  @override
  Widget build(BuildContext context) {
    final myCard = this.myCard;
    final partnerCard = this.partnerCard;
    if (myCard == null && partnerCard == null && !canAddCard) {
      return const SizedBox.shrink();
    }

    final size = cardsAreCompleted && myCard != null && partnerCard != null
        ? HomeHangingStoryCardSize.compact
        : HomeHangingStoryCardSize.standard;
    final content = HomeHangingStoryCards(
      key: const Key('home-story-line'),
      size: size,
      leftCardBuilder: myCard == null
          ? canAddCard
                ? (context, cardWidth) =>
                      _HomeStoryAddButton(onPressed: onAddCard)
                : null
          : (context, cardWidth) => _HomeStoryCardThumbnail(
              card: myCard,
              width: cardWidth,
              onTap: () => onCardTap(myCard),
            ),
      rightCardBuilder: partnerCard == null
          ? null
          : (context, cardWidth) => _HomeStoryCardThumbnail(
              card: partnerCard,
              width: cardWidth,
              onTap: () => onCardTap(partnerCard),
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
  const _HomeStoryAddButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _HomeForegroundPortal(
      portalKey: const Key('home-story-add-foreground'),
      placeholder: const SizedBox.square(dimension: 56),
      child: IconButton(
        key: const Key('home-story-add-button'),
        onPressed: onPressed,
        tooltip: _homeStoryCreateTooltip,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(56),
          backgroundColor: AppColors.actionPrimary,
          foregroundColor: AppColors.textInverse,
          shape: const CircleBorder(),
        ),
        icon: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

class _HomeQuestionAction extends StatelessWidget {
  const _HomeQuestionAction({
    required this.questionText,
    required this.opacity,
    required this.onTap,
  });

  final String questionText;
  final double opacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _HomeForegroundPortal(
      portalKey: const Key('home-question-foreground'),
      layoutKey: questionText,
      placeholder: IgnorePointer(
        child: Opacity(
          opacity: 0,
          child: _HomeQuestionBubble(questionText: questionText),
        ),
      ),
      child: AnimatedOpacity(
        key: const Key('home-question-opacity'),
        opacity: opacity,
        duration: TransientHomeFeedbackPresenter.fadeDuration,
        curve: Curves.easeOut,
        child: _HomeQuestionBubble(
          questionText: questionText,
          onTap: onTap,
          actionKey: const Key('home-question-action'),
          bubbleKey: const Key('home-question-speech-bubble'),
        ),
      ),
    );
  }
}

class _HomeQuestionBubble extends StatelessWidget {
  const _HomeQuestionBubble({
    required this.questionText,
    this.onTap,
    this.actionKey,
    this.bubbleKey,
  });

  final String questionText;
  final VoidCallback? onTap;
  final Key? actionKey;
  final Key? bubbleKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: CharacterSpeechBubble(
          key: bubbleKey,
          speechText: questionText,
          maxWidth: 320,
          maxLines: 4,
          textStyle: AppTextStyles.homeQuestionBubble,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 9,
          ),
          tailSize: const Size(16, 8),
        ),
      ),
    );
  }
}

class _HomeForegroundPortal extends StatefulWidget {
  const _HomeForegroundPortal({
    required this.portalKey,
    required this.placeholder,
    required this.child,
    this.layoutKey,
  });

  final Key portalKey;
  final Widget placeholder;
  final Widget child;
  final Object? layoutKey;

  @override
  State<_HomeForegroundPortal> createState() => _HomeForegroundPortalState();
}

class _HomeForegroundPortalState extends State<_HomeForegroundPortal> {
  late final OverlayPortalController _controller = OverlayPortalController()
    ..show();
  final GlobalKey _placeholderKey = GlobalKey();
  Size? _placeholderSize;
  bool _measurementScheduled = false;

  @override
  void didUpdateWidget(covariant _HomeForegroundPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutKey != widget.layoutKey) {
      _placeholderSize = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _placeholderSize = null;
  }

  void _schedulePlaceholderMeasurement() {
    if (_measurementScheduled) {
      return;
    }
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted || _placeholderSize != null) {
        return;
      }
      final renderObject = _placeholderKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return;
      }
      setState(() {
        _placeholderSize = renderObject.size;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeholderSize = _placeholderSize;
    if (placeholderSize == null) {
      _schedulePlaceholderMeasurement();
    }

    return OverlayPortal.overlayChildLayoutBuilder(
      key: widget.portalKey,
      controller: _controller,
      overlayChildBuilder: (context, info) {
        final offset = MatrixUtils.transformPoint(
          info.childPaintTransform,
          Offset.zero,
        );
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          width: info.childSize.width,
          height: info.childSize.height,
          child: widget.child,
        );
      },
      child: placeholderSize == null
          ? KeyedSubtree(key: _placeholderKey, child: widget.placeholder)
          : SizedBox.fromSize(size: placeholderSize),
    );
  }
}

class _HomeStoryCardThumbnail extends StatelessWidget {
  const _HomeStoryCardThumbnail({
    required this.card,
    required this.width,
    required this.onTap,
  });

  final StoryLoopCardPreview card;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StoryCardPreviewSurface(
      surfaceKey: Key('home-story-card-${card.id}'),
      previewUrl: card.previewUrl,
      width: width,
      onTap: onTap,
      semanticsLabel: _homeStoryCardSemantics,
    );
  }
}

class _HomeStoryLoopPresentation {
  const _HomeStoryLoopPresentation({
    required this.myCard,
    required this.partnerCard,
    required this.questionText,
    required this.cardsAreCompleted,
    required this.canAddCard,
    required this.questionTargetLocation,
    required this.editableCardId,
  });

  final StoryLoopCardPreview? myCard;
  final StoryLoopCardPreview? partnerCard;
  final String? questionText;
  final bool cardsAreCompleted;
  final bool canAddCard;
  final String? questionTargetLocation;
  final String? editableCardId;

  factory _HomeStoryLoopPresentation.fromSummary({
    required TodayStoryLoopSummary summary,
    required String? currentUserId,
  }) {
    final sortedCards = [...summary.cards]
      ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    final question = summary.question;
    final isArchived = summary.accessMode == CoupleAccessMode.archivedReadOnly;
    StoryLoopCardPreview? myCard;
    StoryLoopCardPreview? partnerCard;
    if (currentUserId != null) {
      for (final card in sortedCards) {
        if (card.authorUserId == currentUserId) {
          myCard ??= card;
        } else {
          partnerCard ??= card;
        }
      }
    }
    final canAddCard =
        !isArchived &&
        currentUserId != null &&
        summary.canEditStory &&
        myCard == null;

    return _HomeStoryLoopPresentation(
      myCard: myCard,
      partnerCard: partnerCard,
      questionText: switch ((summary.loopStatus, question)) {
        (_, final question?) when question.myAnswerExists => null,
        (_, final question?) => question.question.questionText,
        (StoryLoopStatus.questionPreparing, null) =>
          _homeQuestionPreparingPrompt,
        _ => null,
      },
      cardsAreCompleted:
          myCard != null &&
          partnerCard != null &&
          question?.myAnswerExists == true &&
          question?.partnerAnswerExists == true,
      canAddCard: canAddCard,
      questionTargetLocation: question == null
          ? null
          : _questionTargetLocation(question, isArchived: isArchived),
      editableCardId: question == null && !isArchived && summary.canEditStory
          ? myCard?.id
          : null,
    );
  }

  String? editTargetLocationForCard(StoryLoopCardPreview card) {
    return card.id == editableCardId ? '/home/story' : null;
  }

  static String _questionTargetLocation(
    StoryLoopQuestionSummary question, {
    required bool isArchived,
  }) {
    final routeContext = const QuestionRouteContext(
      source: QuestionRouteSource.home,
    );
    return isArchived || question.myAnswerExists
        ? routeContext.buildQuestionLocation()
        : routeContext.buildEditLocation();
  }
}
