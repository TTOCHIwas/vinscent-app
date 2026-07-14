import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../characters/presentation/widgets/couple_character_avatar.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../../expressions/application/couple_expression_controller.dart';
import '../../expressions/data/couple_expression.dart';
import '../../profile/application/profile_controller.dart';
import '../../questions/presentation/question_route_context.dart';
import '../../recordings/presentation/widgets/home_recording_panel.dart';
import '../../story_loops/application/today_story_loop_summary_provider.dart';
import '../../story_loops/data/story_loop_card_preview.dart';
import '../../story_loops/data/story_card_scene.dart';
import '../../story_loops/data/story_loop_question_summary.dart';
import '../../story_loops/data/today_story_loop_summary.dart';
import '../../story_loops/data/today_story_loop_summary_state.dart';
import '../application/day_count.dart';

const _homeStatusLoadError =
    '\ucee4\ud50c\u0020\uc815\ubcf4\ub97c\u0020\ubd88\ub7ec\uc624\uc9c0\u0020\ubabb\ud588\uc5b4\uc694\u002e';
const _homeStatusMissingCouple =
    '\ucee4\ud50c\u0020\uc815\ubcf4\ub97c\u0020\ucc3e\uc744\u0020\uc218\u0020\uc5c6\uc5b4\uc694\u002e';
const _homeStatusArchivedNoDate =
    '\uae30\ub85d\u0020\ubcf4\uad00\u0020\uc911\uc774\uc5d0\uc694';
const _homeStatusMissingStartDate =
    '\ucc98\uc74c\u0020\ub9cc\ub09c\u0020\ub0a0\uc744\u0020\uba3c\uc800\u0020\uc785\ub825\ud574\u0020\uc8fc\uc138\uc694\u002e';
const _homeStatusArchivedHeadline =
    '\uae30\ub85d\u0020\ubcf4\uad00\u0020\uc911';
const _homeStatusActiveHeadline = '\uc6b0\ub9ac';
const _homeStatusArchivedSuffix = '\u0020\ubcf4\uad00\u0020\uc911';
const _homeStatusDaySuffix = '\uc77c\uc9f8';

const _homeStoryLoading =
    '\uc624\ub298\u0020\uc2a4\ud1a0\ub9ac\ub97c\u0020\ubd88\ub7ec\uc624\uace0\u0020\uc788\uc5b4\uc694\u002e';
const _homeStoryLoadError =
    '\uc624\ub298\u0020\uc2a4\ud1a0\ub9ac\ub97c\u0020\ubd88\ub7ec\uc624\uc9c0\u0020\ubabb\ud588\uc5b4\uc694\u002e';
const _homeStoryRetry = '\ub2e4\uc2dc\u0020\uc2dc\ub3c4';
const _homeStoryUnavailable =
    '\uc624\ub298\u0020\uc2a4\ud1a0\ub9ac\ub97c\u0020\uc544\uc9c1\u0020\ud655\uc778\ud560\u0020\uc218\u0020\uc5c6\uc5b4\uc694\u002e';
const _homeStoryUnavailableSupporting =
    '\ucee4\ud50c\u0020\uc5f0\uacb0\uacfc\u0020\uc2dc\uc791\uc77c\uc744\u0020\uba3c\uc800\u0020\ud655\uc778\ud574\u0020\uc8fc\uc138\uc694\u002e';
const _homeStoryLabel = '\uc624\ub298\uc758\u0020\uc2a4\ud1a0\ub9ac';
const _homeStoryArchivedEmpty =
    '\ubcf4\uad00\u0020\uc911\uc778\u0020\uc624\ub298\u0020\uc2a4\ud1a0\ub9ac\u0020\uae30\ub85d\uc774\u0020\uc5c6\uc5b4\uc694\u002e';
const _homeStoryEmpty =
    '\uc624\ub298\u0020\uc2a4\ud1a0\ub9ac\u0020\uce74\ub4dc\ub97c\u0020\uc544\uc9c1\u0020\uc544\ubb34\ub3c4\u0020\uc62c\ub9ac\uc9c0\u0020\uc54a\uc558\uc5b4\uc694\u002e';
const _homeStoryReadonlySupporting =
    '\uc9c0\uae08\uc740\u0020\uc77d\uae30\u0020\uc804\uc6a9\uc73c\ub85c\ub9cc\u0020\ubcfc\u0020\uc218\u0020\uc788\uc5b4\uc694\u002e';
