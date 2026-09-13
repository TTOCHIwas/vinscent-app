import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/story_card_type.dart';

class StoryCardPhotoSlotControls extends StatelessWidget {
  const StoryCardPhotoSlotControls({
    super.key,
    required this.cardType,
    required this.hasPhotos,
    required this.selectedEmptyIndex,
    required this.onCameraPressed,
    required this.onGalleryPressed,
    this.isPickingGallery = false,
  });

  final StoryCardType cardType;
  final List<bool> hasPhotos;
  final int? selectedEmptyIndex;
  final ValueChanged<int> onCameraPressed;
  final ValueChanged<int> onGalleryPressed;
  final bool isPickingGallery;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = StoryCardLayout.fromSize(
          type: cardType,
          size: constraints.biggest,
        );
        return Stack(
          children: [
            for (var index = 0; index < layout.photoRects.length; index++)
              if (index >= hasPhotos.length || !hasPhotos[index])
                Positioned.fromRect(
                  rect: layout.photoRects[index],
                  child: _EmptyPhotoSlot(
                    key: ValueKey('story-card-empty-photo-slot-$index'),
                    index: index,
                    isSelected: selectedEmptyIndex == index,
                    isPickingGallery: isPickingGallery,
                    onCameraPressed: () => onCameraPressed(index),
                    onGalleryPressed: () => onGalleryPressed(index),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _EmptyPhotoSlot extends StatelessWidget {
  const _EmptyPhotoSlot({
    super.key,
    required this.index,
    required this.isSelected,
    required this.isPickingGallery,
    required this.onCameraPressed,
    required this.onGalleryPressed,
  });

  final int index;
  final bool isSelected;
  final bool isPickingGallery;
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;

  @override
  Widget build(BuildContext context) {
    if (!isSelected) {
      return const IgnorePointer(
        child: Center(
          child: Icon(LucideIcons.plus, size: 30, color: Color(0xFF777773)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Material(
        color: const Color(0x99000000),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: ValueKey('story-card-photo-slot-camera-$index'),
              tooltip: '촬영',
              onPressed: isPickingGallery ? null : onCameraPressed,
              color: Colors.white,
              disabledColor: Colors.white38,
              icon: const Icon(LucideIcons.camera, size: 30),
            ),
            const SizedBox(width: 16),
            IconButton(
              key: ValueKey('story-card-photo-slot-gallery-$index'),
              tooltip: '갤러리',
              onPressed: isPickingGallery ? null : onGalleryPressed,
              color: Colors.white,
              disabledColor: Colors.white38,
              icon: isPickingGallery
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(LucideIcons.image, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}
