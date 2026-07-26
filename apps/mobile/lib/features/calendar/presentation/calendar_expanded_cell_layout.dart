import 'dart:math' as math;
import 'dart:ui';

import '../../story_loops/data/story_card_scene.dart';

class CalendarExpandedCellLayout {
  const CalendarExpandedCellLayout._({
    required this.cardWidth,
    required this.cardHeight,
    required this.cardOrigin,
    required this.cardOffsets,
    required this.cardGroupSize,
    required this.artworkSize,
    required this.artworkOrigin,
    required this.artworkOffsets,
    required this.artworkGroupSize,
  });

  factory CalendarExpandedCellLayout.resolve({
    required Size size,
    required int cardCount,
    required int artworkCount,
  }) {
    final resolvedSize = Size(
      math.max(0, size.width),
      math.max(0, size.height),
    );
    final resolvedCardCount = math.min(2, math.max(0, cardCount));
    final resolvedArtworkCount = math.max(0, artworkCount);

    if (resolvedCardCount > 0 && resolvedArtworkCount > 0) {
      return _resolveMixed(
        size: resolvedSize,
        cardCount: resolvedCardCount,
        artworkCount: resolvedArtworkCount,
      );
    }
    if (resolvedCardCount > 0) {
      return _resolveCardsOnly(
        size: resolvedSize,
        cardCount: resolvedCardCount,
      );
    }
    if (resolvedArtworkCount > 0) {
      return _resolveArtworkOnly(
        size: resolvedSize,
        artworkCount: resolvedArtworkCount,
      );
    }
    return CalendarExpandedCellLayout._empty;
  }

  static const _cardPairMinimumHorizontalFactor = 0.18;
  static const _cardPairMaximumHorizontalFactor = 0.75;
  static const _cardPairVerticalFactor = 0.65;
  static const _mixedGapFactor = 0.06;
  static const _mixedSingleCardArtworkHeightShare = 0.4;
  static const _mixedCardPairArtworkHeightShare = 0.25;

  static const _empty = CalendarExpandedCellLayout._(
    cardWidth: 0,
    cardHeight: 0,
    cardOrigin: Offset.zero,
    cardOffsets: [],
    cardGroupSize: Size.zero,
    artworkSize: 0,
    artworkOrigin: Offset.zero,
    artworkOffsets: [],
    artworkGroupSize: Size.zero,
  );

  static CalendarExpandedCellLayout _resolveCardsOnly({
    required Size size,
    required int cardCount,
  }) {
    final cardGroup = _resolveCardGroup(size: size, cardCount: cardCount);

    return CalendarExpandedCellLayout._(
      cardWidth: cardGroup.cardWidth,
      cardHeight: cardGroup.cardHeight,
      cardOrigin: _centerOrigin(size, cardGroup.size),
      cardOffsets: cardGroup.offsets,
      cardGroupSize: cardGroup.size,
      artworkSize: 0,
      artworkOrigin: Offset.zero,
      artworkOffsets: const [],
      artworkGroupSize: Size.zero,
    );
  }

  static CalendarExpandedCellLayout _resolveArtworkOnly({
    required Size size,
    required int artworkCount,
  }) {
    final visibleCount = math.min(3, artworkCount);
    final artworkSize = math.min(size.width, size.height / visibleCount);
    final horizontalSpace = math.max(0.0, size.width - artworkSize);
    final offsets = switch (visibleCount) {
      1 => const [Offset.zero],
      2 => [Offset.zero, Offset(horizontalSpace, artworkSize)],
      _ => [
        Offset(horizontalSpace, 0),
        Offset(0, artworkSize),
        Offset(horizontalSpace, artworkSize * 2),
      ],
    };
    final groupSize = Size(
      visibleCount == 1 ? artworkSize : artworkSize + horizontalSpace,
      artworkSize * visibleCount,
    );

    return CalendarExpandedCellLayout._(
      cardWidth: 0,
      cardHeight: 0,
      cardOrigin: Offset.zero,
      cardOffsets: const [],
      cardGroupSize: Size.zero,
      artworkSize: artworkSize,
      artworkOrigin: _centerOrigin(size, groupSize),
      artworkOffsets: offsets,
      artworkGroupSize: groupSize,
    );
  }

