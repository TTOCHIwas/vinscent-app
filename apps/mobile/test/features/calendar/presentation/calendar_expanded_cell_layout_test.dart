import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/presentation/calendar_expanded_cell_layout.dart';

void main() {
  test('scales every expanded visual dimension with the cell', () {
    final compact = CalendarExpandedCellLayout.resolve(
      size: const Size(40, 88),
      cardCount: 2,
      artworkCount: 3,
    );
    final large = CalendarExpandedCellLayout.resolve(
      size: const Size(80, 176),
      cardCount: 2,
      artworkCount: 3,
    );

    expect(large.cardWidth, closeTo(compact.cardWidth * 2, 0.001));
    expect(large.cardHeight, closeTo(compact.cardHeight * 2, 0.001));
    expect(large.cardOrigin.dx, closeTo(compact.cardOrigin.dx * 2, 0.001));
    expect(large.cardOrigin.dy, closeTo(compact.cardOrigin.dy * 2, 0.001));
    expect(
      large.cardOffsets.last.dx,
      closeTo(compact.cardOffsets.last.dx * 2, 0.001),
    );
    expect(large.artworkSize, closeTo(compact.artworkSize * 2, 0.001));
    expect(
      large.artworkOrigin.dx,
      closeTo(compact.artworkOrigin.dx * 2, 0.001),
    );
    expect(
      large.artworkOffsets.last.dx,
      closeTo(compact.artworkOffsets.last.dx * 2, 0.001),
    );
  });

  test('keeps expanded card and artwork groups inside the cell', () {
    const size = Size(96, 180);
    for (final layout in [
      CalendarExpandedCellLayout.resolve(
        size: size,
        cardCount: 2,
        artworkCount: 0,
      ),
      CalendarExpandedCellLayout.resolve(
        size: size,
        cardCount: 0,
        artworkCount: 3,
      ),
      CalendarExpandedCellLayout.resolve(
        size: size,
        cardCount: 2,
        artworkCount: 3,
      ),
    ]) {
      expect(layout.cardGroupRect.left, greaterThanOrEqualTo(-0.001));
      expect(layout.cardGroupRect.top, greaterThanOrEqualTo(-0.001));
      expect(layout.cardGroupRect.right, lessThanOrEqualTo(size.width + 0.001));
      expect(
        layout.cardGroupRect.bottom,
        lessThanOrEqualTo(size.height + 0.001),
      );
      expect(layout.artworkGroupRect.left, greaterThanOrEqualTo(-0.001));
      expect(layout.artworkGroupRect.top, greaterThanOrEqualTo(-0.001));
      expect(
        layout.artworkGroupRect.right,
        lessThanOrEqualTo(size.width + 0.001),
      );
      expect(
        layout.artworkGroupRect.bottom,
        lessThanOrEqualTo(size.height + 0.001),
      );
    }
  });

  test('separates mixed artwork and spread card groups', () {
    final layout = CalendarExpandedCellLayout.resolve(
      size: const Size(96, 180),
      cardCount: 2,
      artworkCount: 3,
    );

    expect(layout.visibleArtworkCount, 2);
    expect(layout.artworkGroupRect.bottom, lessThan(layout.cardGroupRect.top));
    expect(
      layout.cardGroupRect.top - layout.artworkGroupRect.bottom,
      closeTo(96 * 0.06, 0.001),
    );
    expect(layout.artworkOffsets.last.dx, closeTo(layout.artworkSize, 0.001));
    expect(layout.artworkOffsets.last.dy, 0);
    expect(layout.cardOffsets.last.dx, greaterThan(0));
    expect(layout.cardOffsets.last.dy, greaterThan(0));
    expect(layout.artworkGroupRect.top, 0);
  });

  test('prioritizes two-card size over artwork in a mixed cell', () {
    final layout = CalendarExpandedCellLayout.resolve(
      size: const Size(96, 180),
      cardCount: 2,
      artworkCount: 1,
    );

    expect(layout.cardWidth, greaterThan(layout.artworkSize));
    expect(
      layout.cardGroupSize.height,
      greaterThan(layout.artworkGroupSize.height),
    );
    expect(layout.cardGroupRect.bottom, closeTo(180, 0.001));
  });

  test('keeps mixed content top-aligned regardless of card count', () {
    const size = Size(96, 180);
    final singleCard = CalendarExpandedCellLayout.resolve(
      size: size,
      cardCount: 1,
      artworkCount: 2,
    );
    final twoCards = CalendarExpandedCellLayout.resolve(
      size: size,
      cardCount: 2,
      artworkCount: 2,
    );

    expect(singleCard.artworkOrigin.dy, 0);
    expect(twoCards.artworkOrigin.dy, singleCard.artworkOrigin.dy);
    expect(
      singleCard.cardGroupRect.top - singleCard.artworkGroupRect.bottom,
      closeTo(size.width * 0.06, 0.001),
    );
    expect(
      twoCards.cardGroupRect.top - twoCards.artworkGroupRect.bottom,
      closeTo(size.width * 0.06, 0.001),
    );
    expect(
      twoCards.cardGroupRect.bottom,
      greaterThan(singleCard.cardGroupRect.bottom),
    );
    expect(twoCards.cardGroupRect.bottom, closeTo(size.height, 0.001));
  });

  test('uses the full cell without overlapping three artwork-only events', () {
    const size = Size(96, 180);
    final layout = CalendarExpandedCellLayout.resolve(
      size: size,
      cardCount: 0,
      artworkCount: 4,
    );

    expect(layout.visibleArtworkCount, 3);
    expect(layout.artworkOffsets[0].dy, lessThan(layout.artworkOffsets[1].dy));
    expect(layout.artworkOffsets[1].dy, lessThan(layout.artworkOffsets[2].dy));
    expect(
      layout.artworkOffsets[0].dx,
      greaterThan(layout.artworkOffsets[1].dx),
    );
    expect(
      layout.artworkOffsets[2].dx,
      greaterThan(layout.artworkOffsets[1].dx),
    );
    expect(layout.artworkGroupSize.width, greaterThan(size.width * 0.95));
    expect(layout.artworkGroupSize.height, greaterThan(size.height * 0.95));
    for (var index = 1; index < layout.visibleArtworkCount; index++) {
      final previousRect =
          (layout.artworkOrigin + layout.artworkOffsets[index - 1]) &
          Size.square(layout.artworkSize);
      final currentRect =
          (layout.artworkOrigin + layout.artworkOffsets[index]) &
          Size.square(layout.artworkSize);
      expect(previousRect.overlaps(currentRect), isFalse);
      expect(previousRect.bottom, closeTo(currentRect.top, 0.001));
    }
  });

  test('places two artwork-only events edge to edge', () {
    final layout = CalendarExpandedCellLayout.resolve(
      size: const Size(96, 180),
      cardCount: 0,
      artworkCount: 2,
    );
    final firstRect =
        (layout.artworkOrigin + layout.artworkOffsets.first) &
        Size.square(layout.artworkSize);
    final secondRect =
        (layout.artworkOrigin + layout.artworkOffsets.last) &
        Size.square(layout.artworkSize);

    expect(firstRect.overlaps(secondRect), isFalse);
    expect(firstRect.bottom, closeTo(secondRect.top, 0.001));
  });

  test('expands a height-limited card pair across available width', () {
    const size = Size(96, 180);
    final cardOnly = CalendarExpandedCellLayout.resolve(
      size: size,
      cardCount: 2,
      artworkCount: 0,
    );
    final mixed = CalendarExpandedCellLayout.resolve(
      size: size,
      cardCount: 2,
      artworkCount: 1,
    );

    expect(cardOnly.cardOffsets.last.dy, greaterThan(0));
    expect(mixed.cardOffsets.last.dy, greaterThan(0));
    expect(
      mixed.cardOffsets.last.dx / mixed.cardWidth,
      greaterThan(cardOnly.cardOffsets.last.dx / cardOnly.cardWidth),
    );
    expect(
      mixed.cardOffsets.last.dy / mixed.cardHeight,
      closeTo(cardOnly.cardOffsets.last.dy / cardOnly.cardHeight, 0.001),
    );
    expect(mixed.cardOffsets.last.dx, greaterThan(mixed.cardWidth * 0.3));
    expect(mixed.cardGroupSize.width, greaterThan(size.width * 0.9));
    expect(mixed.cardGroupRect.bottom, closeTo(size.height, 0.001));
  });
}