const _homeStoryEditorPlaceholder =
    '\uc0ac\uc9c4\u002c\u0020\uadf8\ub9bc\u002c\u0020\uae00\ub85c\u0020\uc624\ub298\uc758\u0020\uce74\ub4dc\ub97c\u0020\ub9cc\ub4e4\uc5b4\u0020\ubcf4\uc138\uc694\u002e';
const _homeStoryArchivedSingle =
    '\ubcf4\uad00\u0020\uc911\uc778\u0020\uc2a4\ud1a0\ub9ac\u0020\uce74\ub4dc\uc608\uc694\u002e';
const _homeStoryMineFirst =
    '\ub0b4\u0020\uc2a4\ud1a0\ub9ac\u0020\uce74\ub4dc\uac00\u0020\uc62c\ub77c\uac14\uc5b4\uc694\u002e';
const _homeStoryPartnerFirst =
    '\uc0c1\ub300\uac00\u0020\uc2a4\ud1a0\ub9ac\u0020\uce74\ub4dc\ub97c\u0020\uc62c\ub838\uc5b4\uc694\u002e';
const _homeStoryWaitingPartner =
    '\uc0c1\ub300\u0020\uce74\ub4dc\uac00\u0020\uc624\uba74\u0020\uc624\ub298\u0020\uc9c8\ubb38\uc774\u0020\uc0dd\uc131\ub3fc\uc694\u002e';
const _homeStoryMyCardPlaceholder =
    '\ub0b4\u0020\uce74\ub4dc\ub97c\u0020\uc62c\ub9ac\uba74\u0020\uc624\ub298\u0020\uc9c8\ubb38\uc774\u0020\uc0dd\uc131\ub3fc\uc694\u002e';
const _homeStoryArchivedDouble =
    '\ubcf4\uad00\u0020\uc911\uc778\u0020\uc2a4\ud1a0\ub9ac\u0020\uce74\ub4dc\uac00\u0020\ubaa8\ub450\u0020\ubaa8\uc5ec\u0020\uc788\uc5b4\uc694\u002e';
const _homeStoryGenerating = '\uc9c8\ubb38\u0020\uc0dd\uc131\u0020\uc911';
const _homeStoryGeneratingSupporting =
    '\ub450\u0020\uce74\ub4dc\uac00\u0020\ubaa8\ub450\u0020\ub3c4\ucc29\ud588\uc5b4\uc694\u002e\u0020\uc624\ub298\u0020\uc9c8\ubb38\uc744\u0020\uc900\ube44\ud558\uace0\u0020\uc788\uc5b4\uc694\u002e';
const _homeStoryAiPlaceholder =
    '\u0041\u0049\u0020\ud55c\u0020\uc904\u0020\ud3c9\uc774\u0020\uc5ec\uae30\uc5d0\u0020\ud45c\uc2dc\ub420\u0020\uc608\uc815\uc774\uc5d0\uc694\u002e';
const _homeStoryPartnerAnswered =
    '\uc0c1\ub300\ubc29\uc740\u0020\ub2f5\ubcc0\uc744\u0020\ub0a8\uacbc\uc5b4\uc694\u002e';
const _homeStoryWaitingAnswer =
    '\uc0c1\ub300\ubc29\uc758\u0020\ub2f5\ubcc0\uc744\u0020\uae30\ub2e4\ub9ac\uace0\u0020\uc788\uc5b4\uc694\u002e';
const _homeStoryActionRead = '\uae30\ub85d\u0020\ubcf4\uae30';
const _homeStoryActionQuestion =
    '\uc624\ub298\u0020\uc9c8\ubb38\u0020\ubcf4\uae30';
const _homeStoryActionAnswer = '\ub2f5\ubcc0\u0020\ub0a8\uae30\uae30';
const _homeStoryActionCreate = '\uce74\ub4dc\u0020\uc791\uc131';
const _homeStoryActionEdit = '\uce74\ub4dc\u0020\uc218\uc815';

const _homeExpressionArchivedHint =
    '\ubcf4\uad00\u0020\uc911\uc5d0\ub294\u0020\ud45c\ud604\u0020\ubcf4\ub0b4\uae30\uac00\u0020\uc7a0\uc2dc\u0020\ub9c9\ud600\u0020\uc788\uc5b4\uc694\u002e';
