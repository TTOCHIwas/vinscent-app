import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/story_card_scene.dart';

typedef StoryCardSlotBuilder =
    Widget Function(BuildContext context, double cardWidth);

class StoryCardPairLayout extends StatelessWidget {
  const StoryCardPairLayout({
    super.key,
    this.leftCardBuilder,
    this.rightCardBuilder,
  });

  static const maximumContentWidth = 360.0;
  static const slotGap = 16.0;
  static const maximumCardWidth = (maximumContentWidth - slotGap) / 2;
  static const maximumCardHeight =
      maximumCardWidth / storyCardCanvasAspectRatio;

  final StoryCardSlotBuilder? leftCardBuilder;
  final StoryCardSlotBuilder? rightCardBuilder;

  @override
  Widget build(BuildContext context) {
    if (leftCardBuilder == null && rightCardBuilder == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth.clamp(0.0, maximumContentWidth).toDouble()
            : maximumContentWidth;
        final availableCardWidth = math.max(0.0, (contentWidth - slotGap) / 2);
        final heightBoundCardWidth = constraints.hasBoundedHeight
            ? math.max(0.0, constraints.maxHeight) * storyCardCanvasAspectRatio
            : maximumCardWidth;
        final cardWidth = math.min(
          maximumCardWidth,
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
                _StoryCardSlot(
                  width: cardWidth,
                  height: cardHeight,
                  builder: leftCardBuilder,
                ),
                _StoryCardSlot(
                  width: cardWidth,
                  height: cardHeight,
                  builder: rightCardBuilder,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StoryCardSlot extends StatelessWidget {
  const _StoryCardSlot({
    required this.width,
    required this.height,
    required this.builder,
  });

  final double width;
  final double height;
  final StoryCardSlotBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final builder = this.builder;
    return SizedBox(
      width: width,
      height: height,
      child: builder == null ? null : Center(child: builder(context, width)),
    );
  }
}
