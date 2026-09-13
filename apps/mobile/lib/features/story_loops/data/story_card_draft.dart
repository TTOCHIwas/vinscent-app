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

  bool get hasPhoto => photoImageBytes.any((bytes) => bytes != null);

  bool get hasStoredPhoto =>
      storedPhotoImageBytes.any((bytes) => bytes != null);

  List<Uint8List?> get photoImageBytes {
    final photos = storedPhotoImageBytes;
    return List.generate(
      scene.cardType.requiredPhotoCount,
      (index) => index < photos.length ? photos[index] : null,
      growable: false,
    );
  }

  List<Uint8List?> get storedPhotoImageBytes => [
    backgroundImageBytes,
    ...additionalPhotoImageBytes,
  ];

  int get photoCount => photoImageBytes.whereType<Uint8List>().length;

  bool get hasAllRequiredPhotos =>
      photoCount == scene.cardType.requiredPhotoCount;

  bool get canSave =>
      scene.cardType.isFourCut ? hasAllRequiredPhotos : hasContent;

  bool get hasContent => hasPhoto || scene.hasDrawing || scene.hasText;

  bool get hasDraftContent =>
      hasStoredPhoto || scene.hasDrawing || scene.hasText;

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
    final photos = [...storedPhotoImageBytes];
    while (photos.length <= index) {
      photos.add(null);
    }
    photos[index] = imageBytes;
    return copyWith(
      backgroundImageBytes: photos.first,
      clearBackgroundImage: photos.first == null,
      additionalPhotoImageBytes: photos.skip(1).toList(growable: false),
    );
  }

  StoryCardDraft reorderPhotos(int fromIndex, int toIndex) {
    final activePhotos = photoImageBytes;
    if (fromIndex < 0 ||
        fromIndex >= activePhotos.length ||
        toIndex < 0 ||
        toIndex >= activePhotos.length) {
      throw RangeError('Photo reorder index is outside the active card.');
    }
    final storedPhotos = [...storedPhotoImageBytes];
    while (storedPhotos.length < activePhotos.length) {
      storedPhotos.add(null);
    }
    final fromPhoto = storedPhotos[fromIndex];
    storedPhotos[fromIndex] = storedPhotos[toIndex];
    storedPhotos[toIndex] = fromPhoto;
    return copyWith(
      backgroundImageBytes: storedPhotos.first,
      clearBackgroundImage: storedPhotos.first == null,
      additionalPhotoImageBytes: storedPhotos.skip(1).toList(growable: false),
    );
  }
}
