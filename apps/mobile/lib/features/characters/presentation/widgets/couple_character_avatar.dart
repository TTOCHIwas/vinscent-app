import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/character_placeholder.dart';
import '../../../../core/presentation/widgets/app_sized_network_image.dart';
import '../../../../core/presentation/widgets/app_media_reveal.dart';
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
    final characterAsync = ref.watch(coupleCharacterControllerProvider);
    final character = characterAsync.value;
    final imageUrl = character?.imageUrl;
    final child =
        characterAsync.isLoading &&
            !characterAsync.hasValue &&
            !characterAsync.hasError
        ? SizedBox.square(
            dimension: size,
            child: const AppMediaReveal(ready: false, child: SizedBox.shrink()),
          )
        : imageUrl == null
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
      child: AppSizedNetworkImage(
        url: imageUrl,
        key: ValueKey('$imageUrl:$cacheKey'),
        logicalSize: Size.square(size),
        fallbackBuilder: (context) {
          return CharacterPlaceholder(label: label, size: size);
        },
      ),
    );
  }
}
