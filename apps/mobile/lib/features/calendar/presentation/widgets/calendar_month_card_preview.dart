import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_sized_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../story_loops/data/story_loop_card_preview.dart';
import '../../../story_loops/data/story_card_scene.dart';
import '../../../story_loops/presentation/widgets/story_card_preview_surface.dart';
import '../calendar_expanded_cell_layout.dart';

class CalendarMonthCardPreview extends StatelessWidget {
  const CalendarMonthCardPreview({
    super.key,
    required this.cards,
    required this.cellSize,
    required this.expandedLayout,
    required this.previewCacheExtent,
    this.expandedProgress = 0,
  });

  static const _stackWidthFactor = 1.55;

  final List<StoryLoopCardPreview> cards;
  final Size cellSize;
  final CalendarExpandedCellLayout expandedLayout;
  final double previewCacheExtent;
  final double expandedProgress;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.expand();
    }

    final progress = math.min(1.0, math.max(0.0, expandedProgress));
    final compactWidthFromCell = cellSize.width / _stackWidthFactor;
    final compactWidthFromHeight = cellSize.height * storyCardCanvasAspectRatio;
    final compactCardWidth = math.min(
      calendarMonthCompactPreviewSize,
      math.min(compactWidthFromCell, compactWidthFromHeight),
    );
    final cardSlotWidth =
        compactCardWidth +
        ((expandedLayout.cardWidth - compactCardWidth) * progress);
    final compactCardHeight = compactCardWidth / storyCardCanvasAspectRatio;
    final compactHorizontalOffset = cards.length == 2
        ? compactCardWidth * (_stackWidthFactor - 1)
        : 0.0;
    final compactGroupSize = Size(
      compactCardWidth + compactHorizontalOffset,
      compactCardHeight,
    );
    final compactOrigin = Offset(
      (cellSize.width - compactGroupSize.width) / 2,
      (cellSize.height - compactGroupSize.height) / 2,
    );
    final compactOffsets = cards.length == 2
        ? [Offset.zero, Offset(compactHorizontalOffset, 0)]
        : const [Offset.zero];

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        for (var index = 0; index < cards.length; index++)
          Positioned(
            left: _lerpCoordinate(
              compactOrigin.dx +
                  compactOffsets[index].dx +
                  _horizontalCardInset(
                    slotWidth: compactCardWidth,
                    card: cards[index],
                  ),
              expandedLayout.cardOrigin.dx +
                  expandedLayout.cardOffsets[index].dx +
                  _horizontalCardInset(
                    slotWidth: expandedLayout.cardWidth,
                    card: cards[index],
                  ),
              progress,
            ),
            top: _lerpCoordinate(
              compactOrigin.dy + compactOffsets[index].dy,
              expandedLayout.cardOrigin.dy +
                  expandedLayout.cardOffsets[index].dy,
              progress,
            ),
            child: _MonthStorySurface(
              card: cards[index],
              width: StoryCardPreviewSurface.widthInFourByFiveSlot(
                cardSlotWidth,
                cards[index].cardType,
              ),
              previewCacheExtent: previewCacheExtent,
              angle: switch (index) {
                0 when cards.length == 2 => -0.12,
                1 => 0.14,
                _ => 0,
              },
            ),
          ),
      ],
    );
  }

  double _lerpCoordinate(double start, double end, double progress) {
    return start + ((end - start) * progress);
  }

  double _horizontalCardInset({
    required double slotWidth,
    required StoryLoopCardPreview card,
  }) {
    final cardWidth = StoryCardPreviewSurface.widthInFourByFiveSlot(
      slotWidth,
      card.cardType,
    );
    return (slotWidth - cardWidth) / 2;
  }
}

class _MonthStorySurface extends StatelessWidget {
  const _MonthStorySurface({
    required this.card,
    required this.width,
    required this.previewCacheExtent,
    required this.angle,
  });

  final StoryLoopCardPreview card;
  final double width;
  final double previewCacheExtent;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = card.cardType.canvasAspectRatio;
    final height = width / aspectRatio;
    final cacheWidth = StoryCardPreviewSurface.widthInFourByFiveSlot(
      previewCacheExtent,
      card.cardType,
    );

    return Transform.rotate(
      angle: angle,
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: DecoratedBox(
            key: ValueKey('calendar-month-story-card-${card.id}'),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(
                  color: Color(0x28000000),
                  blurRadius: 3,
                  offset: Offset(0, 1.5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2.4),
              child: AppSizedNetworkImage(
                url: card.previewUrl,
                logicalSize: Size(width, height),
                cacheLogicalSize: Size(cacheWidth, cacheWidth / aspectRatio),
                gaplessPlayback: true,
                fallbackBuilder: (_) => _MonthStoryPlaceholder(card: card),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthStoryPlaceholder extends StatelessWidget {
  const _MonthStoryPlaceholder({required this.card});

  final StoryLoopCardPreview card;

  @override
  Widget build(BuildContext context) {
    final seed = card.authorUserId.codeUnits.fold<int>(
      0,
      (value, element) => value + element,
    );
    const palette = [
      Color(0xFFF2EDE7),
      Color(0xFFE9F0ED),
      Color(0xFFECEAF2),
      Color(0xFFF3EFE5),
    ];
    final color = palette[seed % palette.length];

    return ColoredBox(
      color: color,
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Color(0x66111111),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
