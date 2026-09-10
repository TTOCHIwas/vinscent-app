import 'package:flutter/foundation.dart';

import 'story_card_face_detector.dart';
import 'story_card_mediapipe_face_detector.dart';

abstract final class StoryCardFaceDetectorFactory {
  static StoryCardFaceDetector create({TargetPlatform? platform}) {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    final fallback = MlKitStoryCardFaceDetector(platform: resolvedPlatform);
    if (resolvedPlatform != TargetPlatform.android &&
        resolvedPlatform != TargetPlatform.iOS) {
      return fallback;
    }
    return MediaPipeStoryCardFaceDetector(
      fallback: fallback,
      platform: resolvedPlatform,
    );
  }
}
