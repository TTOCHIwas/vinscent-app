import '../../calendar/data/couple_calendar_event.dart';
import 'home_widget_snapshot.dart';

class HomeWidgetCalendarSummaryResolver {
  const HomeWidgetCalendarSummaryResolver();

  HomeWidgetCalendarSummary? resolve({
    required List<CoupleCalendarEvent> events,
    required Iterable<String> defaultEventLabels,
  }) {
    final labels = defaultEventLabels
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    final totalCount = events.length + labels.length;
    if (totalCount == 0) {
      return null;
    }

    if (events.isNotEmpty) {
      final selectedEvent = events.firstWhere(
        _hasDownloadableArtwork,
        orElse: () => events.first,
      );
      final artworkUrl = selectedEvent.artwork?.previewUrl;
      return HomeWidgetCalendarSummary(
        title: selectedEvent.title,
        additionalCount: totalCount - 1,
        artwork: artworkUrl == null || artworkUrl.isEmpty
            ? null
            : HomeWidgetRemoteAsset(
                url: artworkUrl,
                version:
                    '${selectedEvent.id}:${selectedEvent.revision}:'
                    '${selectedEvent.updatedAt.microsecondsSinceEpoch}',
                extension: 'webp',
              ),
      );
    }

    return HomeWidgetCalendarSummary(
      title: labels.first,
      additionalCount: totalCount - 1,
    );
  }

  bool _hasDownloadableArtwork(CoupleCalendarEvent event) {
    final previewUrl = event.artwork?.previewUrl;
    return previewUrl != null && previewUrl.isNotEmpty;
  }
}
