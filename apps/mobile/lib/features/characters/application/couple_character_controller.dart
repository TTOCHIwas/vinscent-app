import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../data/couple_character.dart';
import '../data/couple_character_failure.dart';
import '../data/couple_character_repository.dart';

final coupleCharacterControllerProvider =
    AsyncNotifierProvider<CoupleCharacterController, CoupleCharacter?>(
      CoupleCharacterController.new,
    );

class CoupleCharacterController extends AsyncNotifier<CoupleCharacter?> {
  @override
  Future<CoupleCharacter?> build() async {
    final couple = await ref.watch(coupleControllerProvider.future);
    if (couple == null || couple.status != CoupleStatus.active) {
      return null;
    }

    return ref.watch(coupleCharacterRepositoryProvider).fetchCurrentCharacter();
  }

  Future<CoupleCharacter> saveCharacter({
    required Uint8List imageBytes,
    required String drawingDataJson,
  }) async {
    final couple = await ref.read(coupleControllerProvider.future);
    if (couple == null || couple.status != CoupleStatus.active) {
      throw const CoupleCharacterRepositoryException(
        CoupleCharacterFailureReason.activeCoupleRequired,
      );
    }

    final character = await ref
        .read(coupleCharacterRepositoryProvider)
        .saveCharacter(
          coupleId: couple.id,
          imageBytes: imageBytes,
          drawingDataJson: drawingDataJson,
        );

    state = AsyncValue.data(character);
    return character;
  }

  Future<String?> fetchDrawingData(CoupleCharacter character) {
    return ref
        .read(coupleCharacterRepositoryProvider)
        .fetchDrawingData(character);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(coupleCharacterRepositoryProvider).fetchCurrentCharacter(),
    );
  }
}
