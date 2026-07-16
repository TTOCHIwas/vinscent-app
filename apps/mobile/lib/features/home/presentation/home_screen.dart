import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../../profile/application/profile_controller.dart';
import '../../questions/presentation/question_route_context.dart';
import '../../recordings/presentation/widgets/home_character_recording_control.dart';
import '../../story_loops/application/today_story_loop_summary_provider.dart';
import '../../story_loops/data/story_card_scene.dart';
import '../../story_loops/data/story_loop_card_preview.dart';
import '../../story_loops/data/story_loop_question_summary.dart';
import '../../story_loops/data/today_story_loop_summary.dart';
import '../../story_loops/data/today_story_loop_summary_state.dart';

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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          _CoupleStatus(),
          Expanded(flex: 4, child: _HomeMainStage()),
          Expanded(flex: 5, child: HomeCharacterRecordingControl()),
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
      cards: presentation.cards,
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
    required this.cards,
    required this.questionText,
    required this.canAddCard,
    required this.onAddCard,
    required this.onQuestionTap,
    required this.cardTargetLocation,
  });

  final List<StoryLoopCardPreview> cards;
  final String? questionText;
  final bool canAddCard;
  final VoidCallback? onAddCard;
  final VoidCallback? onQuestionTap;
  final String? Function(StoryLoopCardPreview card) cardTargetLocation;

  @override
  Widget build(BuildContext context) {
    final storyEntry = _CompactStoryEntry(
      cards: cards,
      canAddCard: canAddCard,
      onAddCard: onAddCard,
      onCardTap: (card) {
        final targetLocation = cardTargetLocation(card);
        return targetLocation == null ? null : () => context.go(targetLocation);
      },
    );
    final questionText = this.questionText;

    if (questionText == null) {
      return Center(child: storyEntry);
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onQuestionTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    questionText,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.shellTitle,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        storyEntry,
      ],
    );
  }
}

class _CompactStoryEntry extends StatelessWidget {
  const _CompactStoryEntry({
    required this.cards,
    required this.canAddCard,
    required this.onAddCard,
    required this.onCardTap,
  });

  final List<StoryLoopCardPreview> cards;
  final bool canAddCard;
  final VoidCallback? onAddCard;
  final VoidCallback? Function(StoryLoopCardPreview card) onCardTap;

  @override
  Widget build(BuildContext context) {
    final visibleCards = cards.take(2).toList(growable: false);
    final entries = <Widget>[
      for (final card in visibleCards)
        _HomeStoryCardThumbnail(card: card, onTap: onCardTap(card)),
      if (canAddCard) _HomeStoryAddButton(onPressed: onAddCard),
    ];

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          if (index > 0) const SizedBox(width: 12),
          entries[index],
        ],
      ],
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
  const _HomeStoryCardThumbnail({required this.card, required this.onTap});

  static const _width = 64.0;

  final StoryLoopCardPreview card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final previewUrl = card.previewUrl;
    final previewUri = previewUrl == null ? null : Uri.tryParse(previewUrl);
    final hasRemotePreview =
        previewUri != null &&
        previewUri.hasScheme &&
        (previewUri.scheme == 'http' || previewUri.scheme == 'https');

    return Semantics(
      label: _homeStoryCardSemantics,
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('home-story-card-${card.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: _width,
            child: AspectRatio(
              aspectRatio: storyCardCanvasAspectRatio,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.wireframeBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: hasRemotePreview
                      ? Image.network(
                          previewUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const _HomeStoryCardPreviewPlaceholder(),
                        )
                      : const _HomeStoryCardPreviewPlaceholder(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeStoryCardPreviewPlaceholder extends StatelessWidget {
  const _HomeStoryCardPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF8F8F8),
      child: Center(
        child: Icon(
          Icons.auto_awesome_mosaic_outlined,
          size: 20,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _HomeStoryLoopPresentation {
  const _HomeStoryLoopPresentation({
    required this.cards,
    required this.questionText,
    required this.canAddCard,
    required this.questionTargetLocation,
    required this.editableCardId,
  });

  final List<StoryLoopCardPreview> cards;
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
    final myCard = currentUserId == null
        ? null
        : sortedCards.cast<StoryLoopCardPreview?>().firstWhere(
            (card) => card?.authorUserId == currentUserId,
            orElse: () => null,
          );
    final canAddCard =
        !isArchived &&
        currentUserId != null &&
        summary.canEditStory &&
        myCard == null;

    return _HomeStoryLoopPresentation(
      cards: sortedCards,
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
