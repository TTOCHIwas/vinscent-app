import 'dart:ui';

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

  double get canvasAspectRatio => switch (this) {
    StoryCardType.fullBleed ||
    StoryCardType.polaroid ||
    StoryCardType.fourCutGrid => 4 / 5,
    StoryCardType.fourCutStrip => 2 / 5,
  };

  int get requiredPhotoCount => switch (this) {
    StoryCardType.fullBleed || StoryCardType.polaroid => 1,
    StoryCardType.fourCutGrid || StoryCardType.fourCutStrip => 4,
  };

  bool get supportsCaption => this == StoryCardType.polaroid;

  bool get isFourCut => switch (this) {
    StoryCardType.fourCutGrid || StoryCardType.fourCutStrip => true,
    StoryCardType.fullBleed || StoryCardType.polaroid => false,
  };

  Size get previewSize => switch (this) {
    StoryCardType.fullBleed ||
    StoryCardType.polaroid ||
    StoryCardType.fourCutGrid => const Size(800, 1000),
    StoryCardType.fourCutStrip => const Size(640, 1600),
  };

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
  }) {
    return switch (type) {
      StoryCardType.fullBleed => StoryCardLayout._fullBleed(size),
      StoryCardType.polaroid => StoryCardLayout._polaroid(size),
      StoryCardType.fourCutGrid => StoryCardLayout._grid(size),
      StoryCardType.fourCutStrip => StoryCardLayout._strip(size),
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

  factory StoryCardLayout._grid(Size size) {
    final inset = size.width * 0.06;
    final gap = size.width * 0.03;
    final cellWidth = (size.width - inset * 2 - gap) / 2;
    final cellHeight = (size.height - inset * 2 - gap) / 2;

    return StoryCardLayout(
      photoRects: [
        Rect.fromLTWH(inset, inset, cellWidth, cellHeight),
        Rect.fromLTWH(inset + cellWidth + gap, inset, cellWidth, cellHeight),
        Rect.fromLTWH(inset, inset + cellHeight + gap, cellWidth, cellHeight),
        Rect.fromLTWH(
          inset + cellWidth + gap,
          inset + cellHeight + gap,
          cellWidth,
          cellHeight,
        ),
      ],
      captionRect: null,
    );
  }

  factory StoryCardLayout._strip(Size size) {
    final horizontalInset = size.width * 0.06;
    final verticalInset = size.width * 0.10;
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
