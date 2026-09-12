import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_sized_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/story_card_scene.dart';
import '../../data/story_card_type.dart';

class StoryCardPreviewSurface extends StatelessWidget {
  const StoryCardPreviewSurface({
    super.key,
    required this.previewUrl,
    required this.width,
    this.cardType = StoryCardType.polaroid,
    this.surfaceKey,
    this.onTap,
    this.semanticsLabel,
    this.cornerRadius = 1,
    this.showShadow = true,
  });

  final String? previewUrl;
  final double width;
  final StoryCardType cardType;
  final Key? surfaceKey;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final double cornerRadius;
  final bool showShadow;

  static double widthInFourByFiveSlot(
    double slotWidth,
    StoryCardType cardType,
  ) {
    return slotWidth *
        (cardType.canvasAspectRatio / storyCardCanvasAspectRatio);
  }

  @override
  Widget build(BuildContext context) {
    final height = width / cardType.canvasAspectRatio;
    final borderRadius = BorderRadius.circular(cornerRadius);

    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: surfaceKey,
          onTap: onTap,
          borderRadius: borderRadius,
          child: SizedBox(
            width: width,
            child: AspectRatio(
              aspectRatio: cardType.canvasAspectRatio,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: borderRadius,
                  border: Border.all(color: AppColors.wireframeBorder),
                  boxShadow: showShadow
                      ? const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: AppSizedNetworkImage(
                    url: previewUrl,
                    logicalSize: Size(width, height),
                    fallbackBuilder: (_) =>
                        const _StoryCardPreviewPlaceholder(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryCardPreviewPlaceholder extends StatelessWidget {
  const _StoryCardPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF8F8F8),
      child: Center(
        child: Icon(
          Icons.auto_awesome_mosaic_outlined,
          size: 28,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
