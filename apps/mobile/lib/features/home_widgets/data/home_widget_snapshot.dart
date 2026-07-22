class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.characterImage,
    required this.recordingAudio,
    required this.partnerCardImage,
  });

  final HomeWidgetAssetUpdate characterImage;
  final HomeWidgetAssetUpdate recordingAudio;
  final HomeWidgetAssetUpdate partnerCardImage;

  bool get requiresRetry =>
      characterImage.shouldPreserve ||
      recordingAudio.shouldPreserve ||
      partnerCardImage.shouldPreserve;
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
  static const partnerCardImagePathKey = 'widget_partner_card_image_path';
  static const partnerCardImageVersionKey = 'widget_partner_card_image_version';

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
