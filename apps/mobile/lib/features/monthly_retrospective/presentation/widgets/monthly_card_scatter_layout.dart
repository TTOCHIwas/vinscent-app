import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../story_loops/presentation/widgets/story_card_preview_surface.dart';

class MonthlyScatterPlacement {
  const MonthlyScatterPlacement({required this.rect, required this.angle});

  final Rect rect;
  final double angle;

  Rect get paintedBounds {
    var bounds = _rotateBounds(rect);
    for (final shadow in StoryCardPreviewSurface.shadows) {
      // 블러의 3σ 범위를 확보해 회전된 그림자도 배치 영역 안에 둔다.
      final shadowRect = rect
          .shift(shadow.offset)
          .inflate(shadow.spreadRadius + shadow.blurSigma * 3);
      bounds = bounds.expandToInclude(_rotateBounds(shadowRect));
    }
    return bounds;
  }

  Rect _rotateBounds(Rect bounds) {
    final cosine = math.cos(angle);
    final sine = math.sin(angle);
    final center = rect.center;
    final shadowCenter = bounds.center - center;
    final rotatedCenter =
        center +
        Offset(
          shadowCenter.dx * cosine - shadowCenter.dy * sine,
          shadowCenter.dx * sine + shadowCenter.dy * cosine,
        );
    return Rect.fromCenter(
      center: rotatedCenter,
      width: bounds.width * cosine.abs() + bounds.height * sine.abs(),
      height: bounds.width * sine.abs() + bounds.height * cosine.abs(),
    );
  }
}

class MonthlyCardScatterLayout {
  const MonthlyCardScatterLayout({
    required this.size,
    required this.placements,
  });

  final Size size;
  final List<MonthlyScatterPlacement> placements;

  factory MonthlyCardScatterLayout.compact({
    required double width,
    required List<double> aspectRatios,
  }) {
    if (aspectRatios.isEmpty) {
      return const MonthlyCardScatterLayout(size: Size.zero, placements: []);
    }
    final columns = math.min(3, aspectRatios.length);
    final rows = (aspectRatios.length / columns).ceil();
    final height =
        width *
        switch (rows) {
          1 => 0.64,
          2 => 0.82,
          _ => 0.96,
        };
    const angles = [-0.16, 0.12, -0.06, 0.09, -0.12, 0.17, -0.08, 0.06];
    const offsets = [-0.02, 0.025, -0.015, 0.025, -0.025, 0.02, -0.015, 0.01];
    final placements = <MonthlyScatterPlacement>[];
    Rect? bounds;
    for (var index = 0; index < aspectRatios.length; index++) {
      final row = index ~/ columns;
      final column = index % columns;
      final rowCards = math.min(columns, aspectRatios.length - row * columns);
      final x =
          (rowCards == 1 ? 0.5 : 0.26 + column * 0.48 / (rowCards - 1)) +
          offsets[index % offsets.length];
      final y =
          (rows == 1 ? 0.5 : 0.29 + row * 0.42 / (rows - 1)) +
          offsets[(index + 3) % offsets.length];
      final cardWidth = math.min(
        width * 0.5 * aspectRatios[index],
        width * 0.62,
      );
      final cardHeight = cardWidth / aspectRatios[index];
      final placement = MonthlyScatterPlacement(
        rect: Rect.fromLTWH(
          width * x - cardWidth / 2,
          height * y - cardHeight / 2 + (index.isEven ? -3 : 3),
          cardWidth,
          cardHeight,
        ),
        angle: angles[index % angles.length],
      );
      placements.add(placement);
      bounds =
          bounds?.expandToInclude(placement.paintedBounds) ??
          placement.paintedBounds;
    }
    final paintedBounds = bounds!;
    return MonthlyCardScatterLayout(
      size: paintedBounds.size,
      placements: [
        for (final placement in placements)
          MonthlyScatterPlacement(
            rect: placement.rect.shift(-paintedBounds.topLeft),
            angle: placement.angle,
          ),
      ],
    );
  }
}