  static CalendarExpandedCellLayout _resolveMixed({
    required Size size,
    required int cardCount,
    required int artworkCount,
  }) {
    final visibleArtworkCount = math.min(2, artworkCount);
    final baseCardGroup = _resolveCardGroup(
      size: Size(size.width, double.infinity),
      cardCount: cardCount,
    );
    final baseArtworkSize = size.width / visibleArtworkCount;
    final baseArtworkHeight = baseArtworkSize;
    final desiredGap = math.min(
      size.height,
      size.shortestSide * _mixedGapFactor,
    );
    final availableHeight = math.max(0.0, size.height - desiredGap);
    final artworkHeightShare = cardCount == 2
        ? _mixedCardPairArtworkHeightShare
        : _mixedSingleCardArtworkHeightShare;
    var artworkHeight = baseArtworkHeight;
    var cardGroupHeight = baseCardGroup.size.height;
    if (artworkHeight + cardGroupHeight > availableHeight) {
      artworkHeight = math.min(
        baseArtworkHeight,
        availableHeight * artworkHeightShare,
      );
      cardGroupHeight = math.min(
        baseCardGroup.size.height,
        math.max(0.0, availableHeight - artworkHeight),
      );
      final remainingHeight = math.max(
        0.0,
        availableHeight - artworkHeight - cardGroupHeight,
      );
      artworkHeight += math.min(
        baseArtworkHeight - artworkHeight,
        remainingHeight,
      );
    }
    final artworkScale = baseArtworkHeight <= 0
        ? 0.0
        : artworkHeight / baseArtworkHeight;
    final artworkSize = baseArtworkSize * artworkScale;
    final cardGroup = _resolveCardGroup(
      size: Size(size.width, cardGroupHeight),
      cardCount: cardCount,
    );
    final artworkOffsets = visibleArtworkCount == 2
        ? [Offset.zero, Offset(artworkSize, 0)]
        : const [Offset.zero];
    final artworkGroupSize = Size(
      artworkSize * visibleArtworkCount,
      artworkSize,
    );

    return CalendarExpandedCellLayout._(
      cardWidth: cardGroup.cardWidth,
      cardHeight: cardGroup.cardHeight,
      cardOrigin: Offset(
        (size.width - cardGroup.size.width) / 2,
        artworkGroupSize.height + desiredGap,
      ),
      cardOffsets: cardGroup.offsets,
      cardGroupSize: cardGroup.size,
      artworkSize: artworkSize,
      artworkOrigin: Offset((size.width - artworkGroupSize.width) / 2, 0),
      artworkOffsets: artworkOffsets,
      artworkGroupSize: artworkGroupSize,
    );
  }

  static _CalendarCardGroupLayout _resolveCardGroup({
    required Size size,
    required int cardCount,
  }) {
    final minimumHorizontalFactor = cardCount == 2
        ? _cardPairMinimumHorizontalFactor
        : 0.0;
    final verticalFactor = cardCount == 2 ? _cardPairVerticalFactor : 0.0;
    final cardWidth = math.min(
      size.width / (1 + minimumHorizontalFactor),
      size.height * storyCardCanvasAspectRatio / (1 + verticalFactor),
    );
    final cardHeight = cardWidth / storyCardCanvasAspectRatio;
    final horizontalOffset = cardCount == 2
        ? math.min(
            math.max(0.0, size.width - cardWidth),
            cardWidth * _cardPairMaximumHorizontalFactor,
          )
        : 0.0;
    final offsets = cardCount == 2
        ? [Offset.zero, Offset(horizontalOffset, cardHeight * verticalFactor)]
        : const [Offset.zero];

    return _CalendarCardGroupLayout(
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      offsets: offsets,
      size: Size(
        cardWidth + horizontalOffset,
        cardHeight * (1 + verticalFactor),
      ),
    );
  }

  static Offset _centerOrigin(Size size, Size groupSize) {
    return Offset(
      (size.width - groupSize.width) / 2,
      (size.height - groupSize.height) / 2,
    );
  }

  final double cardWidth;
  final double cardHeight;
  final Offset cardOrigin;
  final List<Offset> cardOffsets;
  final Size cardGroupSize;
  final double artworkSize;
  final Offset artworkOrigin;
  final List<Offset> artworkOffsets;
  final Size artworkGroupSize;

  int get visibleArtworkCount => artworkOffsets.length;

  Rect get cardGroupRect => cardOrigin & cardGroupSize;

  Rect get artworkGroupRect => artworkOrigin & artworkGroupSize;
}

class _CalendarCardGroupLayout {
  const _CalendarCardGroupLayout({
    required this.cardWidth,
    required this.cardHeight,
    required this.offsets,
    required this.size,
  });

  final double cardWidth;
  final double cardHeight;
  final List<Offset> offsets;
  final Size size;
}
