import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

enum StoryCardCharacterSide { left, right }

@immutable
class StoryCardFaceObservation {
  const StoryCardFaceObservation({
    required this.normalizedBounds,
    Offset? normalizedLeftAnchor,
    Offset? normalizedRightAnchor,
    this.rollRadians = 0,
    this.characterSide,
  }) : _normalizedLeftAnchor = normalizedLeftAnchor,
       _normalizedRightAnchor = normalizedRightAnchor;

  final Rect normalizedBounds;
  final Offset? _normalizedLeftAnchor;
  final Offset? _normalizedRightAnchor;
  final double rollRadians;
  final StoryCardCharacterSide? characterSide;

  Offset get normalizedLeftAnchor =>
      _normalizedLeftAnchor ??
      Offset(normalizedBounds.left, normalizedBounds.center.dy);

  Offset get normalizedRightAnchor =>
      _normalizedRightAnchor ??
      Offset(normalizedBounds.right, normalizedBounds.center.dy);

  double get area => normalizedBounds.width * normalizedBounds.height;

  StoryCardFaceObservation mirroredHorizontally() {
    return StoryCardFaceObservation(
      normalizedBounds: Rect.fromLTRB(
        1 - normalizedBounds.right,
        normalizedBounds.top,
        1 - normalizedBounds.left,
        normalizedBounds.bottom,
      ),
      normalizedLeftAnchor: Offset(
        1 - normalizedRightAnchor.dx,
        normalizedRightAnchor.dy,
      ),
      normalizedRightAnchor: Offset(
        1 - normalizedLeftAnchor.dx,
        normalizedLeftAnchor.dy,
      ),
      rollRadians: -rollRadians,
      characterSide: switch (characterSide) {
        StoryCardCharacterSide.left => StoryCardCharacterSide.right,
        StoryCardCharacterSide.right => StoryCardCharacterSide.left,
        null => null,
      },
    );
  }

  StoryCardFaceObservation interpolateTo(
    StoryCardFaceObservation next,
    double factor,
  ) {
    return StoryCardFaceObservation(
      normalizedBounds: Rect.lerp(
        normalizedBounds,
        next.normalizedBounds,
        factor.clamp(0.0, 1.0).toDouble(),
      )!,
      normalizedLeftAnchor: Offset.lerp(
        normalizedLeftAnchor,
        next.normalizedLeftAnchor,
        factor.clamp(0.0, 1.0).toDouble(),
      ),
      normalizedRightAnchor: Offset.lerp(
        normalizedRightAnchor,
        next.normalizedRightAnchor,
        factor.clamp(0.0, 1.0).toDouble(),
      ),
      rollRadians:
          rollRadians +
          (next.rollRadians - rollRadians) * factor.clamp(0.0, 1.0).toDouble(),
      characterSide: next.characterSide ?? characterSide,
    );
  }

  StoryCardFaceObservation withCharacterSide(StoryCardCharacterSide side) {
    return StoryCardFaceObservation(
      normalizedBounds: normalizedBounds,
      normalizedLeftAnchor: normalizedLeftAnchor,
      normalizedRightAnchor: normalizedRightAnchor,
      rollRadians: rollRadians,
      characterSide: side,
    );
  }

  static StoryCardFaceObservation? primary(
    Iterable<StoryCardFaceObservation> observations,
  ) {
    StoryCardFaceObservation? result;
    for (final observation in observations) {
      if (result == null || observation.area > result.area) {
        result = observation;
      }
    }
    return result;
  }
}

@immutable
class StoryCardCharacterAsset {
  const StoryCardCharacterAsset._({
    required this.bytes,
    required this.aspectRatio,
  });

  factory StoryCardCharacterAsset.fromBytes(Uint8List sourceBytes) {
    final decoded = image.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('Unsupported character image format.');
    }
    final upright = image.bakeOrientation(decoded);
    final trimmed = image.trim(upright, mode: image.TrimMode.transparent);
    if (trimmed.width <= 0 || trimmed.height <= 0) {
      throw const FormatException('Character image is empty.');
    }
    return StoryCardCharacterAsset._(
      bytes: Uint8List.fromList(image.encodePng(trimmed)),
      aspectRatio: trimmed.width / trimmed.height,
    );
  }

  final Uint8List bytes;
  final double aspectRatio;
}

@immutable
class StoryCardCharacterComposition {
  const StoryCardCharacterComposition({
    required this.asset,
    required this.face,
  });

  final StoryCardCharacterAsset asset;
  final StoryCardFaceObservation face;
}

abstract final class StoryCardCharacterPlacement {
  static const _viewportMargin = 0.02;

  static StoryCardCharacterSide preferredSide(Rect faceBounds) {
    final leftSpace = faceBounds.left;
    final rightSpace = 1 - faceBounds.right;
    return rightSpace >= leftSpace
        ? StoryCardCharacterSide.right
        : StoryCardCharacterSide.left;
  }

  static Rect calculate({
    required StoryCardFaceObservation face,
    required double characterAspectRatio,
    required Size viewportSize,
  }) {
    if (viewportSize.isEmpty ||
        !characterAspectRatio.isFinite ||
        characterAspectRatio <= 0) {
      return Rect.zero;
    }

    final faceBounds = face.normalizedBounds;
    final targetHeight = (faceBounds.height * 0.68)
        .clamp(0.10, 0.24)
        .toDouble();
    final viewportAspectRatio = viewportSize.width / viewportSize.height;
    final targetWidth =
        (targetHeight * characterAspectRatio / viewportAspectRatio)
            .clamp(0.08, 0.38)
            .toDouble();
    final maximumLeft = 1 - _viewportMargin - targetWidth;
    final left = (faceBounds.center.dx - targetWidth / 2)
        .clamp(_viewportMargin, maximumLeft)
        .toDouble();
    final top = faceBounds.top - targetHeight;
    if (top < _viewportMargin) {
      return Rect.zero;
    }

    return Rect.fromLTWH(left, top, targetWidth, targetHeight);
  }
}

class StoryCardCharacterCompositor {
  const StoryCardCharacterCompositor();

  image.Image composite({
    required image.Image background,
    required Uint8List characterBytes,
    required Rect normalizedPlacement,
  }) {
    final character = image.decodeImage(characterBytes);
    if (character == null) {
      throw const FormatException('Unsupported character image format.');
    }

    final result = image.Image.from(background);
    final left = (normalizedPlacement.left * result.width).round();
    final top = (normalizedPlacement.top * result.height).round();
    final width = (normalizedPlacement.width * result.width).round();
    final height = (normalizedPlacement.height * result.height).round();
    if (width <= 0 || height <= 0) {
      return result;
    }

    image.compositeImage(
      result,
      character,
      dstX: left,
      dstY: top,
      dstW: width,
      dstH: height,
    );
    return result;
  }
}
