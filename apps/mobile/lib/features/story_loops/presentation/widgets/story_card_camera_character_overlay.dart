import 'package:flutter/material.dart';

import '../../application/story_card_face_effect.dart';

class StoryCardCameraCharacterOverlay extends StatelessWidget {
  const StoryCardCameraCharacterOverlay({
    super.key,
    required this.face,
    required this.character,
  });

  final StoryCardFaceObservation face;
  final StoryCardCharacterAsset character;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = constraints.biggest;
        final placement = StoryCardCharacterPlacement.calculate(
          face: face,
          characterAspectRatio: character.aspectRatio,
          viewportSize: viewportSize,
        );
        if (placement.isEmpty) {
          return const SizedBox.shrink();
        }

        return TweenAnimationBuilder<Rect?>(
          tween: RectTween(begin: placement, end: placement),
          duration: const Duration(milliseconds: 60),
          curve: Curves.linear,
          builder: (context, animatedPlacement, child) {
            final resolvedPlacement = animatedPlacement ?? placement;
            return Stack(
              children: [
                Positioned(
                  key: const ValueKey('story-card-camera-character-effect'),
                  left: resolvedPlacement.left * viewportSize.width,
                  top: resolvedPlacement.top * viewportSize.height,
                  width: resolvedPlacement.width * viewportSize.width,
                  height: resolvedPlacement.height * viewportSize.height,
                  child: child!,
                ),
              ],
            );
          },
          child: Image.memory(
            character.bytes,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}
