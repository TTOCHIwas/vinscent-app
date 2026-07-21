import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/character_placeholder.dart';
import '../../application/couple_character_controller.dart';

export '../../../../core/presentation/widgets/character_placeholder.dart';

class CoupleCharacterAvatar extends ConsumerWidget {
  const CoupleCharacterAvatar({
    super.key,
    this.label = '캐릭터',
    this.onTap,
    this.size = 140,
  });

  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final character = ref
        .watch(coupleCharacterControllerProvider)
        .when(
          data: (character) => character,
          loading: () => null,
          error: (error, stackTrace) => null,
        );
    final imageUrl = character?.imageUrl;
    final child = imageUrl == null
        ? CharacterPlaceholder(label: label, size: size)
        : _CharacterImage(
            imageUrl: imageUrl,
            label: label,
            size: size,
            cacheKey: character?.updatedAt.toIso8601String(),
          );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}

class _CharacterImage extends StatelessWidget {
  const _CharacterImage({
    required this.imageUrl,
    required this.label,
    required this.size,
    this.cacheKey,
  });

  final String imageUrl;
  final String label;
  final double size;
  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        imageUrl,
        key: ValueKey('$imageUrl:$cacheKey'),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return CharacterPlaceholder(label: label, size: size);
        },
      ),
    );
  }
}
