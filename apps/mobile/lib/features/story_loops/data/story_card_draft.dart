import 'dart:typed_data';

import 'story_card_scene.dart';

class StoryCardDraft {
  const StoryCardDraft({
    required this.scene,
    this.backgroundImageBytes,
    this.additionalPhotoImageBytes = const [],
    this.existingRevision,
  });

  final StoryCardScene scene;
  final Uint8List? backgroundImageBytes;
  final List<Uint8List?> additionalPhotoImageBytes;
  final int? existingRevision;

  bool get hasPhoto =>
      backgroundImageBytes != null ||
      additionalPhotoImageBytes.any((bytes) => bytes != null);

  List<Uint8List?> get photoImageBytes {
    final photos = [backgroundImageBytes, ...additionalPhotoImageBytes];
    return List.generate(
      scene.cardType.requiredPhotoCount,
      (index) => index < photos.length ? photos[index] : null,
      growable: false,
    );
  }

  int get photoCount => photoImageBytes.whereType<Uint8List>().length;

  bool get hasAllRequiredPhotos =>
      photoCount == scene.cardType.requiredPhotoCount;

  bool get canSave =>
      scene.cardType.isFourCut ? hasAllRequiredPhotos : hasContent;

  bool get hasContent => hasPhoto || scene.hasDrawing || scene.hasText;

  StoryCardDraft copyWith({
    StoryCardScene? scene,
    Uint8List? backgroundImageBytes,
    List<Uint8List?>? additionalPhotoImageBytes,
    bool clearBackgroundImage = false,
    int? existingRevision,
  }) {
    return StoryCardDraft(
      scene: scene ?? this.scene,
      backgroundImageBytes: clearBackgroundImage
          ? null
          : backgroundImageBytes ?? this.backgroundImageBytes,
      additionalPhotoImageBytes:
          additionalPhotoImageBytes ?? this.additionalPhotoImageBytes,
      existingRevision: existingRevision ?? this.existingRevision,
    );
  }

  StoryCardDraft withPhoto(int index, Uint8List? imageBytes) {
    if (index < 0 || index >= scene.cardType.requiredPhotoCount) {
      throw RangeError.index(index, photoImageBytes, 'index');
    }
    final photos = [...photoImageBytes]..[index] = imageBytes;
    return copyWith(
      backgroundImageBytes: photos.first,
      clearBackgroundImage: photos.first == null,
      additionalPhotoImageBytes: photos.skip(1).toList(growable: false),
    );
  }
}
