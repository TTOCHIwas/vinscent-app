import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/story_card_type.dart';

class StoryCardPhotoAssembly extends StatelessWidget {
  const StoryCardPhotoAssembly({
    required this.cardType,
    required this.photos,
    required this.selectedIndex,
    required this.isPickingGallery,
    required this.onBack,
    required this.onPhotoSelected,
    required this.onCameraPressed,
    required this.onGalleryPressed,
    required this.onContinue,
    super.key,
  });

  final StoryCardType cardType;
  final List<Uint8List?> photos;
  final int selectedIndex;
  final bool isPickingGallery;
  final VoidCallback onBack;
  final ValueChanged<int> onPhotoSelected;
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    tooltip: '뒤로',
                  ),
                  Expanded(
                    child: Text(
                      cardType.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('story-card-assembly-next'),
                    onPressed: onContinue,
                    child: const Text('다음'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const horizontalPadding = 36.0;
                  const verticalPadding = 20.0;
                  final maxWidth = constraints.maxWidth - horizontalPadding * 2;
                  final maxHeight = constraints.maxHeight - verticalPadding * 2;
                  final height = (maxWidth / cardType.canvasAspectRatio).clamp(
                    0.0,
                    maxHeight,
                  );
                  final width = height * cardType.canvasAspectRatio;
                  return Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: _PhotoCard(
                        cardType: cardType,
                        photos: photos,
                        selectedIndex: selectedIndex,
                        onPhotoSelected: onPhotoSelected,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AssemblyAction(
                    key: const ValueKey('story-card-assembly-camera'),
                    icon: LucideIcons.camera,
                    label: '촬영',
                    onPressed: onCameraPressed,
                  ),
                  const SizedBox(width: 36),
                  _AssemblyAction(
                    key: const ValueKey('story-card-assembly-gallery'),
                    icon: LucideIcons.images,
                    label: '갤러리',
                    isLoading: isPickingGallery,
                    onPressed: isPickingGallery ? null : onGalleryPressed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.cardType,
    required this.photos,
    required this.selectedIndex,
    required this.onPhotoSelected,
  });

  final StoryCardType cardType;
  final List<Uint8List?> photos;
  final int selectedIndex;
  final ValueChanged<int> onPhotoSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = StoryCardLayout.fromSize(
            type: cardType,
            size: constraints.biggest,
          );
          return Stack(
            children: [
              for (var index = 0; index < layout.photoRects.length; index++)
                Positioned.fromRect(
                  rect: layout.photoRects[index],
                  child: _PhotoSlot(
                    key: ValueKey('story-card-photo-slot-$index'),
                    imageBytes: index < photos.length ? photos[index] : null,
                    isSelected: index == selectedIndex,
                    onTap: () => onPhotoSelected(index),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.imageBytes,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final Uint8List? imageBytes;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE9E9E6),
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? const Color(0xFFE46F61) : Colors.transparent,
              width: isSelected ? 3 : 0,
            ),
          ),
          child: imageBytes == null
              ? const Center(
                  child: Icon(LucideIcons.plus, color: Color(0xFF777773)),
                )
              : Image.memory(
                  imageBytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
        ),
      ),
    );
  }
}

class _AssemblyAction extends StatelessWidget {
  const _AssemblyAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          color: Colors.white,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF202020),
            disabledBackgroundColor: const Color(0xFF202020),
            fixedSize: const Size(56, 56),
          ),
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon),
          tooltip: label,
        ),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}
