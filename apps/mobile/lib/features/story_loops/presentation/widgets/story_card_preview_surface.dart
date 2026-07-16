import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/story_card_scene.dart';

class StoryCardPreviewSurface extends StatelessWidget {
  const StoryCardPreviewSurface({
    super.key,
    required this.previewUrl,
    required this.width,
    this.surfaceKey,
    this.onTap,
    this.semanticsLabel,
  });

  final String? previewUrl;
  final double width;
  final Key? surfaceKey;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final previewUri = previewUrl == null ? null : Uri.tryParse(previewUrl!);
    final hasRemotePreview =
        previewUri != null &&
        previewUri.hasScheme &&
        (previewUri.scheme == 'http' || previewUri.scheme == 'https');
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (width * pixelRatio).round();
    final cacheHeight = (width / storyCardCanvasAspectRatio * pixelRatio)
        .round();

    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: surfaceKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: width,
            child: AspectRatio(
              aspectRatio: storyCardCanvasAspectRatio,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.wireframeBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: hasRemotePreview
                      ? Image.network(
                          previewUrl!,
                          fit: BoxFit.contain,
                          cacheWidth: cacheWidth,
                          cacheHeight: cacheHeight,
                          errorBuilder: (context, error, stackTrace) =>
                              const _StoryCardPreviewPlaceholder(),
                        )
                      : const _StoryCardPreviewPlaceholder(),
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
