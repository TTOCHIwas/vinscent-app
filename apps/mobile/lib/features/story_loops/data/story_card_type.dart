import 'dart:ui';

const storyCardLegacyLayoutVersion = 1;
const storyCardCurrentLayoutVersion = 2;

int storyCardLayoutVersionFromValue(Object? value) {
  return (value as num?)?.toInt() == storyCardCurrentLayoutVersion
      ? storyCardCurrentLayoutVersion
      : storyCardLegacyLayoutVersion;
}

enum StoryCardType {
  fullBleed,
  polaroid,
  fourCutGrid,
  fourCutStrip;

  static const editorOrder = [
    StoryCardType.fullBleed,
    StoryCardType.polaroid,
    StoryCardType.fourCutGrid,
    StoryCardType.fourCutStrip,
  ];

  String get storageValue => switch (this) {
    StoryCardType.fullBleed => 'full_bleed',
    StoryCardType.polaroid => 'polaroid',
    StoryCardType.fourCutGrid => 'four_cut_grid',
    StoryCardType.fourCutStrip => 'four_cut_strip',
  };

  String get displayName => switch (this) {
    StoryCardType.fullBleed => '사진',
    StoryCardType.polaroid => '폴라로이드',
    StoryCardType.fourCutGrid => '네컷',
    StoryCardType.fourCutStrip => '세로 네컷',
  };

  double get canvasAspectRatio =>
      canvasAspectRatioFor(storyCardCurrentLayoutVersion);

  double canvasAspectRatioFor(int layoutVersion) {
    final version = storyCardLayoutVersionFromValue(layoutVersion);
    return switch (this) {
      StoryCardType.fullBleed || StoryCardType.polaroid => 4 / 5,
      StoryCardType.fourCutGrid =>
        version == storyCardCurrentLayoutVersion ? 20 / 27 : 4 / 5,
      StoryCardType.fourCutStrip =>
        version == storyCardCurrentLayoutVersion ? 8 / 21 : 2 / 5,
    };
  }

  int get requiredPhotoCount => switch (this) {
    StoryCardType.fullBleed || StoryCardType.polaroid => 1,
    StoryCardType.fourCutGrid || StoryCardType.fourCutStrip => 4,
  };

  bool get supportsCaption => this == StoryCardType.polaroid;

  bool get isFourCut => switch (this) {
    StoryCardType.fourCutGrid || StoryCardType.fourCutStrip => true,
    StoryCardType.fullBleed || StoryCardType.polaroid => false,
  };

  Size get previewSize => previewSizeFor(storyCardCurrentLayoutVersion);

  Size previewSizeFor(int layoutVersion) {
    final version = storyCardLayoutVersionFromValue(layoutVersion);
    return switch (this) {
      StoryCardType.fullBleed ||
      StoryCardType.polaroid => const Size(800, 1000),
      StoryCardType.fourCutGrid =>
        version == storyCardCurrentLayoutVersion
            ? const Size(800, 1080)
            : const Size(800, 1000),
      StoryCardType.fourCutStrip =>
        version == storyCardCurrentLayoutVersion
            ? const Size(640, 1680)
            : const Size(640, 1600),
    };
  }

  static StoryCardType fromStorageValue(String? value) {
    return StoryCardType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => StoryCardType.polaroid,
    );
  }
}

class StoryCardLayout {
  const StoryCardLayout({required this.photoRects, required this.captionRect});

  factory StoryCardLayout.fromSize({
    required StoryCardType type,
    required Size size,
    int layoutVersion = storyCardCurrentLayoutVersion,
  }) {
    return switch (type) {
      StoryCardType.fullBleed => StoryCardLayout._fullBleed(size),
      StoryCardType.polaroid => StoryCardLayout._polaroid(size),
      StoryCardType.fourCutGrid => StoryCardLayout._grid(size, layoutVersion),
      StoryCardType.fourCutStrip => StoryCardLayout._strip(size, layoutVersion),
    };
  }

  factory StoryCardLayout._fullBleed(Size size) {
    return StoryCardLayout(photoRects: [Offset.zero & size], captionRect: null);
  }

  factory StoryCardLayout._polaroid(Size size) {
    final horizontalInset = size.width * 0.06;
    final topInset = horizontalInset;
    final photoSide = size.width - horizontalInset * 2;
    final photoRect = Rect.fromLTWH(
      horizontalInset,
      topInset,
      photoSide,
      photoSide,
    );
    final captionTop = photoRect.bottom + size.width * 0.03;

    return StoryCardLayout(
      photoRects: [photoRect],
      captionRect: Rect.fromLTRB(
        horizontalInset,
        captionTop,
        size.width - horizontalInset,
        size.height - topInset,
      ),
    );
  }

  factory StoryCardLayout._grid(Size size, int layoutVersion) {
    final isCurrent =
        storyCardLayoutVersionFromValue(layoutVersion) ==
        storyCardCurrentLayoutVersion;
    final horizontalInset = size.width * 0.06;
    final verticalInset = size.width * (isCurrent ? 0.11 : 0.06);
    final gap = size.width * 0.03;
    final cellWidth = (size.width - horizontalInset * 2 - gap) / 2;
    final cellHeight = (size.height - verticalInset * 2 - gap) / 2;

    return StoryCardLayout(
      photoRects: [
        Rect.fromLTWH(horizontalInset, verticalInset, cellWidth, cellHeight),
        Rect.fromLTWH(
          horizontalInset + cellWidth + gap,
          verticalInset,
          cellWidth,
          cellHeight,
        ),
        Rect.fromLTWH(
          horizontalInset,
          verticalInset + cellHeight + gap,
          cellWidth,
          cellHeight,
        ),
        Rect.fromLTWH(
          horizontalInset + cellWidth + gap,
          verticalInset + cellHeight + gap,
          cellWidth,
          cellHeight,
        ),
      ],
      captionRect: null,
    );
  }

  factory StoryCardLayout._strip(Size size, int layoutVersion) {
    final isCurrent =
        storyCardLayoutVersionFromValue(layoutVersion) ==
        storyCardCurrentLayoutVersion;
    final horizontalInset = size.width * 0.06;
    final verticalInset = size.width * (isCurrent ? 0.1625 : 0.10);
    final gap = size.width * 0.03;
    final photoWidth = size.width - horizontalInset * 2;
    final photoHeight = (size.height - verticalInset * 2 - gap * 3) / 4;

    return StoryCardLayout(
      photoRects: List.generate(4, (index) {
        return Rect.fromLTWH(
          horizontalInset,
          verticalInset + index * (photoHeight + gap),
          photoWidth,
          photoHeight,
        );
      }),
      captionRect: null,
    );
  }

  final List<Rect> photoRects;
  final Rect? captionRect;

  double photoAspectRatio(int index) {
    final rect = photoRects[index];
    return rect.width / rect.height;
  }
}
