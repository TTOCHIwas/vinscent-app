class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.characterImage,
    required this.recordingAudio,
    required this.partnerCardImage,
  });

  final HomeWidgetRemoteAsset? characterImage;
  final HomeWidgetRemoteAsset? recordingAudio;
  final HomeWidgetRemoteAsset? partnerCardImage;
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

class HomeWidgetStorage {
  const HomeWidgetStorage._();

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
}
