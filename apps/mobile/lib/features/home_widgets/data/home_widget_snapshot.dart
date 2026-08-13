class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.characterImage,
    required this.recordingAudio,
    required this.partnerCardImage,
    this.calendarSummary = const HomeWidgetCalendarSummaryUpdate.remove(),
  });

  final HomeWidgetAssetUpdate characterImage;
  final HomeWidgetAssetUpdate recordingAudio;
  final HomeWidgetAssetUpdate partnerCardImage;
  final HomeWidgetCalendarSummaryUpdate calendarSummary;

  bool get requiresRetry =>
      characterImage.shouldPreserve ||
      recordingAudio.shouldPreserve ||
      partnerCardImage.shouldPreserve ||
      calendarSummary.shouldPreserve;
}

enum HomeWidgetAssetUpdateType { replace, remove, preserve }

class HomeWidgetAssetUpdate {
  const HomeWidgetAssetUpdate.replace(this.asset)
    : type = HomeWidgetAssetUpdateType.replace,
      assert(asset != null);

  const HomeWidgetAssetUpdate.remove()
    : type = HomeWidgetAssetUpdateType.remove,
      asset = null;

  const HomeWidgetAssetUpdate.preserve()
    : type = HomeWidgetAssetUpdateType.preserve,
      asset = null;

  final HomeWidgetAssetUpdateType type;
  final HomeWidgetRemoteAsset? asset;

  bool get shouldPreserve => type == HomeWidgetAssetUpdateType.preserve;
}

class HomeWidgetRemoteAsset {
  const HomeWidgetRemoteAsset({
    required this.url,
    required this.version,
    required this.extension,
    this.maxBytes = 5 * 1024 * 1024,
  });

  final String url;
  final String version;
  final String extension;
  final int maxBytes;
}

class HomeWidgetRecordingRemoteAsset extends HomeWidgetRemoteAsset {
  const HomeWidgetRecordingRemoteAsset({
    required super.url,
    required this.coupleId,
    required this.recordingId,
    required this.revision,
    super.maxBytes = 4 * 1024 * 1024,
  }) : super(version: '$recordingId:$revision', extension: 'm4a');

  final String coupleId;
  final String recordingId;
  final int revision;
}

enum HomeWidgetCalendarSummaryUpdateType { replace, remove, preserve }

class HomeWidgetCalendarSummaryUpdate {
  const HomeWidgetCalendarSummaryUpdate.replace(this.summary)
    : type = HomeWidgetCalendarSummaryUpdateType.replace,
      assert(summary != null);

  const HomeWidgetCalendarSummaryUpdate.remove()
    : type = HomeWidgetCalendarSummaryUpdateType.remove,
      summary = null;

  const HomeWidgetCalendarSummaryUpdate.preserve()
    : type = HomeWidgetCalendarSummaryUpdateType.preserve,
      summary = null;

  final HomeWidgetCalendarSummaryUpdateType type;
  final HomeWidgetCalendarSummary? summary;

  bool get shouldPreserve =>
      type == HomeWidgetCalendarSummaryUpdateType.preserve;
}

class HomeWidgetCalendarSummary {
  const HomeWidgetCalendarSummary({
    required this.title,
    required this.additionalCount,
    this.artwork,
  }) : assert(title != ''),
       assert(additionalCount >= 0);

  final String title;
  final int additionalCount;
  final HomeWidgetRemoteAsset? artwork;
}

class HomeWidgetTarget {
  const HomeWidgetTarget({
    required this.qualifiedAndroidName,
    required this.iOSName,
  });

  final String qualifiedAndroidName;
  final String iOSName;
}

class HomeWidgetStorage {
  const HomeWidgetStorage._();

  static const appGroupId = 'group.com.vinscent.vinscent';

  static const characterImagePathKey = 'widget_character_image_path';
  static const characterImageVersionKey = 'widget_character_image_version';
  static const recordingAudioPathKey = 'widget_recording_audio_path';
  static const recordingAudioVersionKey = 'widget_recording_audio_version';
  static const recordingCacheManifestKey = 'widget_recording_cache_manifest';
  static const partnerCardImagePathKey = 'widget_partner_card_image_path';
  static const partnerCardImageVersionKey = 'widget_partner_card_image_version';
  static const calendarEventArtworkPathKey =
      'widget_calendar_event_artwork_path';
  static const calendarEventArtworkVersionKey =
      'widget_calendar_event_artwork_version';
  static const calendarEventTitleKey = 'widget_calendar_event_title';
  static const calendarEventAdditionalCountKey =
      'widget_calendar_event_additional_count';

  static const characterAndroidProvider =
      'com.vinscent.vinscent.widgets.CharacterWidgetProvider';
  static const cardAndroidProvider =
      'com.vinscent.vinscent.widgets.CardWidgetProvider';
  static const characterIOSKind = 'VinscentCharacterWidget';
  static const cardIOSKind = 'VinscentCardWidget';

  static const characterTarget = HomeWidgetTarget(
    qualifiedAndroidName: characterAndroidProvider,
    iOSName: characterIOSKind,
  );
  static const cardTarget = HomeWidgetTarget(
    qualifiedAndroidName: cardAndroidProvider,
    iOSName: cardIOSKind,
  );
}
