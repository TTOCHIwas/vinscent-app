import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/character_placeholder.dart';
import '../../../../core/presentation/widgets/app_network_image.dart';
import '../../../../core/presentation/widgets/app_sized_network_image.dart';
import '../../../../core/presentation/widgets/app_media_reveal.dart';
import '../../../profile/application/profile_controller.dart';
import '../../application/couple_character_controller.dart';
import '../../data/couple_character.dart';
import '../../data/couple_character_repository.dart';

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
    final child =
        characterAsync.isLoading &&
            !characterAsync.hasValue &&
            !characterAsync.hasError
        ? SizedBox.square(
            dimension: size,
            child: const AppMediaReveal(ready: false, child: SizedBox.shrink()),
          )
        : character == null
        ? CharacterPlaceholder(label: label, size: size)
        : _CharacterImage(character: character, label: label, size: size);

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

class _CharacterImage extends ConsumerWidget {
  const _CharacterImage({
    required this.character,
    required this.label,
    required this.size,
  });

  final CoupleCharacter character;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = character.imageUrl;
    final userId = imageUrl == null
        ? ref.watch(
            profileControllerProvider.select(
              (state) => state.asData?.value?.id,
            ),
          )
        : null;
    final revision = character.updatedAt.microsecondsSinceEpoch;
    final repository = ref.watch(coupleCharacterRepositoryProvider);
    final imageProvider = userId == null || character.imagePath.isEmpty
        ? null
        : AppNetworkImage.withLoader(
            'character/$userId/$revision/${character.imagePath}',
            () => repository.fetchImageBytes(character),
          );

    return SizedBox(
      width: size,
      height: size,
      child: AppSizedNetworkImage(
        url: imageUrl,
        imageProvider: imageProvider,
        key: ValueKey((imageUrl, imageProvider, revision)),
        logicalSize: Size.square(size),
        fallbackBuilder: (context) {
          return CharacterPlaceholder(label: label, size: size);
        },
      ),
    );
  }
}
