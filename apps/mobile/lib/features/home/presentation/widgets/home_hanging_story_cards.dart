import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../story_loops/data/story_card_scene.dart';

typedef HomeHangingStoryCardBuilder =
    Widget Function(BuildContext context, double cardWidth);

enum HomeHangingStoryCardSize { standard, compact }

class HomeHangingStoryCards extends StatelessWidget {
  const HomeHangingStoryCards({
    super.key,
    required this.size,
    this.leftCardBuilder,
    this.rightCardBuilder,
  });

  static const maximumContentWidth = 360.0;
  static const slotGap = 16.0;
  static const maximumStandardCardWidth = (maximumContentWidth - slotGap) / 2;
  static const maximumCompactCardWidth = 80.0;
  static const maximumStandardHeight =
      _cardTop + (maximumStandardCardWidth / storyCardCanvasAspectRatio);
  static const maximumCompactHeight = 148.0;

  static const _lineEdgeY = 10.0;
  static const _lineControlY = 36.0;
  static const _cardTop = 36.0;
  static const _compactBottomClearance = 12.0;
  static const _leftRotation = -0.055;
  static const _rightRotation = 0.055;

  final HomeHangingStoryCardSize size;
  final HomeHangingStoryCardBuilder? leftCardBuilder;
  final HomeHangingStoryCardBuilder? rightCardBuilder;

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
        final slotWidth = math.max(0.0, (contentWidth - slotGap) / 2);
        final leftAnchorX = slotWidth / 2;
        final rightAnchorX = contentWidth - (slotWidth / 2);
        final maximumCardWidth = switch (size) {
          HomeHangingStoryCardSize.standard => maximumStandardCardWidth,
          HomeHangingStoryCardSize.compact => maximumCompactCardWidth,
        };
        final bottomClearance = switch (size) {
          HomeHangingStoryCardSize.standard => 0.0,
          HomeHangingStoryCardSize.compact => _compactBottomClearance,
        };
        final heightBoundCardWidth = constraints.hasBoundedHeight
            ? math.max(
                    0.0,
                    constraints.maxHeight - _cardTop - bottomClearance,
                  ) *
                  storyCardCanvasAspectRatio
            : maximumCardWidth;
        final cardWidth = math.min(
          maximumCardWidth,
          math.min(slotWidth, heightBoundCardWidth),
        );
        final cardHeight = cardWidth / storyCardCanvasAspectRatio;
        final preferredHeight = _cardTop + cardHeight + bottomClearance;
        final maximumHeight = switch (size) {
          HomeHangingStoryCardSize.standard => maximumStandardHeight,
          HomeHangingStoryCardSize.compact => maximumCompactHeight,
        };
        final contentHeight = constraints.hasBoundedHeight
            ? math.min(preferredHeight, constraints.maxHeight)
            : math.min(preferredHeight, maximumHeight);
        final leftRotation = size == HomeHangingStoryCardSize.compact
            ? _leftRotation
            : 0.0;
        final rightRotation = size == HomeHangingStoryCardSize.compact
            ? _rightRotation
            : 0.0;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            height: contentHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    key: const Key('home-story-clothesline'),
                    painter: const _ClotheslinePainter(
                      edgeY: _lineEdgeY,
                      controlY: _lineControlY,
                    ),
                  ),
                ),
                if (leftCardBuilder case final builder?)
                  _HangingStoryCard(
                    anchorX: leftAnchorX,
                    anchorY: _lineY(leftAnchorX, contentWidth),
                    cardWidth: cardWidth,
                    rotation: leftRotation,
                    builder: builder,
                  ),
                if (rightCardBuilder case final builder?)
                  _HangingStoryCard(
                    anchorX: rightAnchorX,
                    anchorY: _lineY(rightAnchorX, contentWidth),
                    cardWidth: cardWidth,
                    rotation: rightRotation,
                    builder: builder,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static double _lineY(double x, double width) {
    if (width <= 0) {
      return _lineEdgeY;
    }

    final t = x / width;
    final inverseT = 1 - t;
    return (inverseT * inverseT * _lineEdgeY) +
        (2 * inverseT * t * _lineControlY) +
        (t * t * _lineEdgeY);
  }
}

class _HangingStoryCard extends StatelessWidget {
  const _HangingStoryCard({
    required this.anchorX,
    required this.anchorY,
    required this.cardWidth,
    required this.rotation,
    required this.builder,
  });

  final double anchorX;
  final double anchorY;
  final double cardWidth;
  final double rotation;
  final HomeHangingStoryCardBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: anchorX - (cardWidth / 2),
      top: 0,
      width: cardWidth,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: HomeHangingStoryCards._cardTop),
            child: Transform.rotate(
              angle: rotation,
              alignment: Alignment.topCenter,
              child: builder(context, cardWidth),
            ),
          ),
          Positioned(
            top: anchorY - 4,
            child: Transform.rotate(
              angle: rotation * 0.35,
              child: const _Clothespin(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Clothespin extends StatelessWidget {
  const _Clothespin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 25,
      decoration: BoxDecoration(
        color: const Color(0xFFD0AF7A),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF9D7B4D), width: 0.7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: 5,
          child: Divider(height: 1, thickness: 0.7, color: Color(0xFF9D7B4D)),
        ),
      ),
    );
  }
}

class _ClotheslinePainter extends CustomPainter {
  const _ClotheslinePainter({required this.edgeY, required this.controlY});

  final double edgeY;
  final double controlY;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, edgeY)
      ..quadraticBezierTo(size.width / 2, controlY, size.width, edgeY);
    final paint = Paint()
      ..color = const Color(0xFFAD8A5F)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ClotheslinePainter oldDelegate) {
    return edgeY != oldDelegate.edgeY || controlY != oldDelegate.controlY;
  }
}
