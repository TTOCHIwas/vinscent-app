import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../story_loops/data/story_card_scene.dart';

typedef HomeCompletedStoryCardBuilder =
    Widget Function(BuildContext context, double cardWidth);

class HomeCompletedStoryCards extends StatelessWidget {
  const HomeCompletedStoryCards({
    super.key,
    required this.leftCardBuilder,
    required this.rightCardBuilder,
  });

  static const maximumContentWidth = 360.0;
  static const maximumCardWidth = 94.0;
  static const maximumHeight = 164.0;

  static const _lineEdgeY = 10.0;
  static const _lineControlY = 36.0;
  static const _cardTopGap = 10.0;
  static const _bottomClearance = 14.0;
  static const _leftAnchor = 0.27;
  static const _rightAnchor = 0.73;
  static const _leftRotation = -0.055;
  static const _rightRotation = 0.055;

  final HomeCompletedStoryCardBuilder leftCardBuilder;
  final HomeCompletedStoryCardBuilder rightCardBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth.clamp(0.0, maximumContentWidth).toDouble()
            : maximumContentWidth;
        final leftAnchorX = contentWidth * _leftAnchor;
        final rightAnchorX = contentWidth * _rightAnchor;
        final maximumAnchorY = math.max(
          _lineY(_leftAnchor),
          _lineY(_rightAnchor),
        );
        final availableCardWidth = math.max(
          0.0,
          (contentWidth * (_rightAnchor - _leftAnchor)) - 20,
        );
        final heightBoundCardWidth = constraints.hasBoundedHeight
            ? math.max(
                    0.0,
                    constraints.maxHeight -
                        maximumAnchorY -
                        _cardTopGap -
                        _bottomClearance,
                  ) *
                  storyCardCanvasAspectRatio
            : maximumCardWidth;
        final cardWidth = math.min(
          maximumCardWidth,
          math.min(availableCardWidth, heightBoundCardWidth),
        );
        final cardHeight = cardWidth / storyCardCanvasAspectRatio;
        final contentHeight = math.min(
          maximumHeight,
          maximumAnchorY + _cardTopGap + cardHeight + _bottomClearance,
        );

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
                    key: const Key('home-completed-story-clothesline'),
                    painter: const _ClotheslinePainter(
                      edgeY: _lineEdgeY,
                      controlY: _lineControlY,
                    ),
                  ),
                ),
                _HangingStoryCard(
                  anchorX: leftAnchorX,
                  anchorY: _lineY(_leftAnchor),
                  cardWidth: cardWidth,
                  rotation: _leftRotation,
                  builder: leftCardBuilder,
                ),
                _HangingStoryCard(
                  anchorX: rightAnchorX,
                  anchorY: _lineY(_rightAnchor),
                  cardWidth: cardWidth,
                  rotation: _rightRotation,
                  builder: rightCardBuilder,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static double _lineY(double t) {
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
  final HomeCompletedStoryCardBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: anchorX - (cardWidth / 2),
      top: anchorY - 4,
      width: cardWidth,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Transform.rotate(
              angle: rotation,
              alignment: Alignment.topCenter,
              child: builder(context, cardWidth),
            ),
          ),
          Transform.rotate(angle: rotation * 0.35, child: const _Clothespin()),
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
