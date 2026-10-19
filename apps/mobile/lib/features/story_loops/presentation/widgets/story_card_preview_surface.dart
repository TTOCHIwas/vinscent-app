import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_sized_network_image.dart';
import '../../../../core/presentation/widgets/app_media_reveal.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/story_card_scene.dart';
import '../../data/story_card_type.dart';

class StoryCardPreviewSurface extends StatelessWidget {
  const StoryCardPreviewSurface({
    super.key,
    required this.previewUrl,
    required this.width,
    this.cardType = StoryCardType.polaroid,
    this.layoutVersion = storyCardLegacyLayoutVersion,
    this.surfaceKey,
    this.onTap,
    this.semanticsLabel,
    this.cornerRadius = 1,
    this.showShadow = true,
    this.aspectRatioOverride,
    this.isLoading = false,
  });

  final String? previewUrl;
  final double width;
  final StoryCardType cardType;
  final int layoutVersion;
  final Key? surfaceKey;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final double cornerRadius;
  final bool showShadow;
  final double? aspectRatioOverride;
  final bool isLoading;

  static const shadows = [
    BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 4)),
  ];

  static double widthInFourByFiveSlot(
    double slotWidth,
    StoryCardType cardType, {
    int layoutVersion = storyCardLegacyLayoutVersion,
  }) {
    return slotWidth *
        (cardType.canvasAspectRatioFor(layoutVersion) /
            storyCardCanvasAspectRatio);
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio =
        aspectRatioOverride ?? cardType.canvasAspectRatioFor(layoutVersion);
    final height = width / aspectRatio;
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
              aspectRatio: aspectRatio,
              child: isLoading
                  ? const AppMediaReveal(ready: false, child: SizedBox.shrink())
                  : AppSizedNetworkImage(
                      url: previewUrl,
                      logicalSize: Size(width, height),
                      fallbackBuilder: (_) =>
                          const _StoryCardPreviewPlaceholder(),
                      surfaceBuilder: (context, image) => DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: borderRadius,
                          border: Border.all(color: AppColors.wireframeBorder),
                          boxShadow: showShadow ? shadows : null,
                        ),
                        child: ClipRRect(
                          borderRadius: borderRadius,
                          child: image,
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
