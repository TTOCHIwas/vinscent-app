import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../../profile/application/profile_controller.dart';
import '../../questions/presentation/question_route_context.dart';
import '../../questions/presentation/widgets/character_speech_prompt.dart';
import '../../recordings/presentation/widgets/home_character_recording_control.dart';
import '../../story_loops/application/today_story_loop_summary_provider.dart';
import '../../story_loops/data/story_card_scene.dart';
import '../../story_loops/data/story_loop_card_preview.dart';
import '../../story_loops/data/story_loop_question_summary.dart';
import '../../story_loops/data/today_story_loop_summary.dart';
import '../../story_loops/data/today_story_loop_summary_state.dart';
import '../../story_loops/presentation/widgets/story_card_preview_surface.dart';

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
          Expanded(child: _HomeMainStage()),
          Expanded(child: HomeCharacterRecordingControl()),
        ],
      ),
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
      padding: EdgeInsets.symmetric(vertical: 8),
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

class _ResolvedHomeStoryLoopPreview extends StatelessWidget {
  const _ResolvedHomeStoryLoopPreview({
    required this.summary,
    required this.currentUserId,
  });

  final TodayStoryLoopSummary summary;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final presentation = _HomeStoryLoopPresentation.fromSummary(
      summary: summary,
      currentUserId: currentUserId,
    );
    final questionTargetLocation = presentation.questionTargetLocation;

    return _HomeStoryLoopContent(
      myCard: presentation.myCard,
      partnerCard: presentation.partnerCard,
      questionText: presentation.questionText,
      canAddCard: presentation.canAddCard,
      onAddCard: presentation.canAddCard
          ? () => context.go('/home/story')
          : null,
      onQuestionTap: questionTargetLocation == null
          ? null
          : () => context.go(questionTargetLocation),
      cardTargetLocation: presentation.targetLocationForCard,
    );
  }
}

class _HomeStoryLoopContent extends StatelessWidget {
  const _HomeStoryLoopContent({
    required this.myCard,
    required this.partnerCard,
    required this.questionText,
    required this.canAddCard,
    required this.onAddCard,
    required this.onQuestionTap,
    required this.cardTargetLocation,
  });

  final StoryLoopCardPreview? myCard;
  final StoryLoopCardPreview? partnerCard;
  final String? questionText;
  final bool canAddCard;
  final VoidCallback? onAddCard;
  final VoidCallback? onQuestionTap;
  final String? Function(StoryLoopCardPreview card) cardTargetLocation;

  static const _entryGap = 8.0;
  static const _minimumQuestionHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final storyEntry = _CompactStoryEntry(
      myCard: myCard,
      partnerCard: partnerCard,
      canAddCard: canAddCard,
      onAddCard: onAddCard,
      onCardTap: (card) {
        final targetLocation = cardTargetLocation(card);
        return targetLocation == null ? null : () => context.go(targetLocation);
      },
    );
    final questionText = this.questionText;
    final hasCard = myCard != null || partnerCard != null;

    if (questionText == null) {
      return hasCard
          ? Align(alignment: Alignment.topCenter, child: storyEntry)
          : Center(child: storyEntry);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableCardHeight = constraints.hasBoundedHeight
            ? math.max(
                0.0,
                constraints.maxHeight - _minimumQuestionHeight - _entryGap,
              )
            : _CompactStoryEntry._maximumCardHeight;
        final cardHeight = hasCard
            ? math.min(
                _CompactStoryEntry._maximumCardHeight,
                availableCardHeight,
              )
            : 0.0;
        final entryGap = cardHeight > 0 ? _entryGap : 0.0;

        return Column(
          children: [
            if (cardHeight > 0) SizedBox(height: cardHeight, child: storyEntry),
            if (entryGap > 0) SizedBox(height: entryGap),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onQuestionTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: CharacterSpeechBubble(
                        key: const Key('home-question-speech-bubble'),
                        speechText: questionText,
                        maxWidth: 320,
                        maxLines: 4,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        tailSize: const Size(16, 8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompactStoryEntry extends StatelessWidget {
  const _CompactStoryEntry({
    required this.myCard,
    required this.partnerCard,
    required this.canAddCard,
    required this.onAddCard,
    required this.onCardTap,
  });

  static const _maxContentWidth = 360.0;
  static const _slotGap = 16.0;
  static const _maximumCardWidth = (_maxContentWidth - _slotGap) / 2;
  static const _maximumCardHeight =
      _maximumCardWidth / storyCardCanvasAspectRatio;

  final StoryLoopCardPreview? myCard;
  final StoryLoopCardPreview? partnerCard;
  final bool canAddCard;
  final VoidCallback? onAddCard;
  final VoidCallback? Function(StoryLoopCardPreview card) onCardTap;

  @override
  Widget build(BuildContext context) {
    final myCard = this.myCard;
    final partnerCard = this.partnerCard;
    if (myCard == null && partnerCard == null) {
      return canAddCard
          ? _HomeStoryAddButton(onPressed: onAddCard)
          : const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth
            .clamp(0.0, _maxContentWidth)
            .toDouble();
        final availableCardWidth = math.max(0.0, (contentWidth - _slotGap) / 2);
        final heightBoundCardWidth = constraints.hasBoundedHeight
            ? math.max(0.0, constraints.maxHeight) * storyCardCanvasAspectRatio
            : _maximumCardWidth;
        final cardWidth = math.min(
          _maximumCardWidth,
          math.min(availableCardWidth, heightBoundCardWidth),
        );
        final cardHeight = cardWidth / storyCardCanvasAspectRatio;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            height: cardHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HomeStorySlot(
                  width: cardWidth,
                  height: cardHeight,
                  child: myCard == null
                      ? canAddCard
                            ? _HomeStoryAddButton(onPressed: onAddCard)
                            : null
                      : _HomeStoryCardThumbnail(
                          card: myCard,
                          width: cardWidth,
                          onTap: onCardTap(myCard),
                        ),
                ),
                _HomeStorySlot(
                  width: cardWidth,
                  height: cardHeight,
                  child: partnerCard == null
                      ? null
                      : _HomeStoryCardThumbnail(
                          card: partnerCard,
                          width: cardWidth,
                          onTap: onCardTap(partnerCard),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeStorySlot extends StatelessWidget {
  const _HomeStorySlot({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final child = this.child;
    if (child == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: width,
      height: height,
      child: Center(child: child),
    );
  }
}

class _HomeStoryAddButton extends StatelessWidget {
  const _HomeStoryAddButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
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
    required this.canAddCard,
    required this.questionTargetLocation,
    required this.editableCardId,
  });

  final StoryLoopCardPreview? myCard;
  final StoryLoopCardPreview? partnerCard;
  final String? questionText;
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
      questionText: question?.question.questionText,
      canAddCard: canAddCard,
      questionTargetLocation: question == null
          ? null
          : _questionTargetLocation(question, isArchived: isArchived),
      editableCardId: question == null && !isArchived && summary.canEditStory
          ? myCard?.id
          : null,
    );
  }

  String? targetLocationForCard(StoryLoopCardPreview card) {
    final questionTargetLocation = this.questionTargetLocation;
    if (questionTargetLocation != null) {
      return questionTargetLocation;
    }
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