const _homeExpressionSent =
    '\ud45c\ud604\uc744\u0020\ubcf4\ub0c8\uc5b4\uc694\u002e';
const _homeExpressionSendFailed =
    '\ud45c\ud604\uc744\u0020\ubcf4\ub0b4\uc9c0\u0020\ubabb\ud588\uc5b4\uc694\u002e';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentMinHeight = (constraints.maxHeight - 64).clamp(
          0.0,
          double.infinity,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: contentMinHeight),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CoupleStatus(),
                  _HomeMainStage(),
                  HomeRecordingPanel(),
                  _ExpressionGrid(),
                ],
              ),
            ),
          ),
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

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: couple.when(
          loading: () => const Align(
            alignment: Alignment.centerRight,
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, stackTrace) =>
              const _CoupleStatusMessage(_homeStatusLoadError),
          data: (couple) {
            if (couple == null) {
              return const _CoupleStatusMessage(_homeStatusMissingCouple);
            }

            if (!couple.hasRelationshipStartDate) {
              return Text(
                couple.isArchivedReadOnly
                    ? _homeStatusArchivedNoDate
                    : _homeStatusMissingStartDate,
                textAlign: TextAlign.end,
                style: AppTextStyles.homeBody.copyWith(
                  color: AppColors.textMuted,
                ),
              );
            }

            final dayCount = calculateRelationshipDayCount(
              startDate: couple.relationshipStartDate!,
              today: couple.effectiveCurrentDate,
            );
            final headline = couple.isArchivedReadOnly
                ? _homeStatusArchivedHeadline
                : _homeStatusActiveHeadline;
            final suffix = couple.isArchivedReadOnly
                ? _homeStatusArchivedSuffix
                : _homeStatusDaySuffix;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(headline, style: AppTextStyles.homeBody),
                const SizedBox(height: 4),
                RichText(
                  textAlign: TextAlign.end,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'D+',
                        style: AppTextStyles.homeBodyMedium,
                      ),
                      TextSpan(
                        text: '$dayCount',
                        style: AppTextStyles.homeDayCount,
                      ),
                      TextSpan(
                        text: suffix,
                        style: AppTextStyles.homeBodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
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
    return const SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            _HomeStoryLoopPreview(),
            SizedBox(height: 24),
            _HomeCharacterArea(),
          ],
        ),
      ),
    );
  }
}

class _HomeCharacterArea extends StatelessWidget {
  const _HomeCharacterArea();

