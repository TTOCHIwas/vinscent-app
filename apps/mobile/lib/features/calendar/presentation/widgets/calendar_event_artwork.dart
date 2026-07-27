import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_sized_network_image.dart';
import '../../data/couple_calendar_event.dart';

class CalendarEventArtwork extends StatelessWidget {
  const CalendarEventArtwork({
    super.key,
    required this.event,
    required this.size,
    this.cacheLogicalSize,
    this.gaplessPlayback = false,
  });

  final CoupleCalendarEvent event;
  final double size;
  final Size? cacheLogicalSize;
  final bool gaplessPlayback;

  @override
  Widget build(BuildContext context) {
    final artwork = event.artwork;
    if (artwork == null) {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF555555),
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: (size * 0.24).clamp(3, 8)),
          ),
        ),
      );
    }

    return SizedBox.square(
      dimension: size,
      child: AppSizedNetworkImage(
        url: artwork.previewUrl,
        logicalSize: Size.square(size),
        cacheLogicalSize: cacheLogicalSize,
        gaplessPlayback: gaplessPlayback,
        fallbackBuilder: (_) => _ArtworkFallback(size: size),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.brush_outlined,
      size: size * 0.72,
      color: const Color(0xFF777777),
    );
  }
}
