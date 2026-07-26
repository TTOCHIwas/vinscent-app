import 'package:flutter/material.dart';

import '../../../../core/drawing/app_drawing.dart';
import '../../../../core/drawing/app_drawing_painter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/calendar_cell_preview_mode.dart';

class CalendarCellPreviewModeThumbnail extends StatelessWidget {
  const CalendarCellPreviewModeThumbnail({super.key, required this.mode});

  static const _surfaceColor = Color(0xFFF2F2F4);
  static const _firstCardColor = Color(0xFFDCE7E2);
  static const _secondCardColor = Color(0xFFE8E2EC);

  final CalendarCellPreviewMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('calendar-cell-preview-thumbnail-${mode.storageValue}'),
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: switch (mode) {
        CalendarCellPreviewMode.all => const _CombinedPreview(),
        CalendarCellPreviewMode.cardsOnly => const _CardsPreview(),
        CalendarCellPreviewMode.eventsOnly => const _EventsPreview(),
      },
    );
  }
}

class _CardsPreview extends StatelessWidget {
  const _CardsPreview();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        _TransformCard(
          angle: -0.14,
          offset: Offset(-8, -1),
          photoColor: CalendarCellPreviewModeThumbnail._firstCardColor,
          artworkStrokes: _PreviewDoodles.landscape,
        ),
        _TransformCard(
          angle: 0.12,
          offset: Offset(8, 2),
          photoColor: CalendarCellPreviewModeThumbnail._secondCardColor,
          artworkStrokes: _PreviewDoodles.heart,
        ),
      ],
    );
  }
}

class _EventsPreview extends StatelessWidget {
  const _EventsPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _DrawingPreview(
        key: const Key('calendar-cell-preview-smiling-doodle'),
        size: 46,
        strokes: _PreviewDoodles.smilingSun,
      ),
    );
  }
}

class _CombinedPreview extends StatelessWidget {
  const _CombinedPreview();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 5,
          top: 4,
          child: _DrawingPreview(size: 40, strokes: _PreviewDoodles.smilingSun),
        ),
        Positioned(
          right: 8,
          bottom: 7,
          child: _TransformCard(
            angle: 0.12,
            offset: Offset.zero,
            photoColor: CalendarCellPreviewModeThumbnail._firstCardColor,
            artworkStrokes: _PreviewDoodles.landscape,
          ),
        ),
      ],
    );
  }
}

class _TransformCard extends StatelessWidget {
  const _TransformCard({
    required this.angle,
    required this.offset,
    required this.photoColor,
    required this.artworkStrokes,
  });

  final double angle;
  final Offset offset;
  final Color photoColor;
  final List<AppDrawingStroke> artworkStrokes;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: _MiniStoryCard(
          photoColor: photoColor,
          artworkStrokes: artworkStrokes,
        ),
      ),
    );
  }
}

class _MiniStoryCard extends StatelessWidget {
  const _MiniStoryCard({
    required this.photoColor,
    required this.artworkStrokes,
  });

  final Color photoColor;
  final List<AppDrawingStroke> artworkStrokes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 35,
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 7),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRect(
        child: ColoredBox(
          color: photoColor,
          child: CustomPaint(
            painter: AppDrawingPainter(strokes: artworkStrokes),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _DrawingPreview extends StatelessWidget {
  const _DrawingPreview({super.key, required this.size, required this.strokes});

  final double size;
  final List<AppDrawingStroke> strokes;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: AppDrawingPainter(strokes: strokes)),
    );
  }
}

abstract final class _PreviewDoodles {
  static const _black = Color(0xFF111111);
  static const _pink = Color(0xFFE56BAA);
  static const _orange = Color(0xFFF4932F);
  static const _yellow = Color(0xFFF7D748);
  static const _green = Color(0xFF39B871);
  static const _blue = Color(0xFF3E8EDE);

  static final smilingSun = <AppDrawingStroke>[
    _stroke(
      color: _yellow,
      width: 0.065,
      points: const [
        Offset(0.50, 0.18),
        Offset(0.66, 0.20),
        Offset(0.79, 0.31),
        Offset(0.83, 0.48),
        Offset(0.78, 0.66),
        Offset(0.65, 0.79),
        Offset(0.48, 0.82),
        Offset(0.31, 0.77),
        Offset(0.20, 0.64),
        Offset(0.17, 0.47),
        Offset(0.22, 0.31),
        Offset(0.35, 0.20),
        Offset(0.50, 0.18),
      ],
    ),
    ...[
      const [Offset(0.49, 0.04), Offset(0.49, 0.12)],
      const [Offset(0.76, 0.10), Offset(0.70, 0.17)],
      const [Offset(0.91, 0.47), Offset(0.84, 0.47)],
      const [Offset(0.79, 0.85), Offset(0.72, 0.78)],
      const [Offset(0.48, 0.96), Offset(0.48, 0.87)],
      const [Offset(0.15, 0.84), Offset(0.23, 0.76)],
      const [Offset(0.04, 0.48), Offset(0.13, 0.48)],
      const [Offset(0.16, 0.12), Offset(0.24, 0.20)],
    ].map((points) => _stroke(color: _orange, width: 0.055, points: points)),
    _stroke(color: _black, width: 0.075, points: const [Offset(0.38, 0.43)]),
    _stroke(color: _black, width: 0.075, points: const [Offset(0.62, 0.43)]),
    _stroke(
      color: _black,
      width: 0.045,
      points: const [
        Offset(0.34, 0.58),
        Offset(0.42, 0.66),
        Offset(0.51, 0.68),
        Offset(0.61, 0.65),
        Offset(0.68, 0.57),
      ],
    ),
    _stroke(color: _pink, width: 0.08, points: const [Offset(0.27, 0.56)]),
    _stroke(color: _pink, width: 0.08, points: const [Offset(0.73, 0.56)]),
  ];

  static final landscape = <AppDrawingStroke>[
    _stroke(color: _yellow, width: 0.16, points: const [Offset(0.74, 0.24)]),
    _stroke(
      color: _green,
      width: 0.10,
      points: const [
        Offset(0.00, 0.78),
        Offset(0.22, 0.62),
        Offset(0.43, 0.73),
        Offset(0.67, 0.48),
        Offset(1.00, 0.70),
      ],
    ),
    _stroke(
      color: _blue,
      width: 0.055,
      points: const [
        Offset(0.05, 0.88),
        Offset(0.28, 0.84),
        Offset(0.52, 0.89),
        Offset(0.76, 0.84),
        Offset(0.98, 0.88),
      ],
    ),
  ];

  static final heart = <AppDrawingStroke>[
    _stroke(
      color: _pink,
      width: 0.09,
      points: const [
        Offset(0.50, 0.80),
        Offset(0.28, 0.59),
        Offset(0.23, 0.41),
        Offset(0.31, 0.27),
        Offset(0.43, 0.25),
        Offset(0.50, 0.38),
        Offset(0.57, 0.25),
        Offset(0.69, 0.27),
        Offset(0.77, 0.41),
        Offset(0.72, 0.59),
        Offset(0.50, 0.80),
      ],
    ),
  ];

  static AppDrawingStroke _stroke({
    required Color color,
    required double width,
    required List<Offset> points,
  }) {
    return AppDrawingStroke(
      tool: AppDrawingTool.pen,
      color: color,
      width: width,
      points: points
          .map((point) => AppDrawingPoint(x: point.dx, y: point.dy))
          .toList(growable: false),
    );
  }
}
