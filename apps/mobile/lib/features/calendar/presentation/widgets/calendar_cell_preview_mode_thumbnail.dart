import 'package:flutter/material.dart';

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
      children: const [
        _TransformCard(
          angle: -0.14,
          offset: Offset(-8, -1),
          photoColor: CalendarCellPreviewModeThumbnail._firstCardColor,
        ),
        _TransformCard(
          angle: 0.12,
          offset: Offset(8, 2),
          photoColor: CalendarCellPreviewModeThumbnail._secondCardColor,
        ),
      ],
    );
  }
}

class _EventsPreview extends StatelessWidget {
  const _EventsPreview();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.sentiment_satisfied_outlined,
        size: 36,
        color: AppColors.textPrimary,
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
      children: const [
        Positioned(
          left: 9,
          top: 9,
          child: Icon(
            Icons.sentiment_satisfied_outlined,
            size: 32,
            color: AppColors.textPrimary,
          ),
        ),
        Positioned(
          right: 8,
          bottom: 7,
          child: _TransformCard(
            angle: 0.12,
            offset: Offset.zero,
            photoColor: CalendarCellPreviewModeThumbnail._firstCardColor,
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
  });

  final double angle;
  final Offset offset;
  final Color photoColor;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: _MiniStoryCard(photoColor: photoColor),
      ),
    );
  }
}

class _MiniStoryCard extends StatelessWidget {
  const _MiniStoryCard({required this.photoColor});

  final Color photoColor;

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
      child: ColoredBox(color: photoColor),
    );
  }
}