  @override
  Widget build(BuildContext context) {
    return CoupleCharacterAvatar(
      size: 160,
      onTap: () => context.go('/home/character'),
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
      loading: () => const _HomeStoryLoopCard(
        message: _homeStoryLoading,
        footer: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) => _HomeStoryLoopCard(
        message: _homeStoryLoadError,
        footer: TextButton(
          onPressed: () => ref.invalidate(todayStoryLoopSummaryProvider),
          child: const Text(_homeStoryRetry),
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
          UnavailableTodayStoryLoopSummaryState() => const _HomeStoryLoopCard(
            message: _homeStoryUnavailable,
            supportingText: _homeStoryUnavailableSupporting,
          ),
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

    return _HomeStoryLoopCard(
      cards: presentation.cards,
      message: presentation.message,
      supportingText: presentation.supportingText,
      actionLabel: presentation.actionLabel,
      onActionTap: presentation.onActionTap == null
          ? null
          : () => presentation.onActionTap!(context),
    );
  }
}

class _HomeStoryLoopCard extends StatelessWidget {
  const _HomeStoryLoopCard({
    required this.message,
    this.cards = const [],
    this.supportingText,
    this.actionLabel,
    this.onActionTap,
    this.footer,
  });

  final List<StoryLoopCardPreview> cards;
  final String message;
  final String? supportingText;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    final footer = this.footer;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onActionTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Text(_homeStoryLabel, style: AppTextStyles.homeBody),
              const SizedBox(height: 16),
              _HomeStoryCardStack(cards: cards),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.homeBodyMedium,
              ),
              if (supportingText != null) ...[
                const SizedBox(height: 8),
                Text(
                  supportingText!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.homeCharacterLabel.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              if (actionLabel != null && onActionTap != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: onActionTap, child: Text(actionLabel)),
              ] else if (footer != null) ...[
                const SizedBox(height: 12),
                footer,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeStoryCardStack extends StatelessWidget {
  const _HomeStoryCardStack({required this.cards});

  final List<StoryLoopCardPreview> cards;

  @override
  Widget build(BuildContext context) {
    final visibleCards = [...cards]
      ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    final limitedCards = visibleCards.take(2).toList(growable: false);

    if (limitedCards.isEmpty) {
      return const _HomeStoryCardEmptySlot();
    }

    if (limitedCards.length == 1) {
      return Center(
        child: _HomeStoryCardSurface(card: limitedCards.first, width: 180),
      );
    }

    return Center(
      child: SizedBox(
        width: 280,
        height: 330,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 8,
              top: 10,
              child: Transform.rotate(
                angle: -0.05,
                child: _HomeStoryCardSurface(
                  card: limitedCards.first,
                  width: 170,
                  backgroundColor: const Color(0xFFF3F0EA),
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 18,
              child: Transform.rotate(
                angle: 0.1,
                child: _HomeStoryCardSurface(
                  card: limitedCards[1],
                  width: 170,
                  backgroundColor: const Color(0xFFEAF2EF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeStoryCardEmptySlot extends StatelessWidget {
  const _HomeStoryCardEmptySlot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: AspectRatio(
        aspectRatio: storyCardCanvasAspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.wireframeBorder),
          ),
          child: const Center(
            child: Icon(
              Icons.auto_awesome_mosaic_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeStoryCardSurface extends StatelessWidget {
  const _HomeStoryCardSurface({
    required this.card,
    required this.width,
    this.backgroundColor = Colors.white,
  });

  final StoryLoopCardPreview card;
  final double width;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final previewUrl = card.previewUrl;
    final previewUri = previewUrl == null ? null : Uri.tryParse(previewUrl);
    final hasRemotePreview =
        previewUri != null &&
        previewUri.hasScheme &&
        (previewUri.scheme == 'http' || previewUri.scheme == 'https');

    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: storyCardCanvasAspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.wireframeBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Positioned.fill(
                  child: hasRemotePreview
                      ? Image.network(
                          previewUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const _HomeStoryCardPreviewPlaceholder();
                          },
                        )
                      : const _HomeStoryCardPreviewPlaceholder(),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC171717),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        _formatStoryCardTime(card.submittedAt),
                        style: AppTextStyles.homeCharacterLabel.copyWith(
                          color: AppColors.textInverse,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
          size: 40,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _HomeStoryLoopPresentation {
  const _HomeStoryLoopPresentation({
    required this.cards,
    required this.message,
    this.supportingText,
    this.actionLabel,
    this.onActionTap,
  });

  final List<StoryLoopCardPreview> cards;
  final String message;
  final String? supportingText;
  final String? actionLabel;
  final void Function(BuildContext context)? onActionTap;

  factory _HomeStoryLoopPresentation.fromSummary({
    required TodayStoryLoopSummary summary,
    required String? currentUserId,
  }) {
    final sortedCards = [...summary.cards]
      ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    final question = summary.question;
    final isArchived = summary.accessMode == CoupleAccessMode.archivedReadOnly;

    if (question != null) {
      return _fromQuestionSummary(
        cards: sortedCards,
        question: question,
        isArchived: isArchived,
      );
    }

    if (sortedCards.isEmpty) {
      return _HomeStoryLoopPresentation(
        cards: const [],
        message: isArchived ? _homeStoryArchivedEmpty : _homeStoryEmpty,
        supportingText: isArchived
            ? _homeStoryReadonlySupporting
            : _homeStoryEditorPlaceholder,
        actionLabel: isArchived ? null : _homeStoryActionCreate,
        onActionTap: isArchived ? null : (context) => context.go('/home/story'),
      );
    }

    if (sortedCards.length == 1) {
      final isMyCard =
          currentUserId != null &&
          sortedCards.first.authorUserId == currentUserId;
      return _HomeStoryLoopPresentation(
        cards: sortedCards,
        message: isArchived
            ? _homeStoryArchivedSingle
            : isMyCard
            ? _homeStoryMineFirst
            : _homeStoryPartnerFirst,
        supportingText: isArchived
            ? _homeStoryReadonlySupporting
            : isMyCard
            ? _homeStoryWaitingPartner
            : _homeStoryMyCardPlaceholder,
        actionLabel: isArchived
            ? null
            : isMyCard
            ? _homeStoryActionEdit
            : _homeStoryActionCreate,
        onActionTap: isArchived ? null : (context) => context.go('/home/story'),
      );
    }

    return _HomeStoryLoopPresentation(
      cards: sortedCards,
      message: isArchived ? _homeStoryArchivedDouble : _homeStoryGenerating,
      supportingText: isArchived
          ? _homeStoryReadonlySupporting
          : _homeStoryGeneratingSupporting,
    );
  }

  static _HomeStoryLoopPresentation _fromQuestionSummary({
    required List<StoryLoopCardPreview> cards,
    required StoryLoopQuestionSummary question,
    required bool isArchived,
  }) {
    final routeContext = const QuestionRouteContext(
      source: QuestionRouteSource.home,
    );
    final hasMyAnswer = question.myAnswerExists;
    final hasPartnerAnswer = question.partnerAnswerExists;
    final isCompleted = hasMyAnswer && hasPartnerAnswer;

    final message = isCompleted
        ? _homeStoryAiPlaceholder
        : !hasMyAnswer && hasPartnerAnswer
        ? _homeStoryPartnerAnswered
        : hasMyAnswer
        ? _homeStoryWaitingAnswer
        : question.question.questionText;

    final actionLabel = isArchived
        ? _homeStoryActionRead
        : hasMyAnswer
        ? _homeStoryActionQuestion
        : _homeStoryActionAnswer;
    final targetLocation = isArchived || hasMyAnswer
        ? routeContext.buildQuestionLocation()
        : routeContext.buildEditLocation();

    return _HomeStoryLoopPresentation(
      cards: cards,
      message: message,
      supportingText: isArchived ? _homeStoryReadonlySupporting : null,
      actionLabel: actionLabel,
      onActionTap: (context) => context.go(targetLocation),
    );
  }
}

String _formatStoryCardTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _ExpressionGrid extends ConsumerWidget {
  const _ExpressionGrid();

  static const _actions = [
    _ExpressionAction(
      type: CoupleExpressionType.missYou,
      icon: Icons.favorite_border,
    ),
    _ExpressionAction(
      type: CoupleExpressionType.thanks,
      icon: Icons.thumb_up_alt_outlined,
    ),
    _ExpressionAction(
      type: CoupleExpressionType.feelingDown,
      icon: Icons.sentiment_dissatisfied_outlined,
    ),
    _ExpressionAction(
      type: CoupleExpressionType.cheerUp,
      icon: Icons.wb_sunny_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expressionState = ref.watch(coupleExpressionControllerProvider);
    final couple = ref.watch(
      coupleControllerProvider.select(
        (state) => state.maybeWhen(data: (value) => value, orElse: () => null),
      ),
    );
    final isSending = expressionState.isLoading;
    final canSend = (couple?.canEditSharedData ?? false) && !isSending;

    return Column(
      children: [
        if (couple?.isArchivedReadOnly == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _homeExpressionArchivedHint,
              style: AppTextStyles.homeCharacterLabel.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _ExpressionButton(
                action: _actions[0],
                isEnabled: canSend,
                onTap: () => _sendExpression(context, ref, _actions[0].type),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExpressionButton(
                action: _actions[1],
                isEnabled: canSend,
                onTap: () => _sendExpression(context, ref, _actions[1].type),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ExpressionButton(
                action: _actions[2],
                isEnabled: canSend,
                onTap: () => _sendExpression(context, ref, _actions[2].type),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExpressionButton(
                action: _actions[3],
                isEnabled: canSend,
                onTap: () => _sendExpression(context, ref, _actions[3].type),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _sendExpression(
    BuildContext context,
    WidgetRef ref,
    CoupleExpressionType type,
  ) async {
    try {
      await ref.read(coupleExpressionControllerProvider.notifier).send(type);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_homeExpressionSent)));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_homeExpressionSendFailed)));
    }
  }
}

class _ExpressionAction {
  const _ExpressionAction({required this.type, required this.icon});

  final CoupleExpressionType type;
  final IconData icon;
}

class _ExpressionButton extends StatelessWidget {
  const _ExpressionButton({
    required this.action,
    required this.isEnabled,
    required this.onTap,
  });

  final _ExpressionAction action;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isEnabled
        ? AppColors.textPrimary
        : AppColors.actionDisabledContent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.wireframeBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 24, color: foreground),
              const SizedBox(width: 10),
              Text(
                action.type.label,
                style: AppTextStyles.homeBody.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
