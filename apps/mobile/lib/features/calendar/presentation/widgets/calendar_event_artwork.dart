import 'package:flutter/material.dart';

import '../../data/couple_calendar_event.dart';

class CalendarEventArtwork extends StatelessWidget {
  const CalendarEventArtwork({
    super.key,
    required this.event,
    required this.size,
  });

  final CoupleCalendarEvent event;
  final double size;

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

    final previewUrl = artwork.previewUrl;
    final previewUri = previewUrl == null ? null : Uri.tryParse(previewUrl);
    final canLoadPreview =
        previewUri != null &&
        previewUri.hasScheme &&
        (previewUri.scheme == 'http' || previewUri.scheme == 'https');

    return SizedBox.square(
      dimension: size,
      child: canLoadPreview
          ? Image.network(
              previewUrl!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _ArtworkFallback(size: size);
              },
            )
          : _ArtworkFallback(size: size),
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
