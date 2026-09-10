import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_face_effect.dart';
import 'package:vinscent/features/story_loops/application/story_card_face_tracking_policy.dart';

void main() {
  test('새 얼굴 위치를 완만하게 보간한다', () {
    final policy = StoryCardFaceTrackingPolicy(smoothingFactor: 0.5);
    const first = StoryCardFaceObservation(
      normalizedBounds: Rect.fromLTWH(0.1, 0.2, 0.2, 0.2),
    );
    const moved = StoryCardFaceObservation(
      normalizedBounds: Rect.fromLTWH(0.3, 0.4, 0.2, 0.2),
    );

    expect(policy.update(first)?.normalizedBounds, first.normalizedBounds);
    final smoothed = policy.update(moved);

    expect(smoothed?.normalizedBounds.left, closeTo(0.2, 0.0001));
    expect(smoothed?.normalizedBounds.top, closeTo(0.3, 0.0001));
  });

  test('짧은 감지 누락에는 이전 위치를 유지한 뒤 제거한다', () {
    final policy = StoryCardFaceTrackingPolicy(maxConsecutiveMisses: 2);
    const face = StoryCardFaceObservation(
      normalizedBounds: Rect.fromLTWH(0.2, 0.2, 0.2, 0.2),
    );

    policy.update(face);

    expect(policy.update(null), isNotNull);
    expect(policy.update(null), isNotNull);
    expect(policy.update(null), isNull);
  });

  test('얼굴을 추적하는 동안 캐릭터 부착 방향을 유지한다', () {
    final policy = StoryCardFaceTrackingPolicy(smoothingFactor: 1);
    const leftFace = StoryCardFaceObservation(
      normalizedBounds: Rect.fromLTWH(0.12, 0.2, 0.2, 0.24),
    );
    const rightFace = StoryCardFaceObservation(
      normalizedBounds: Rect.fromLTWH(0.72, 0.2, 0.2, 0.24),
    );

    final first = policy.update(leftFace);
    final moved = policy.update(rightFace);

    expect(first?.characterSide, StoryCardCharacterSide.right);
    expect(moved?.characterSide, StoryCardCharacterSide.right);
  });

  test('얼굴을 완전히 놓친 뒤에는 부착 방향을 다시 선택한다', () {
    final policy = StoryCardFaceTrackingPolicy(
      smoothingFactor: 1,
      maxConsecutiveMisses: 0,
    );
    const leftFace = StoryCardFaceObservation(
      normalizedBounds: Rect.fromLTWH(0.12, 0.2, 0.2, 0.24),
    );
    const rightFace = StoryCardFaceObservation(
      normalizedBounds: Rect.fromLTWH(0.72, 0.2, 0.2, 0.24),
    );

    expect(
      policy.update(leftFace)?.characterSide,
      StoryCardCharacterSide.right,
    );
    expect(policy.update(null), isNull);
    expect(
      policy.update(rightFace)?.characterSide,
      StoryCardCharacterSide.left,
    );
  });
}
